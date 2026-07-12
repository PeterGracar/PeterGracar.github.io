import SwiftUI

struct ContentView: View {
    @Environment(LBMSimulation.self) private var sim
    @State private var showInspector = true

    var body: some View {
        @Bindable var sim = sim

        NavigationStack {
            SimulationCanvas()
                .navigationTitle("Lévy vs Brownian")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            if !sim.hasStarted {
                                sim.hasStarted = true
                                sim.isPaused = false
                            } else {
                                sim.isPaused.toggle()
                            }
                        } label: {
                            Label(
                                sim.hasStarted && !sim.isPaused ? "Pause" : "Start",
                                systemImage: sim.hasStarted && !sim.isPaused ? "pause.fill" : "play.fill"
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
