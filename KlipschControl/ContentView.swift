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
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(speaker.modelName ?? "Speaker").font(.largeTitle).bold()

                    // Tap to search for the speaker again
                    Button(action: { speaker.triggerScan() }) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(speaker.deviceReady ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)
                            Text(speaker.statusText)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top)

                VStack(spacing: 16) {
                    Card(title: "Input", icon: "rectangle.on.rectangle") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                            ForEach(Input.allCases, id: \.self) { input in
                                InputTile(input: input, selected: speaker.activeInput == input) {
                                    if speaker.activeInput != input { speaker.switchInput(input) }
                                }
                            }
                        }
                    }

                    Card(title: "Volume (\(Int(sliderValue.rounded()) * 100 / Int(speaker.MAX_VOLUME))%)", icon: "speaker.wave.2.fill") {
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
                    }
                    .onChange(of: speaker.volume, initial: true) {
                        sliderValue = Double(speaker.volume)
                    }

                    Card(title: "EQ (\(speaker.activePreset?.label ?? "Custom"))", icon: "slider.vertical.3") {
                        Picker("EQ", selection: Binding(
                            get: { speaker.activePreset },
                            set: { if let preset = $0 { speaker.applyPreset(preset) } }
                        )) {
                            ForEach(EQPreset.allCases, id: \.self) { preset in
                                Text(preset.label).tag(Optional(preset))
                            }
                        }
                        .pickerStyle(.segmented)

                        ForEach(Array(zip(["Bass", "Mid", "Treble"], speaker.EQ_UUIDS)), id: \.1) { label, uuid in
                            EQSlider(label: label, level: speaker.eqLevels[uuid]) { speaker.setEQLevel(uuid, $0) }
                        }
                    }

                    // Labels and descriptions from KlipschRemote's Audio Adjustments panel
                    Card(title: "Audio Adjustments", icon: "tuningfork") {
                        Toggle(isOn: Binding(get: { speaker.dynamicBass }, set: { speaker.setDynamicBass($0) })) {
                            adjustmentLabel("Dynamic Bass", "Boosts bass at lower volume levels for a fuller sound.", icon: "waveform")
                        }
                        Toggle(isOn: Binding(get: { speaker.nightMode }, set: { speaker.setNightMode($0) })) {
                            adjustmentLabel("Night Mode", "Compresses the dynamic range so loud sounds are softer and quiet sounds are cleaner at low volume.", icon: "moon.fill")
                        }

                        Divider().padding(.top, 4)

                        Label("Only one mode can be on at a time. Turning Night Mode off restores Dynamic Bass to how it was before.", systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                // Not on the header: tapping the status text to rescan must work while not ready
                .disabled(!speaker.deviceReady)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}

#Preview {
    ContentView(speaker: Speaker())
}
