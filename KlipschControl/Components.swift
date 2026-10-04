//
//  Components.swift
//  KlipschControl
//
//  Building blocks used by ContentView.
//

import SwiftUI

struct Card<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon).font(.headline)
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct InputTile: View {
    let input: Input
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                if input == .bluetooth {
                    BluetoothRune()
                        .stroke(style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                        .frame(width: 26, height: 26)
                } else {
                    Image(systemName: input.icon).font(.title2).frame(height: 26)
                }
                Text(input.label).font(.caption).fontWeight(selected ? .bold : .regular)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(selected ? Color.blue : Color.blue.opacity(0.15))
            .foregroundColor(selected ? .white : .blue)
            .cornerRadius(14)
        }
        .animation(.easeInOut(duration: 0.15), value: selected)
    }
}

// One EQ band in -10...+6. Like the volume slider, it follows the speaker and writes only on release.
struct EQSlider: View {
    let label: String
    let level: Int?
    let onRelease: (Int) -> Void
    @State private var value = 0.0

    var body: some View {
        HStack {
            Text(label).frame(width: 56, alignment: .leading)
            Slider(value: $value, in: -10...6) { editing in
                if !editing {
                    value = value.rounded()
                    onRelease(Int(value))
                }
            }
            Text(Int(value.rounded()).formatted(.number.sign(strategy: .always(includingZero: false))))
                .monospacedDigit()
                .frame(width: 32, alignment: .trailing)
        }
        .onChange(of: level, initial: true) {
            if let level { value = Double(level) }
        }
    }
}

// SF Symbols has no Bluetooth logo, so draw the rune. Path is the Feather "bluetooth" icon
// (MIT) on a 24x24 grid, scaled to fit.
struct BluetoothRune: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24
        let origin = CGPoint(x: rect.midX - 12 * scale, y: rect.midY - 12 * scale)
        let points: [(CGFloat, CGFloat)] = [(6.5, 6.5), (17.5, 17.5), (12, 23), (12, 1), (17.5, 6.5), (6.5, 17.5)]
        var path = Path()
        path.addLines(points.map { CGPoint(x: origin.x + $0.0 * scale, y: origin.y + $0.1 * scale) })
        return path
    }
}

func adjustmentLabel(_ title: String, _ description: String, icon: String) -> some View {
    Label {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(description).font(.caption).foregroundStyle(.secondary)
        }
    } icon: {
        Image(systemName: icon)
    }
}
