import SwiftUI

struct ContentView: View {
    @Environment(Simulation.self) private var sim
    @State private var showInspector = true

    var body: some View {
        @Bindable var sim = sim

        NavigationStack {
            VStack(spacing: 0) {
                StatsHeader()
                SimulationCanvas()
                HistoryChart()
                    .frame(height: 96)
            }
            .navigationTitle("Contact process")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        sim.isPaused.toggle()
                    } label: {
                        Label(
                            sim.isPaused ? "Resume" : "Pause",
                            systemImage: sim.isPaused ? "play.fill" : "pause.fill"
                        )
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(role: .destructive) {
                        sim.reset()
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

struct StatsHeader: View {
    @Environment(Simulation.self) private var sim

    var body: some View {
        HStack(alignment: .center, spacing: 24) {
            statBlock(
                title: "Prevalence",
                value: prevalenceText,
                emphasised: true,
                alignment: .leading
            )
            Spacer(minLength: 12)
            statBlock(
                title: "R₀ proxy",
                value: r0Text,
                alignment: .trailing
            )
            Divider()
                .frame(height: 32)
            statBlock(
                title: "λ × 10⁴",
                value: densityText,
                alignment: .trailing
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    private func statBlock(
        title: String,
        value: String,
        emphasised: Bool = false,
        alignment: HorizontalAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Text(value)
                .font(emphasised
                    ? .system(.title, design: .rounded, weight: .semibold)
                    : .system(.title3, design: .rounded).monospacedDigit())
                .foregroundStyle(emphasised ? AnyShapeStyle(Color.red) : AnyShapeStyle(.primary))
                .contentTransition(.numericText())
        }
    }

    private var prevalenceText: String {
        sim.prevalence.formatted(.percent.precision(.fractionLength(0)))
    }
    private var r0Text: String {
        if let r = sim.r0Proxy {
            return r.formatted(.number.precision(.fractionLength(2)))
        }
        return "∞"
    }
    private var densityText: String {
        sim.density.formatted(.number.precision(.fractionLength(2)))
    }
}
