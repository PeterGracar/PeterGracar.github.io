import SwiftUI

struct ParametersInspector: View {
    @Environment(Simulation.self) private var sim

    var body: some View {
        @Bindable var sim = sim

        Form {
            Section {
                LabeledSlider(
                    title: "Torus size (L)",
                    value: $sim.L,
                    range: 500...4000,
                    step: 100,
                    format: { Int($0).description },
                    critical: sim.criticalL
                )

                IntSlider(
                    title: "Node count (N)",
                    value: $sim.N,
                    range: 50...1000,
                    step: 10,
                    critical: sim.criticalN
                )

                Toggle("Deterministic radii", isOn: $sim.deterministicRadii)

                if sim.deterministicRadii {
                    LabeledSlider(
                        title: "Radius (r)",
                        value: $sim.r0,
                        range: 5...100,
                        step: 1,
                        format: { Int($0).description }
                    )
                } else {
                    LabeledSlider(
                        title: "Pareto scale (xₘ)",
                        value: $sim.xm,
                        range: 5...100,
                        step: 1,
                        format: { Int($0).description },
                        critical: sim.criticalXm
                    )
                    LabeledSlider(
                        title: "Pareto shape (γ)",
                        value: $sim.gamma,
                        range: 0.5...5.0,
                        step: 0.1,
                        format: { String(format: "%.1f", $0) }
                    )
                }
            } header: {
                Text("Continuum percolation")
            } footer: {
                Text("Each node has a random connection radius. Edges are drawn whenever two discs overlap on the periodic torus.")
            }

            Section {
                Toggle("Freeze motion", isOn: $sim.motionFrozen)

                LabeledSlider(
                    title: "Lévy index (α)",
                    value: $sim.alpha,
                    range: 0.5...2.0,
                    step: 0.1,
                    format: { String(format: "%.1f", $0) }
                )
                LabeledSlider(
                    title: "Velocity (v)",
                    value: $sim.speed,
                    range: 0.5...10.0,
                    step: 0.5,
                    format: { String(format: "%.1f", $0) }
                )
            } header: {
                Text("Mobility (Lévy flight)")
            } footer: {
                Text("α = 2 reduces to Brownian motion. Smaller α produces heavier-tailed jumps.")
            }

            Section {
                LabeledSlider(
                    title: "Infection rate (β)",
                    value: $sim.beta,
                    range: 0...1,
                    step: 0.01,
                    format: { String(format: "%.2f", $0) },
                    critical: sim.criticalBeta
                )
                LabeledSlider(
                    title: "Recovery rate (δ)",
                    value: $sim.delta,
                    range: 0...0.2,
                    step: 0.005,
                    format: { String(format: "%.3f", $0) },
                    critical: sim.criticalDelta
                )
            } header: {
                Text("Contact process (SIS)")
            } footer: {
                Text("Susceptible → Infected at rate β per infected neighbour. Infected → Susceptible at rate δ.")
            }
        }
        #if os(iOS)
        .formStyle(.grouped)
        #endif
        .navigationTitle("Parameters")
    }
}

/// Wraps `LabeledSlider` for an integer-valued parameter without forcing the
/// caller to manage a Double bridge.
private struct IntSlider: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    var critical: Double? = nil

    var body: some View {
        let proxy = Binding<Double>(
            get: { Double(value) },
            set: { value = Int($0.rounded()) }
        )
        LabeledSlider(
            title: title,
            value: proxy,
            range: Double(range.lowerBound)...Double(range.upperBound),
            step: Double(step),
            format: { Int($0).description },
            critical: critical
        )
    }
}
