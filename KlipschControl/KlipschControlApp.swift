//
//  KlipschControlApp.swift
//  KlipschControl
//
//  Created by William Leese on 17/02/2024.
//

import SwiftUI

@main
struct KlipschControlApp: App {
    @Environment(\.scenePhase) var scenePhase
    
    var speaker = Speaker()
    
    var body: some Scene {
        WindowGroup {
            ContentView(speaker: speaker)
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                speaker.triggerScan()
            }
            if scenePhase == .background {
                startBackgroundTask()
            }
        }
    }
    
    // We need to use the annotation here to have a mutatable value in our struct
    @State var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
    
    func startBackgroundTask() {
        backgroundTaskId = UIApplication.shared.beginBackgroundTask { [self] in
            self.endBackgroundTask()
        }
        
        DispatchQueue.global(qos: .background).async { [self] in
            Thread.sleep(forTimeInterval: 20)
            
            // Final check
            if UIApplication.shared.applicationState == .background {
                speaker.disconnect()
            }
            self.endBackgroundTask()
        }
    }
    
    func endBackgroundTask() {
        UIApplication.shared.endBackgroundTask(backgroundTaskId)
        backgroundTaskId = .invalid
    }
}
