import SwiftUI

struct ParametersInspector: View {
    @Environment(LBMSimulation.self) private var sim
    @State private var seedField: String = ""

    var body: some View {
        @Bindable var sim = sim

        Form {
            Section {
                LabeledSlider(
                    title: "Lévy index (α)",
                    value: $sim.alpha,
                    range: 0.1...1.99,
                    step: 0.01,
                    format: { String(format: "%.2f", $0) }
                )
                HStack(alignment: .firstTextBaseline) {
                    Text("Median jump")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatLength(sim.medianJumpSize))
                        .font(.body.monospacedDigit())
                }

                IntLabeledSlider(
                    title: "Speed (steps/frame)",
                    value: $sim.speed,
                    range: 1...20,
                    step: 1
                )
            } header: {
                Text("Walks")
            } footer: {
                Text("P(step > x) ∼ x⁻ᵅ. Smaller α means heavier tails. Both walks share the same direction sequence each step, so only the jump magnitudes differ.")
            }

            Section {
                LabeledSlider(
                    title: "Sausage radius (q-th quantile)",
                    value: $sim.sausageQuantilePercent,
                    range: 0...100,
                    step: 1,
                    format: { q in
                        let r = sim.radiusForQuantile(percent: q)
                        return "R = \(formatLength(r))  (q = \(Int(q))%)"
                    }
                )
            } header: {
                Text("Sausage")
            } footer: {
                Text("Slider position is the quantile q ∈ [0, 1) of the Lévy jump size; the radius is R(q) = baseScale · (1−q)^(−1/α).")
            }

            Section {
                Toggle("Show Brownian motion", isOn: $sim.showBrownian)
                Toggle("Show Lévy flight", isOn: $sim.showLevy)
                Toggle("Sausage mode (balls)", isOn: $sim.showSausage)
            } header: {
                Text("Display")
            }

            Section {
                LabeledContent("Random seed") {
                    TextField("seed", text: $seedField)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .onSubmit { applySeed() }
                }
                Button {
                    sim.newSeed()
                    seedField = sim.seed
                } label: {
                    Label("New seed & reset", systemImage: "die.face.5")
                }
            } header: {
                Text("Seeding")
            } footer: {
                Text("Press return after editing the seed. The walks restart whenever the seed changes.")
            }
        }
        #if os(iOS)
        .formStyle(.grouped)
        #endif
        .navigationTitle("Parameters")
        .onAppear {
            if seedField.isEmpty { seedField = sim.seed }
        }
        .onChange(of: sim.seed) { _, newValue in
            if seedField != newValue { seedField = newValue }
        }
    }

    private func applySeed() {
        let trimmed = seedField.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != sim.seed else {
            seedField = sim.seed
            return
        }
        sim.reset(seed: trimmed)
    }

    private func formatLength(_ r: Double) -> String {
        if !r.isFinite { return "∞" }
        if r < 10 { return String(format: "%.1f", r) }
        if r < 1000 { return String(Int(r.rounded())) }
        if r < 1e6 { return String(format: "%.1fk", r / 1000) }
        if r < 1e9 { return String(format: "%.1fM", r / 1e6) }
        return String(format: "%.1e", r)
    }
}
