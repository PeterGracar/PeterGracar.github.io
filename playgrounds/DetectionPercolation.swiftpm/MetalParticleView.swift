import SwiftUI
import Metal
import MetalKit
import simd
import UIKit

// MARK: - GPU data layouts (must match the MSL structs below)

private struct GPUParticle {
    var position: SIMD2<Float>
    var radius: Float
    var isBig: Float
}

private struct ParticleUniforms {
    var smallHaloColor: SIMD4<Float>
    var bigHaloColor: SIMD4<Float>
    var smallCoreColor: SIMD4<Float>
    var bigCoreColor: SIMD4<Float>
    var viewportSize: SIMD2<Float>
    var center: SIMD2<Float>
    var scale: Float
    var coreRadiusPoints: Float
    var L: Float
}

private struct EdgeUniforms {
    var color: SIMD4<Float>
    var viewportSize: SIMD2<Float>
    var center: SIMD2<Float>
    var scale: Float
}

// MARK: - Shader source (compiled at runtime via makeLibrary(source:options:))

private let shaderSource = """
#include <metal_stdlib>
using namespace metal;

struct GPUParticle {
    float2 position;
    float radius;
    float isBig;
};

struct ParticleUniforms {
    float4 smallHaloColor;
    float4 bigHaloColor;
    float4 smallCoreColor;
    float4 bigCoreColor;
    float2 viewportSize;
    float2 center;
    float scale;
    float coreRadiusPoints;
    float L;
};

struct EdgeUniforms {
    float4 color;
    float2 viewportSize;
    float2 center;
    float scale;
};

struct VertexOut {
    float4 position [[position]];
    float2 localPos;
    float4 color;
};

constant float2 cornerOffsets[4] = {
    float2(-1, -1),
    float2( 1, -1),
    float2(-1,  1),
    float2( 1,  1)
};

constant float2 shifts[9] = {
    float2( 0,  0),
    float2( 1,  0),
    float2(-1,  0),
    float2( 0,  1),
    float2( 0, -1),
    float2( 1,  1),
    float2(-1, -1),
    float2( 1, -1),
    float2(-1,  1)
};

vertex VertexOut vertex_particle(
    uint vid [[vertex_id]],
    uint iid [[instance_id]],
    constant GPUParticle* particles [[buffer(0)]],
    constant ParticleUniforms& u [[buffer(1)]],
    constant int& mode [[buffer(2)]]
) {
    uint pid = iid / 9;
    uint sid = iid % 9;

    GPUParticle p = particles[pid];
    float2 shift = shifts[sid] * u.L;
    float2 shifted = p.position + shift;

    // Early-cull torus copies that fall entirely outside the tile.
    // Produces a degenerate zero-area quad that the rasterizer trivially skips.
    float halfL = u.L * 0.5;
    float margin = p.radius + u.coreRadiusPoints / u.scale;
    if (shifted.x < -halfL - margin || shifted.x > halfL + margin ||
        shifted.y < -halfL - margin || shifted.y > halfL + margin) {
        VertexOut out;
        out.position = float4(0, 0, 0, 1);
        out.localPos = float2(2);
        out.color = float4(0);
        return out;
    }

    float2 corner = cornerOffsets[vid];
    float r = (mode == 0) ? p.radius : (u.coreRadiusPoints / u.scale);
    float2 worldPos = shifted + corner * r;
    float2 viewportPos = worldPos * u.scale + u.center;
    float2 ndc = (viewportPos / u.viewportSize) * 2.0 - 1.0;
    ndc.y = -ndc.y;

    VertexOut out;
    out.position = float4(ndc, 0, 1);
    out.localPos = corner;
    if (mode == 0) {
        out.color = (p.isBig > 0.5) ? u.bigHaloColor : u.smallHaloColor;
    } else {
        out.color = (p.isBig > 0.5) ? u.bigCoreColor : u.smallCoreColor;
    }
    return out;
}

fragment float4 fragment_particle(VertexOut in [[stage_in]]) {
    float dist = length(in.localPos);
    float fw = fwidth(dist);
    float aa = 1.0 - smoothstep(1.0 - fw, 1.0, dist);
    if (aa <= 0.0) discard_fragment();
    return float4(in.color.rgb, in.color.a * aa);
}

vertex VertexOut vertex_edge(
    uint vid [[vertex_id]],
    constant float2* vertices [[buffer(0)]],
    constant EdgeUniforms& u [[buffer(1)]]
) {
    float2 worldPos = vertices[vid];
    float2 viewportPos = worldPos * u.scale + u.center;
    float2 ndc = (viewportPos / u.viewportSize) * 2.0 - 1.0;
    ndc.y = -ndc.y;

    VertexOut out;
    out.position = float4(ndc, 0, 1);
    out.localPos = float2(0);
    out.color = u.color;
    return out;
}

fragment float4 fragment_edge(VertexOut in [[stage_in]]) {
    return in.color;
}
"""

// MARK: - Renderer

@MainActor
final class MetalParticleRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private var particlePipeline: MTLRenderPipelineState!
    private var edgePipeline: MTLRenderPipelineState!

    private var particleBuffer: MTLBuffer?
    private var edgeBuffer: MTLBuffer?

    // Cached color conversions (resolved once, not every frame)
    private let cachedSmallHalo = rgba(UIColor.systemTeal.withAlphaComponent(0.22))
    private let cachedBigHalo = rgba(UIColor.systemOrange.withAlphaComponent(0.32))
    private let cachedSmallCore = rgba(UIColor.systemTeal)
    private let cachedBigCore = rgba(UIColor.systemOrange)
    private let cachedEdgeColor = rgba(UIColor.secondaryLabel.withAlphaComponent(0.45))

    weak var sim: DPSimulation?

    init?(view: MTKView) {
        guard let device = view.device else { return nil }
        self.device = device
        guard let queue = device.makeCommandQueue() else { return nil }
        self.queue = queue
        super.init()
        do {
            try setupPipelines(view: view)
        } catch {
            // Surface the error so users see why Metal isn't lighting up.
            print("MetalParticleRenderer setup failed: \(error)")
            return nil
        }
    }

    private func setupPipelines(view: MTKView) throws {
        let library = try device.makeLibrary(source: shaderSource, options: nil)
        guard
            let vertexParticle = library.makeFunction(name: "vertex_particle"),
            let fragmentParticle = library.makeFunction(name: "fragment_particle"),
            let vertexEdge = library.makeFunction(name: "vertex_edge"),
            let fragmentEdge = library.makeFunction(name: "fragment_edge")
        else {
            throw NSError(domain: "MetalParticleRenderer", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Shader functions missing in compiled library"
            ])
        }

        let particleDesc = MTLRenderPipelineDescriptor()
        particleDesc.vertexFunction = vertexParticle
        particleDesc.fragmentFunction = fragmentParticle
        particleDesc.rasterSampleCount = view.sampleCount
        particleDesc.colorAttachments[0].pixelFormat = view.colorPixelFormat
        particleDesc.colorAttachments[0].isBlendingEnabled = true
        particleDesc.colorAttachments[0].rgbBlendOperation = .add
        particleDesc.colorAttachments[0].alphaBlendOperation = .add
        particleDesc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        particleDesc.colorAttachments[0].sourceAlphaBlendFactor = .one
        particleDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        particleDesc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        particlePipeline = try device.makeRenderPipelineState(descriptor: particleDesc)

        let edgeDesc = MTLRenderPipelineDescriptor()
        edgeDesc.vertexFunction = vertexEdge
        edgeDesc.fragmentFunction = fragmentEdge
        edgeDesc.rasterSampleCount = view.sampleCount
        edgeDesc.colorAttachments[0].pixelFormat = view.colorPixelFormat
        edgeDesc.colorAttachments[0].isBlendingEnabled = true
        edgeDesc.colorAttachments[0].rgbBlendOperation = .add
        edgeDesc.colorAttachments[0].alphaBlendOperation = .add
        edgeDesc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        edgeDesc.colorAttachments[0].sourceAlphaBlendFactor = .one
        edgeDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        edgeDesc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        edgePipeline = try device.makeRenderPipelineState(descriptor: edgeDesc)
    }

    // MARK: MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard
            let sim = sim,
            let drawable = view.currentDrawable,
            let renderPassDescriptor = view.currentRenderPassDescriptor,
            let commandBuffer = queue.makeCommandBuffer()
        else { return }

        sim.tickIfNotPausedOrHit()

        let L = Float(sim.L)
        guard L > 0 else {
            commandBuffer.commit()
            return
        }

        let kmax = sim.hotKmaxDirect
        let scenarioIsTwo = sim.scenario == .largestComponent

        let pointsWidth = Float(view.bounds.width)
        let pointsHeight = Float(view.bounds.height)
        guard pointsWidth > 0, pointsHeight > 0 else {
            commandBuffer.commit()
            return
        }

        let padding: Float = 16
        let avW = max(pointsWidth - 2 * padding, 1)
        let avH = max(pointsHeight - 2 * padding, 1)
        let scale = min(avW, avH) / L
        let centerX = pointsWidth / 2
        let centerY = pointsHeight / 2
        let coreRadius: Float = Float(max(1.5, min(3.0, Double(scale) * 0.6)))
        let drawn = L * scale

        // ── Write particle data directly into the Metal buffer ────────────
        let particleCount = sim.withHotParticles { buf in
            let n = buf.count
            guard n > 0 else { return 0 }
            let particleBytes = MemoryLayout<GPUParticle>.stride * n
            if particleBuffer == nil || particleBuffer!.length < particleBytes {
                let newSize = max(particleBytes * 2, 16 * 1024)
                particleBuffer = device.makeBuffer(length: newSize, options: .storageModeShared)
            }
            if let metalBuf = particleBuffer {
                let ptr = metalBuf.contents().bindMemory(to: GPUParticle.self, capacity: n)
                for i in 0..<n {
                    let p = buf[i]
                    let isBig: Float = (scenarioIsTwo && kmax > 0 && p.compSize == kmax) ? 1 : 0
                    ptr[i] = GPUParticle(
                        position: SIMD2<Float>(Float(p.x), Float(p.y)),
                        radius: Float(p.radius),
                        isBig: isBig
                    )
                }
            }
            return n
        }

        // ── Build edge GPU buffer (scenario 2 only, shifts pre-baked) ─────
        var edgeVertexCount = 0
        if scenarioIsTwo, sim.hotEdgeCount > 0 {
            sim.withHotParticles { partsBuf in
                sim.withHotEdges { edgesBuf in
                    let edgeCount = edgesBuf.count
                    let needBytes = MemoryLayout<SIMD2<Float>>.stride * edgeCount * 9 * 2
                    if edgeBuffer == nil || edgeBuffer!.length < needBytes {
                        let newSize = max(needBytes * 2, 16 * 1024)
                        edgeBuffer = device.makeBuffer(length: newSize, options: .storageModeShared)
                    }
                    if let buf = edgeBuffer {
                        let raw = buf.contents().bindMemory(to: SIMD2<Float>.self, capacity: edgeCount * 9 * 2)
                        let shifts: [(Float, Float)] = [
                            (0, 0), (L, 0), (-L, 0),
                            (0, L), (0, -L),
                            (L, L), (-L, -L),
                            (L, -L), (-L, L)
                        ]
                        var idx = 0
                        for shift in shifts {
                            for ei in 0..<edgeCount {
                                let e = edgesBuf[ei]
                                let u = partsBuf[e.i]
                                raw[idx] = SIMD2<Float>(Float(u.x) + shift.0, Float(u.y) + shift.1)
                                idx += 1
                                raw[idx] = SIMD2<Float>(Float(e.vRelX) + shift.0, Float(e.vRelY) + shift.1)
                                idx += 1
                            }
                        }
                        edgeVertexCount = idx
                    }
                }
            }
        }

        // ── Uniforms (colors resolved once at init, not per-frame) ────────
        var pUniforms = ParticleUniforms(
            smallHaloColor: cachedSmallHalo,
            bigHaloColor: cachedBigHalo,
            smallCoreColor: cachedSmallCore,
            bigCoreColor: cachedBigCore,
            viewportSize: SIMD2<Float>(pointsWidth, pointsHeight),
            center: SIMD2<Float>(centerX, centerY),
            scale: scale,
            coreRadiusPoints: coreRadius,
            L: L
        )

        var eUniforms = EdgeUniforms(
            color: cachedEdgeColor,
            viewportSize: SIMD2<Float>(pointsWidth, pointsHeight),
            center: SIMD2<Float>(centerX, centerY),
            scale: scale
        )

        // ── Encode ────────────────────────────────────────────────────────
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            commandBuffer.commit()
            return
        }

        // Scissor rect clips rendering to the tile boundary
        let cs = Float(view.contentScaleFactor)
        let drawableW = Int(view.drawableSize.width)
        let drawableH = Int(view.drawableSize.height)
        let sx = max(0, Int(((centerX - drawn / 2) * cs).rounded(.down)))
        let sy = max(0, Int(((centerY - drawn / 2) * cs).rounded(.down)))
        let sw = max(1, min(drawableW - sx, Int((drawn * cs).rounded(.up))))
        let sh = max(1, min(drawableH - sy, Int((drawn * cs).rounded(.up))))
        encoder.setScissorRect(MTLScissorRect(x: sx, y: sy, width: sw, height: sh))

        if edgeVertexCount > 0, let edgeBuffer = edgeBuffer {
            encoder.setRenderPipelineState(edgePipeline)
            encoder.setVertexBuffer(edgeBuffer, offset: 0, index: 0)
            encoder.setVertexBytes(&eUniforms, length: MemoryLayout<EdgeUniforms>.stride, index: 1)
            encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: edgeVertexCount)
        }

        if particleCount > 0, let particleBuffer = particleBuffer {
            encoder.setRenderPipelineState(particlePipeline)
            encoder.setVertexBuffer(particleBuffer, offset: 0, index: 0)
            encoder.setVertexBytes(&pUniforms, length: MemoryLayout<ParticleUniforms>.stride, index: 1)

            var mode: Int32 = 0
            encoder.setVertexBytes(&mode, length: MemoryLayout<Int32>.size, index: 2)
            encoder.drawPrimitives(
                type: .triangleStrip,
                vertexStart: 0,
                vertexCount: 4,
                instanceCount: 9 * particleCount
            )

            mode = 1
            encoder.setVertexBytes(&mode, length: MemoryLayout<Int32>.size, index: 2)
            encoder.drawPrimitives(
                type: .triangleStrip,
                vertexStart: 0,
                vertexCount: 4,
                instanceCount: 9 * particleCount
            )
        }

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

// MARK: - SwiftUI bridge

struct MetalParticleView: UIViewRepresentable {
    let sim: DPSimulation

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MTKView {
        guard let device = MTLCreateSystemDefaultDevice() else {
            // Without Metal there's nothing to render — return an empty view.
            return MTKView()
        }
        let view = MTKView(frame: .zero, device: device)
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = true
        view.preferredFramesPerSecond = 60
        view.sampleCount = 1
        view.isOpaque = false
        view.backgroundColor = .clear
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        view.layer.isOpaque = false

        if let renderer = MetalParticleRenderer(view: view) {
            renderer.sim = sim
            view.delegate = renderer
            context.coordinator.renderer = renderer
        } else {
            view.isPaused = true
            view.enableSetNeedsDisplay = false
        }
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.renderer?.sim = sim
    }

    final class Coordinator {
        var renderer: MetalParticleRenderer?
    }
}

// MARK: - Helpers

private func rgba(_ color: UIColor) -> SIMD4<Float> {
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    color.getRed(&r, green: &g, blue: &b, alpha: &a)
    return SIMD4<Float>(Float(r), Float(g), Float(b), Float(a))
}
