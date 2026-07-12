import SwiftUI

struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: (Double) -> String

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
            Slider(value: $value, in: range, step: step)
        }
    }
}

struct IntLabeledSlider: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int

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
            format: { Int($0).description }
        )
    }
}
