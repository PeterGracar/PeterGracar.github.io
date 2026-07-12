import SwiftUI

@main
struct ContactProcessApp: App {
    @State private var simulation = Simulation()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(simulation)
        }
    }
}
