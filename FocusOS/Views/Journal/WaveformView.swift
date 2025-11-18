import SwiftUI

struct WaveformView: View {
    var level: CGFloat // 0.0...1.0
    var barCount: Int = 24
    var barWidth: CGFloat = 3
    var spacing: CGFloat = 2
    var cornerRadius: CGFloat = 1.5

    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            let maxBarHeight = height
            let active = max(0, min(1, level))
            HStack(alignment: .center, spacing: spacing) {
                ForEach(0..<barCount, id: \.self) { i in
                    // Create a subtle wave by phasing across bars
                    let phase = CGFloat(i) / CGFloat(barCount)
                    let envelope = 0.6 + 0.4 * sin(phase * .pi)
                    let barHeight = max(2, active * envelope * maxBarHeight)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.accentColor.opacity(0.9))
                        .frame(width: barWidth, height: barHeight)
                        .frame(maxHeight: .infinity, alignment: .center)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    VStack {
        WaveformView(level: 0.2)
            .frame(height: 40)
        WaveformView(level: 0.8)
            .frame(height: 40)
    }
    .padding()
}


