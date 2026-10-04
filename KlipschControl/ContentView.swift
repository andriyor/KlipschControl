//
//  ContentView.swift
//  KlipschControl
//
//  Created by William Leese on 17/02/2024.
//

import SwiftUI

struct ContentView: View {
    @StateObject var speaker: Speaker
    // Local slider position; follows speaker.volume, written to the speaker on release
    @State private var sliderValue = 0.0

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
        .disabled(!speaker.deviceReady)
        
        VStack {
            Text("Volume (\(Int(sliderValue.rounded()) * 100 / Int(speaker.MAX_VOLUME))%)").font(.title3).bold()

            HStack {
                Button(action: {
                    speaker.volumeDown()
                }) {
                    Image(systemName: "minus.circle.fill").font(.title)
                }

                // Write only on release; per-step writes would queue up over BLE.
                // Don't track drag state from onEditingChanged: on iOS 26 it fires an extra
                // `true` after release, which would leave it stuck. No `step:`, so round here.
                Slider(value: $sliderValue, in: 0...Double(speaker.MAX_VOLUME)) { editing in
                    if !editing {
                        sliderValue = sliderValue.rounded()
                        speaker.setVolume(UInt8(sliderValue))
                    }
                }

                Button(action: {
                    speaker.volumeUp()
                }) {
                    Image(systemName: "plus.circle.fill").font(.title)
                }
            }
        }.padding()
        .disabled(!speaker.deviceReady)
        .onChange(of: speaker.volume, initial: true) {
            sliderValue = Double(speaker.volume)
        }

        VStack {
            Text("EQ (\(speaker.activePreset?.label ?? "Custom"))").font(.title3).bold()

            Picker("EQ", selection: Binding(
                get: { speaker.activePreset },
                set: { if let preset = $0 { speaker.applyPreset(preset) } }
            )) {
                ForEach(EQPreset.allCases, id: \.self) { preset in
                    Text(preset.label).tag(Optional(preset))
                }
            }
            .pickerStyle(.segmented)

            Toggle("Dynamic Bass", isOn: Binding(get: { speaker.dynamicBass }, set: { speaker.setDynamicBass($0) }))
            Toggle("Night Mode", isOn: Binding(get: { speaker.nightMode }, set: { speaker.setNightMode($0) }))
        }.padding()
        .disabled(!speaker.deviceReady)

        Spacer()
        
    }
}

#Preview {
    ContentView(speaker: Speaker())
}
