import SwiftUI

struct ContentView: View {
    @Environment(DPSimulation.self) private var sim
    @State private var showInspector = true

    var body: some View {
        @Bindable var sim = sim

        NavigationStack {
            ZStack(alignment: .topLeading) {
                SimulationCanvas()
                StatsOverlay()
                    .padding(16)
            }
            .navigationTitle("Detection percolation")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if sim.hit != nil {
                            sim.reset()
                            sim.isPaused = true
                        } else {
                            sim.isPaused.toggle()
                        }
                    } label: {
                        Label(
                            sim.hit != nil
                                ? "Restart"
                                : (sim.isPaused ? "Start" : "Pause"),
                            systemImage: sim.hit != nil
                                ? "arrow.clockwise"
                                : (sim.isPaused ? "play.fill" : "pause.fill")
                        )
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(role: .destructive) {
                        sim.reset()
                        sim.isPaused = true
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showInspector.toggle()
                    } label: {
                        Label("Parameters", systemImage: "slider.horizontal.3")
                    }
                }
            }
            .inspector(isPresented: $showInspector) {
                ParametersInspector()
                    .inspectorColumnWidth(min: 280, ideal: 340, max: 420)
            }
        }
    }
}

private struct StatsOverlay: View {
    @Environment(DPSimulation.self) private var sim

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                row(label: "t", value: String(format: "%.2f", sim.t), big: true)
                row(label: "N", value: "\(sim.particleCount)")
                if sim.scenario == .largestComponent {
                    row(label: "k_max", value: "\(sim.kmax)")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.thinMaterial, in: .rect(cornerRadius: 12))

            if let h = sim.hit {
                Text("Hit at t = \(String(format: "%.2f", h.t))")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Color.red)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.thinMaterial, in: .rect(cornerRadius: 10))
            }
        }
        .allowsHitTesting(false)
    }

    private func row(label: String, value: String, big: Bool = false) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .leading)
            Text(value)
                .font(big
                    ? .system(.title2, design: .rounded, weight: .semibold).monospacedDigit()
                    : .system(.body, design: .rounded).monospacedDigit())
        }
    }
}
