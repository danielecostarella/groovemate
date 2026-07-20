import SwiftUI

/// A fully hand-drawn slider — bypasses the system `Slider` entirely so its
/// appearance never depends on OS control chrome. The system Slider's Liquid
/// Glass rendering was showing a second, fainter track line on real hardware
/// that the Simulator never reproduced, making it impossible to verify a fix
/// without a physical device; a custom-drawn track has no such dependency.
struct CustomSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1
    var step: Double? = nil

    @State private var isDragging = false
    private let trackHeight: CGFloat = 6
    private let thumbSize: CGFloat = 26

    var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, thumbSize)
            let thumbX = normalizedFraction * (width - thumbSize) + thumbSize / 2

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: trackHeight)
                Capsule()
                    .fill(Color.amber)
                    .frame(width: max(thumbX, trackHeight / 2), height: trackHeight)
                Circle()
                    .fill(Color.white)
                    .frame(width: thumbSize, height: thumbSize)
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                    .scaleEffect(isDragging ? 1.15 : 1.0)
                    .position(x: thumbX, y: geo.size.height / 2)
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isDragging)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        isDragging = true
                        let x = min(max(drag.location.x - thumbSize / 2, 0), width - thumbSize)
                        setValue(fromFraction: width > thumbSize ? x / (width - thumbSize) : 0)
                    }
                    .onEnded { _ in isDragging = false }
            )
        }
        .frame(height: thumbSize)
    }

    private var normalizedFraction: Double {
        guard range.upperBound > range.lowerBound else { return 0 }
        return min(max((value - range.lowerBound) / (range.upperBound - range.lowerBound), 0), 1)
    }

    private func setValue(fromFraction f: Double) {
        var v = range.lowerBound + f * (range.upperBound - range.lowerBound)
        if let step, step > 0 {
            v = (v / step).rounded() * step
        }
        value = min(max(v, range.lowerBound), range.upperBound)
    }
}
