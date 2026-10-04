//
//  ContentView.swift
//  KlipschControl
//
//  Created by William Leese on 17/02/2024.
//

import SwiftUI

let bluetooth = Data([0x00])
let digital = Data([0x01])
let usbComputer = Data([0x02])
let usbStorage = Data([0x03])
let analog = Data([0x04])

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
        
        VStack {
            HStack {
                let inputTv = Button(action: {
                    speaker.switchInput(data: digital)
                }) {
                    Text("Television")
                        .padding(.horizontal, 30)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .bold()
                }
                
                let inputUsbComputer = Button(action: {
                    speaker.switchInput(data: usbComputer)
                }) {
                    Text("Speaker Only")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .bold()
                }
                
                if speaker.activeInput == digital {
                    inputTv
                } else {
                    inputTv.opacity(0.7).fontWeight(.regular)
                }
                
                if speaker.activeInput == usbComputer {
                    inputUsbComputer
                } else {
                    inputUsbComputer.opacity(0.7).fontWeight(.regular)
                }
                
            }
        }.padding().padding()
        
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
