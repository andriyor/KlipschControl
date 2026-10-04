# KlipschControl

## What's this?

The official [Klipsch Connect](https://apps.apple.com/app/id1490524287) application for iOS has a few issues.
The ones that bothered me most were:

* Slow startup + connection time (~15 seconds with The Fives)
* Regularly fails to find and connect to the speaker
* The interface is relatively complex for something which should be a simple remote control

This is an iOS app that serves as a simple, fast remote control for the **Klipsch The Fives**, and should also work with The Sevens and The Nines (including McLaren editions), which share the same protocol.

<img src="https://github.com/user-attachments/assets/e63eb3f3-245a-4315-a473-230ddb0292eb" width="300" alt="KlipschControl screenshot">

## Features

* Fast and reliable connection, ~4 seconds versus ~15 for the official app, with no device chooser: reuses the link iOS already has to the speaker (`retrieveConnectedPeripherals`) instead of scanning, and only scans as a fallback, matching any Klipsch speaker by name or by its Klipsch service IDs (so a renamed speaker is still found)
* Restores the connection when iOS relaunches the app, and reconnects on its own after an unexpected disconnect
* Volume: a bar pinned to the bottom of the screen, with a slider between speaker icons that step it down or up (like Apple Music); follows the speaker's knob and remote live
* Input: TV, Bluetooth, Optical, USB, Analog and Phono, as two rows in the bottom bar above volume; the active input is highlighted and follows the speaker's remote
* EQ: presets Flat, Vocal, Bass, Rock and Boom, plus bass, mid and treble sliders (−10 to +6); shows Custom when the bands don't match a preset
* Dynamic Bass and Night Mode switches
* Shows the speaker model (The Fives, Sevens, Nines or a McLaren edition) in the header, read from the speaker's Device Information service
* Until the speaker is ready, shows a connecting or Bluetooth-off placeholder instead of the controls

## Install

The app isn't on the App Store; build it with Xcode and run it on your own device.

1. Open `KlipschControl.xcodeproj` in Xcode 26.2 or later.
2. In the KlipschControl target → **Signing & Capabilities**, pick your **Team** and change the **Bundle Identifier** to something unique (e.g. `com.yourname.KlipschControl`).
3. Connect an iPhone or iPad running iOS / iPadOS 26.2 or later, turn on **Settings → Privacy & Security → Developer Mode**, select it as the run destination and press **Run**.
4. On first launch, trust the developer in **Settings → General → VPN & Device Management**.

With a free Apple ID the app stops opening after 7 days and has to be run from Xcode again; with a paid Apple Developer Program membership it lasts a year.

## Comparison

|                           | KlipschControl (this app)                                                         | [Klipsch Connect](https://apps.apple.com/app/id1490524287) (official) | [KlipschRemote](https://github.com/Nixer1337/KlipschRemote)                                                                                          |
| ------------------------- | --------------------------------------------------------------------------------- | --------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| platforms                 | iOS only (SwiftUI + CoreBluetooth)                                                | iOS, Android                                                          | Windows / Linux / macOS desktop, web app (Web Bluetooth), CLI, Python library                                                                        |
| on iOS                    | iOS app (SwiftUI), installed from Xcode                                           | App Store app                                                         | web app only, via a Web Bluetooth browser (e.g. Bluefy); didn't connect in my testing on iPhone or iPad                                              |
| connect time              | ~4 s                                                                              | ~15 s, regularly fails to find the speaker                            | ~6 s                                                                                                                                                 |
| volume                    | slider between speaker icons that step it, pinned to the bottom; follows the knob | yes, follows the knob                                                 | yes, follows the knob                                                                                                                                |
| volume shown as           | slider position only, no number                                                   | dB, −80 to +8 (a label; the speaker has 36 steps)                     | step 0–36 while dragging                                                                                                                             |
| input                     | yes                                                                               | yes                                                                   | yes                                                                                                                                                  |
| EQ                        | 3-band                                                                            | yes                                                                   | 3-band                                                                                                                                               |
| EQ presets                | Flat, Vocal, Bass, Rock, Boom                                                     | yes, without Boom                                                     | Flat, Vocal, Bass, Rock, Boom                                                                                                                        |
| speaker placement         | no                                                                                | yes                                                                   | yes: corner / wall / open (bass compensation)                                                                                                        |
| Dynamic Bass + Night Mode | one at a time; switches follow what the speaker reports                           | one at a time                                                         | **bug:** both switches can be shown on, but the speaker actually ends with both off; its switches show what was tapped, not what the speaker reports |
| sub / transport           | no                                                                                | yes                                                                   | sub level / mute / phase, play-pause / next / previous                                                                                               |
| device settings           | no                                                                                | rename, standby, firmware update, setup                               | rename, auto standby, about, factory reset; no firmware update                                                                                       |
| speakers                  | The Fives (tested), Sevens / Nines (same protocol, untested)                      | soundbars, One / Three Plus, T5 earbuds, The Fives, ...               | The Fives / Sevens / Nines                                                                                                                           |

In short: use the official app for firmware updates and first setup, KlipschRemote on desktop and Android for the full feature set, and this app as a simple daily remote on iPhone and iPad.

## Limitations

* Only tested on The Fives. The Sevens and The Nines use the same protocol according to KlipschRemote, but haven't been tried.
* The app connects to the first Klipsch speaker it finds (by name, or by Klipsch's service IDs if it was renamed); there's no picker for choosing between several speakers.
* Only volume, input, EQ, Dynamic Bass and Night Mode are implemented; no speaker placement, subwoofer, playback controls or device settings.
* Switching from Bluetooth to another input and back drops the phone's audio connection: the speaker's Bluetooth light blinks and you have to reconnect it in iOS Settings → Bluetooth. This is the speaker's firmware: it happens with the official app and KlipschRemote too, while switching with the speaker's own knob reconnects audio by itself. iOS apps can't start an audio connection, so the app can't fix it. The app's own control connection is not affected.
* Dynamic Bass and Night Mode are linked on the speaker: turning Night Mode on turns Dynamic Bass off, and turning Night Mode off (or Dynamic Bass on) restores Dynamic Bass to what it was before Night Mode. The two switches show what the speaker does, so turning Dynamic Bass on from Night Mode may need a second tap.
* Changing the input with the speaker's knob doesn't notify the app (no Bluetooth characteristic reports it), so the highlighted input only updates when you reopen the app. Changes from the IR remote show up right away.

## Ideas

Under consideration, not planned.

- Playback controls (prev / play-pause / next) via the AV transport service `DA6D0FB1`, as in KlipschRemote; play/pause is a stateless toggle, likely Bluetooth input only. Low value: when the phone is the one streaming, the lock screen and Control Center already control playback
- Follow input changes made with the speaker's knob: no characteristic notifies on them (checked all 30, including the undocumented `DA6D0FD3`–`FD5`), but reading the input returns the new value, so re-reading it every ~2 s while the app is open would catch them

## Development

The quickest loop is pressing **Run** in Xcode. From the command line:

```sh
# Build for the simulator (it has no Bluetooth, so it only shows the "Turn on Bluetooth" screen)
xcodebuild -project KlipschControl.xcodeproj -scheme KlipschControl \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath build build
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/KlipschControl.app
xcrun simctl launch booted <your bundle id>

# Build, install and launch on a connected device (see Install for signing)
xcrun devicectl list devices
xcodebuild -project KlipschControl.xcodeproj -scheme KlipschControl \
  -destination 'platform=iOS,name=<device name>' -derivedDataPath build -allowProvisioningUpdates build
xcrun devicectl device install app --device <identifier> build/Build/Products/Debug-iphoneos/KlipschControl.app
xcrun devicectl device process launch --device <identifier> --console <your bundle id>
```

* **Logs:** the app logs with subsystem `KlipschControl`. Watch them in Console.app (select the device, filter by `subsystem:KlipschControl`), or for the simulator with `xcrun simctl spawn booted log stream --predicate 'subsystem == "KlipschControl"'`. `--console` above also prints the volume as the speaker reports it.
* **Formatting:** the code follows [swift-format](https://github.com/swiftlang/swift-format)'s defaults (`.swift-format`). Check with `xcrun swift-format lint -r KlipschControl`, fix with `xcrun swift-format format -i -r KlipschControl`.
* **Protocol:** to see what a characteristic does, [ble-probe](https://github.com/andriyor/ble-probe) prints every notification from the speaker. Close the app first so the speaker isn't already connected to your phone.

## Inspired by and ported from

* A fork of [wleese/KlipschControl](https://github.com/wleese/KlipschControl), which was built for the Klipsch The Three Plus after BlueZ (and so Home Assistant) [couldn't talk to that speaker](https://github.com/bluez/bluez/issues/712). It has since been almost completely rewritten: over 80% of the current Swift code is new, and what remains from the original is mostly the app's skeleton (the CoreBluetooth delegate methods, the app and view structure, a few status messages).
* The Bluetooth protocol for The Fives (input byte map, characteristics, EQ encoding, model numbers) is ported from [Nixer1337/KlipschRemote](https://github.com/Nixer1337/KlipschRemote).
* The protocol was checked against the speaker with [ble-probe](https://github.com/andriyor/ble-probe), a small Python script using [bleak](https://github.com/hbldh/bleak) that subscribes to every characteristic and prints each change, to see which bytes the knob and remote update.
