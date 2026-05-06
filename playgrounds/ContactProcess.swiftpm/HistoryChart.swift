import SwiftUI

struct HistoryChart: View {
    @Environment(Simulation.self) private var sim

    var body: some View {
        // Touch the observable in `body` so the Canvas closure value changes
        // whenever the history buffer mutates.
        let history = sim.history
        ZStack(alignment: .topLeading) {
            Canvas(opaque: true) { context, size in
                let w = Double(size.width)
                let h = Double(size.height)
                let padding: Double = 12
                let contentH = max(h - 2 * padding, 1)

                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(Color(.systemBackground))
                )

                var grid = Path()
                let yMid = (h - padding) - 0.5 * contentH
                grid.move(to: CGPoint(x: 0, y: yMid))
                grid.addLine(to: CGPoint(x: w, y: yMid))
                context.stroke(
                    grid,
                    with: .color(Color.secondary.opacity(0.3)),
                    style: StrokeStyle(lineWidth: 0.5, dash: [3, 3])
                )

                guard history.count >= 2 else { return }
                var line = Path()
                for (i, value) in history.enumerated() {
                    let x = Double(i) / Double(history.count - 1) * w
                    let y = (h - padding) - value * contentH
                    if i == 0 {
                        line.move(to: CGPoint(x: x, y: y))
                    } else {
                        line.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                context.stroke(line, with: .color(.red), lineWidth: 2)
            }
            .accessibilityHidden(true)

            Text("Infection history")
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .background(Color(.systemBackground))
        .overlay(alignment: .top) {
            Divider()
        }
    }
}
