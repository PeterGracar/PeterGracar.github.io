import SwiftUI

@main
struct DetectionPercolationApp: App {
    @State private var simulation = DPSimulation()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(simulation)
        }
    }
}
