import SwiftUI

@main
struct LevyVsBrownianApp: App {
    @State private var simulation = LBMSimulation()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(simulation)
        }
    }
}
