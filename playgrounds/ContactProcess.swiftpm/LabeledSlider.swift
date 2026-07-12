import SwiftUI

/// A row that pairs a slider with a title, current value, and an optional
/// orange tick marking the critical value of the parameter (the point at
/// which the simulation's R₀ proxy crosses 1).
struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: (Double) -> String
    var critical: Double? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                Text(format(value))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.tint)
                    .contentTransition(.numericText())
            }
            slider
        }
    }

    @ViewBuilder
    private var slider: some View {
        if let c = critical, range.contains(c), range.upperBound > range.lowerBound {
            VStack(spacing: 2) {
                criticalMarker(for: c)
                    .frame(height: 6)
                Slider(value: $value, in: range, step: step)
            }
        } else {
            Slider(value: $value, in: range, step: step)
        }
    }

    private func criticalMarker(for c: Double) -> some View {
        GeometryReader { geo in
            let frac = (c - range.lowerBound) / (range.upperBound - range.lowerBound)
            // The slider track is inset by roughly the thumb radius on each
            // side. Approximate that inset so the marker lines up visually.
            let inset: Double = 14
            let usable = max(Double(geo.size.width) - 2 * inset, 1)
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 8))
                .foregroundStyle(Color.orange)
                .position(x: inset + usable * frac, y: 4)
                .accessibilityHidden(true)
        }
    }
}
