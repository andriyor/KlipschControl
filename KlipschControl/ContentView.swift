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
        // Controls only once the speaker is ready; before that they'd show default or stale values
        if speaker.deviceReady {
            screen { cards }
                // The most-used controls, pinned under the thumb and visible however far the cards scroll
                .safeAreaInset(edge: .bottom) { controlsBar }
        } else {
            screen { placeholder }
        }
    }

    private func screen(@ViewBuilder _ content: () -> some View) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                content()
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    private var header: some View {
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
    }

    private var placeholder: some View {
        VStack(spacing: 12) {
            if speaker.bluetoothReady {
                ProgressView().controlSize(.large)
                Text("Connecting to your speaker…")
            } else {
                Image(systemName: "antenna.radiowaves.left.and.right.slash").font(.largeTitle)
                Text("Turn on Bluetooth and connect to your Klipsch speaker")
                    .multilineTextAlignment(.center)
            }
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private var cards: some View {
        VStack(spacing: 16) {
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
            Card(title: "Audio Adjustments", icon: "tuningfork",
                 info: "Only one mode can be on at a time. Turning Night Mode off restores Dynamic Bass to how it was before.") {
                Toggle(isOn: Binding(get: { speaker.dynamicBass }, set: { speaker.setDynamicBass($0) })) {
                    adjustmentLabel("Dynamic Bass", "Boosts bass at lower volume levels for a fuller sound.", icon: "waveform")
                }
                Toggle(isOn: Binding(get: { speaker.nightMode }, set: { speaker.setNightMode($0) })) {
                    adjustmentLabel("Night Mode", "Compresses the dynamic range so loud sounds are softer and quiet sounds are cleaner at low volume.", icon: "moon.fill")
                }
            }
        }
    }

    private var controlsBar: some View {
        // Gap between inputs and volume so a thumb on the slider doesn't switch input by accident
        VStack(spacing: 24) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                ForEach(Input.allCases, id: \.self) { input in
                    InputTile(input: input, selected: speaker.activeInput == input) {
                        if speaker.activeInput != input { speaker.switchInput(input) }
                    }
                }
            }
            .padding(.horizontal, 8)

            // Like Apple Music, but the speaker icons step the volume by one for fine control
            HStack(spacing: 4) {
                Button(action: { speaker.volumeDown() }) {
                    Image(systemName: "speaker.fill").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Volume down")

                // Write only on release; per-step writes would queue up over BLE.
                // Don't track drag state from onEditingChanged: on iOS 26 it fires an extra
                // `true` after release, which would leave it stuck. No `step:`, so round here.
                Slider(value: $sliderValue, in: 0...Double(speaker.MAX_VOLUME)) { editing in
                    if !editing {
                        sliderValue = sliderValue.rounded()
                        speaker.setVolume(UInt8(sliderValue))
                    }
                }
                .accessibilityLabel("Volume")

                Button(action: { speaker.volumeUp() }) {
                    Image(systemName: "speaker.wave.3.fill").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Volume up")
            }
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .background(.bar)
        .onChange(of: speaker.volume, initial: true) {
            sliderValue = Double(speaker.volume)
        }
    }
}

#Preview {
    ContentView(speaker: Speaker())
}
