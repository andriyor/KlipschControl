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
        cancelPendingDisconnect()
        speaker.triggerScan()
      }
      if scenePhase == .background {
        scheduleDisconnect()
      }
    }
  }

  // We need to use the annotation here to have a mutatable value in our struct
  @State var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
  @State var pendingDisconnect: DispatchWorkItem?

  // Drops the speaker connection 20 s after going to the background unless the app comes back
  // first. Runs on the main queue, where UIKit and the CBCentralManager live.
  func scheduleDisconnect() {
    cancelPendingDisconnect()
    backgroundTaskId = UIApplication.shared.beginBackgroundTask {
      cancelPendingDisconnect()
    }

    let work = DispatchWorkItem {
      speaker.disconnect()
      endBackgroundTask()
    }
    pendingDisconnect = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 20, execute: work)
  }

  func cancelPendingDisconnect() {
    pendingDisconnect?.cancel()
    pendingDisconnect = nil
    endBackgroundTask()
  }

  func endBackgroundTask() {
    guard backgroundTaskId != .invalid else { return }
    UIApplication.shared.endBackgroundTask(backgroundTaskId)
    backgroundTaskId = .invalid
  }
}
