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
  // Shown in a popover from an info button next to the title
  var info: String? = nil
  @ViewBuilder let content: Content
  @State private var showInfo = false

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Label(title, systemImage: icon).font(.headline)
        if let info {
          Spacer()
          Button(action: { showInfo = true }) {
            // Icon on the trailing edge, in line with switches below; the tap area extends left
            Image(systemName: "info.circle").frame(width: 44, height: 44, alignment: .trailing)
          }
          .accessibilityLabel("About \(title)")
          // Without the adaptation, iPhone shows the popover as a full sheet
          .popover(isPresented: $showInfo) {
            Text(info)
              .font(.footnote)
              .padding()
              .frame(width: 280)
              .fixedSize(horizontal: false, vertical: true)
              .presentationCompactAdaptation(.popover)
          }
          // Keeps the 44 pt tap area from making the header taller
          .padding(.vertical, -12)
        }
      }
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
      // Compact: two rows of three in the bottom bar
      VStack(spacing: 4) {
        if input == .bluetooth {
          BluetoothRune()
            .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .frame(width: 20, height: 20)
        } else {
          Image(systemName: input.icon).font(.title3).frame(height: 20)
        }
        Text(input.label)
          .font(.caption2)
          .fontWeight(selected ? .bold : .regular)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 8)
      .background(selected ? Color.accentColor : Color.accentColor.opacity(0.15))
      .foregroundStyle(selected ? Color.white : Color.accentColor)
      .cornerRadius(10)
    }
    .animation(.easeInOut(duration: 0.15), value: selected)
  }
}

// Follows a value from the speaker and writes back only on release; per-step writes would queue
// up over BLE. Don't track drag state from onEditingChanged: on iOS 26 it fires an extra `true`
// after release, which would leave it stuck. No `step:`, so round on release.
struct SpeakerSlider: View {
  // Where the thumb is, including mid-drag; the caller owns it to show a live value
  @Binding var position: Double
  let value: Int?
  let range: ClosedRange<Int>
  let onRelease: (Int) -> Void

  var body: some View {
    Slider(value: $position, in: Double(range.lowerBound)...Double(range.upperBound)) { editing in
      if !editing {
        position = position.rounded()
        onRelease(Int(position))
      }
    }
    .onChange(of: value, initial: true) {
      if let value { position = Double(value) }
    }
  }
}

// One EQ band in -10...+6
struct EQSlider: View {
  let label: String
  let level: Int?
  let onRelease: (Int) -> Void
  @State private var position = 0.0

  var body: some View {
    HStack {
      Text(label).frame(width: 56, alignment: .leading)
      SpeakerSlider(position: $position, value: level, range: -10...6, onRelease: onRelease)
      Text(Int(position.rounded()).formatted(.number.sign(strategy: .always(includingZero: false))))
        .monospacedDigit()
        .frame(width: 32, alignment: .trailing)
    }
  }
}

// SF Symbols has no Bluetooth logo, so draw the rune. Path is the Feather "bluetooth" icon
// (MIT) on a 24x24 grid, scaled to fit.
struct BluetoothRune: Shape {
  func path(in rect: CGRect) -> Path {
    let scale = min(rect.width, rect.height) / 24
    let origin = CGPoint(x: rect.midX - 12 * scale, y: rect.midY - 12 * scale)
    let points: [(CGFloat, CGFloat)] = [
      (6.5, 6.5), (17.5, 17.5), (12, 23), (12, 1), (17.5, 6.5), (6.5, 17.5),
    ]
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
