import SwiftUI

struct ContentView: View {
    @Environment(DPSimulation.self) private var sim
    @State private var showInspector = true

    var body: some View {
        NavigationStack {
            SimulationCanvas()
                .toolbar(.hidden, for: .navigationBar)
                .overlay(alignment: .topTrailing) {
                    if !showInspector {
                        Button {
                            showInspector = true
                        } label: {
                            Image(systemName: "sidebar.right")
                                .font(.body.weight(.medium))
                                .padding(8)
                                .background(.regularMaterial, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.tint)
                        .accessibilityLabel("Show inspector")
                        .padding(.top, 8)
                        .padding(.trailing, 8)
                    }
                }
                .inspector(isPresented: $showInspector) {
                    ParametersInspector(showInspector: $showInspector)
                        .inspectorColumnWidth(min: 280, ideal: 340, max: 420)
                }
        }
    }
}
