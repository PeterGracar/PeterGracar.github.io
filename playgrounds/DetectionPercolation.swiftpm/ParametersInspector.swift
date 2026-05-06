import SwiftUI

struct ParametersInspector: View {
    @Environment(DPSimulation.self) private var sim
    @State private var seedField: String = ""

    var body: some View {
        @Bindable var sim = sim

        Form {
            Section {
                LabeledSlider(
                    title: "Box side (L)",
                    value: $sim.L,
                    range: 50...800,
                    step: 10,
                    format: { Int($0).description }
                )
                LabeledSlider(
                    title: "log₁₀ intensity (λ)",
                    value: $sim.logLambda,
                    range: -5...(-1),
                    step: 0.05,
                    format: { String(format: "%.2f", $0) }
                )
                HStack(alignment: .firstTextBaseline) {
                    Text("E[N] = λ·L²")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatMean(sim.meanN))
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.primary)
                }
            } header: {
                Text("Box & intensity")
            } footer: {
                Text("Particles are placed by a Poisson process of intensity λ on the L×L torus.")
            }

            Section {
                Picker("Motion", selection: $sim.motion) {
                    ForEach(MotionKind.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)

                if sim.motion == .brownian {
                    LabeledSlider(
                        title: "Diffusion (σ)",
                        value: $sim.sigma,
                        range: 0.05...5,
                        step: 0.05,
                        format: { String(format: "%.2f", $0) }
                    )
                } else {
                    LabeledSlider(
                        title: "Stability (α)",
                        value: $sim.alpha,
                        range: 0.30...1.99,
                        step: 0.01,
                        format: { String(format: "%.2f", $0) }
                    )
                }
            } header: {
                Text("Motion")
            } footer: {
                Text(
                    sim.motion == .brownian
                        ? "Δx = σ·√Δt · Z each tick (Δt = 0.1)."
                        : "Heavy-tailed jumps with P(|J| > x) ∼ x⁻ᵅ. Each jump is spread over ⌈|J|/speed⌉ ticks."
                )
            }

            Section {
                Picker("Radius", selection: $sim.radiusMode) {
                    ForEach(RadiusMode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)

                if sim.radiusMode == .deterministic {
                    LabeledSlider(
                        title: "Radius (r)",
                        value: $sim.fixedRadius,
                        range: 0.5...30,
                        step: 0.1,
                        format: { String(format: "%.1f", $0) }
                    )
                } else {
                    LabeledSlider(
                        title: "Minimum (xₘ)",
                        value: $sim.xm,
                        range: 0.1...10,
                        step: 0.1,
                        format: { String(format: "%.1f", $0) }
                    )
                    LabeledSlider(
                        title: "Tail index (δ)",
                        value: $sim.paretoDelta,
                        range: 1.10...5.00,
                        step: 0.01,
                        format: { String(format: "%.2f", $0) }
                    )
                }
            } header: {
                Text("Radius")
            } footer: {
                Text(
                    sim.radiusMode == .deterministic
                        ? "Every disc has radius r."
                        : "P(r > x) = (xₘ/x)^δ. E[r²] is finite iff δ > 2."
                )
            }

            Section {
                Picker("Target", selection: $sim.target) {
                    ForEach(TargetMode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Target particle")
            } footer: {
                Text(
                    sim.target == .fixed
                        ? "The target stays at the origin and waits to be detected."
                        : "The target performs the same motion as the particles, starting from the origin."
                )
            }

            Section {
                Picker("Stopping rule", selection: $sim.scenario) {
                    ForEach(Scenario.allCases) { Text("\($0.rawValue) — \($0.label)").tag($0) }
                }
                .pickerStyle(.menu)
            } header: {
                Text("Stopping scenario")
            } footer: {
                Text(sim.scenario.explanation)
            }

            Section {
                IntLabeledSlider(
                    title: "Speed (ticks/frame)",
                    value: $sim.speed,
                    range: 1...20,
                    step: 1
                )
                LabeledContent("Random seed") {
                    TextField("seed", text: $seedField)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .onSubmit {
                            applySeed()
                        }
                }
                Button {
                    let s = "seed-" + String(Int.random(in: 0..<1_000_000_000), radix: 36)
                    seedField = s
                    sim.seed = s
                } label: {
                    Label("New seed", systemImage: "die.face.5")
                }
            } header: {
                Text("Playback")
            }
        }
        #if os(iOS)
        .formStyle(.grouped)
        #endif
        .navigationTitle("Parameters")
        .onAppear {
            seedField = sim.seed
        }
        .onChange(of: sim.seed) { _, newValue in
            if seedField != newValue { seedField = newValue }
        }
    }

    private func applySeed() {
        let trimmed = seedField.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            seedField = sim.seed
            return
        }
        sim.seed = trimmed
    }

    private func formatMean(_ value: Double) -> String {
        if value < 10 { return String(format: "%.2f", value) }
        return Int(value.rounded()).description
    }
}
