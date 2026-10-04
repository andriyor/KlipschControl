//
//  ContentView.swift
//  KlipschControl
//
//  Created by William Leese on 17/02/2024.
//

import SwiftUI

struct ContentView: View {
    @StateObject var speaker: Speaker
    // Local slider position, so speaker notifications don't move it while dragging
    @State private var sliderValue = 0.0
    @State private var isDragging = false

    init(speaker: Speaker) {
        _speaker = StateObject(wrappedValue: speaker)
    }
    
    var body: some View {
        VStack {
            Text("Speaker").font(.title).bold()
            
            let speakerImage = Image(systemName: "speaker.3.fill")
                .font(.system(size: 140))
                .padding()
            
            if speaker.deviceReady {
                speakerImage.foregroundColor(.green)
            } else {
                speakerImage.foregroundColor(.red)
            }
        }.padding()
        
        Text(speaker.statusText)
            .onTapGesture { speaker.triggerScan() }
        
        Divider()
        
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
            ForEach(Input.allCases, id: \.self) { input in
                let selected = speaker.activeInput == input
                Button(action: {
                    if !selected { speaker.switchInput(input) }
                }) {
                    VStack(spacing: 6) {
                        Image(systemName: input.icon).font(.title2)
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
        }.padding()
        
        VStack {
            Text("Volume (\(Int(sliderValue) * 100 / Int(speaker.MAX_VOLUME))%)").font(.title3).bold()

            HStack {
                Button(action: {
                    speaker.volumeDown()
                }) {
                    Image(systemName: "minus.circle.fill").font(.title)
                }

                // Write only on release; per-step writes would queue up over BLE
                Slider(value: $sliderValue, in: 0...Double(speaker.MAX_VOLUME), step: 1) { editing in
                    isDragging = editing
                    if !editing {
                        speaker.volume(data: Data([UInt8(sliderValue)]))
                    }
                }

                Button(action: {
                    speaker.volumeUp()
                }) {
                    Image(systemName: "plus.circle.fill").font(.title)
                }
            }
        }.padding()
        .onChange(of: speaker.volume, initial: true) {
            if !isDragging {
                sliderValue = Double(speaker.volume.withUnsafeBytes { $0.load(as: UInt8.self) })
            }
        }
        
        Spacer()
        
    }
}

#Preview {
    ContentView(speaker: Speaker())
}
