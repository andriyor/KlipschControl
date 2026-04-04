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
            let vol = speaker.volume.withUnsafeBytes { $0.load(as: UInt8.self) }
            Text("Volume (\(vol))").font(.title3).bold()
            
            Button(action: {
                speaker.volumeUp()
            }) {
                Image(systemName: "arrow.up").bold()
                    .padding(.horizontal, 60)
                    .padding(.vertical, 30)
                    .background(Color.green)
                    .foregroundColor(.black)
                    .cornerRadius(10)
            }
            Button(action: {
                speaker.volumeDown()
            }) {
                Image(systemName: "arrow.down").bold()
                    .padding(.horizontal, 60)
                    .padding(.vertical, 30)
                    .background(Color.red)
                    .foregroundColor(.black)
                    .cornerRadius(10)
            }
        }.padding()
        
        Spacer()
        
    }
}

#Preview {
    ContentView(speaker: Speaker())
}
