# KlipschControl

## What's this?

The official Klipsch Connect application for iOS has a few issues.
The ones that bothered me most were:

* Slow startup + connection time (~15 seconds with The Fives)
* Regularly fails to find and connect to the speaker
* The interface is relatively complex for something which should be a simple remote control

This is an iOS app that serves as a simple, fast remote control for the **Klipsch The Fives**, and should also work with The Sevens and The Nines (including McLaren editions), which share the same protocol.

It is a fork of [wleese/KlipschControl](https://github.com/wleese/KlipschControl), which was built for the Klipsch The Three Plus. The Bluetooth protocol for The Fives (inputs byte map, characteristics) is ported from [Nixer1337/KlipschRemote](https://github.com/Nixer1337/KlipschRemote), and was checked against the speaker with [ble-probe](https://github.com/andriyor/ble-probe), a small Python script using [bleak](https://github.com/hbldh/bleak) that subscribes to every characteristic and prints each change, to see which bytes the knob and remote update.

## Features

* Fast and reliable connection, ~4 seconds versus ~15 for the official app, with no device chooser: reuses the link iOS already has to the speaker (`retrieveConnectedPeripherals`) instead of scanning, and only scans as a fallback, matching any Klipsch speaker by name or by its Klipsch service IDs (so a renamed speaker is still found)
* Restores the connection when iOS relaunches the app, and reconnects on its own after an unexpected disconnect
* Volume: a bar pinned to the bottom of the screen, with a slider between speaker icons that step it down or up (like Apple Music); follows the speaker's knob and remote live
* Input: TV, Bluetooth, Optical, USB, Analog and Phono, as two rows in the bottom bar above volume; the active input is highlighted and follows the speaker's remote
* EQ: presets Flat, Vocal, Bass, Rock and Boom, plus bass, mid and treble sliders (−10 to +6); shows Custom when the bands don't match a preset
* Dynamic Bass and Night Mode switches
* Shows the speaker model (The Fives, Sevens, Nines or a McLaren edition) in the header, read from the speaker's Device Information service
* Until the speaker is ready, shows a connecting or Bluetooth-off placeholder instead of the controls

## How did we get here?

At first the original author wanted to control a Klipsch The Three Plus with Home Assistant, but this didn't work.
After some sleuthing, they learned that [BlueZ doesn't play well with this device](https://github.com/bluez/bluez/issues/712), even though Android, macOS and iOS worked fine.

With this in mind, they settled on building a very simple app to act as a remote control.

## Comparison

|                           | KlipschControl (this app)                                                         | Klipsch Connect (official)                              | [KlipschRemote](https://github.com/Nixer1337/KlipschRemote)                                                                                          |
| ------------------------- | --------------------------------------------------------------------------------- | ------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| platforms                 | iOS only (SwiftUI + CoreBluetooth)                                                | iOS, Android                                            | Windows / Linux / macOS desktop, web app (Web Bluetooth), CLI, Python library                                                                        |
| on iOS                    | iOS app (SwiftUI), installed from Xcode                                           | App Store app                                           | web app only, via a Web Bluetooth browser (e.g. Bluefy); didn't connect in my testing on iPhone or iPad                                              |
| connect time              | ~4 s                                                                              | ~15 s, regularly fails to find the speaker              | ~6 s                                                                                                                                                 |
| volume                    | slider between speaker icons that step it, pinned to the bottom; follows the knob | yes                                                     | yes, follows the knob                                                                                                                                |
| input                     | yes                                                                               | yes                                                     | yes                                                                                                                                                  |
| EQ / modes                | 3-band EQ + presets, Dynamic Bass, Night Mode                                     | yes                                                     | 3-band EQ + presets, Dynamic Bass, Night Mode, placement                                                                                             |
| Dynamic Bass + Night Mode | one at a time; switches follow what the speaker reports                           | one at a time                                           | **bug:** both switches can be shown on, but the speaker actually ends with both off; its switches show what was tapped, not what the speaker reports |
| sub / transport           | no                                                                                | yes                                                     | sub level / mute / phase, play-pause / next / previous                                                                                               |
| device settings           | no                                                                                | rename, standby, firmware update, setup                 | rename, auto standby, about, factory reset; no firmware update                                                                                       |
| speakers                  | The Fives (tested), Sevens / Nines (same protocol, untested)                      | soundbars, One / Three Plus, T5 earbuds, The Fives, ... | The Fives / Sevens / Nines                                                                                                                           |

In short: use the official app for firmware updates and first setup, KlipschRemote on desktop and Android for the full feature set, and this app as a simple daily remote on iPhone and iPad.

## Limitations

* Only tested on The Fives. The Sevens and The Nines use the same protocol according to KlipschRemote, but haven't been tried.
* The app connects to the first Klipsch speaker it finds (by name, or by Klipsch's service IDs if it was renamed); there's no picker for choosing between several speakers.
* Only volume, input, EQ, Dynamic Bass and Night Mode are implemented; no speaker placement, subwoofer or device settings.
* Switching from Bluetooth to another input and back drops the phone's audio connection: the speaker's Bluetooth light blinks and you have to reconnect it in iOS Settings → Bluetooth. This is the speaker's firmware: it happens with the official app and KlipschRemote too, while switching with the speaker's own knob reconnects audio by itself. iOS apps can't start an audio connection, so the app can't fix it. The app's own control connection is not affected.
* Dynamic Bass and Night Mode are linked on the speaker: turning Night Mode on turns Dynamic Bass off, and turning Night Mode off (or Dynamic Bass on) restores Dynamic Bass to what it was before Night Mode. The two switches show what the speaker does, so turning Dynamic Bass on from Night Mode may need a second tap.
* Changing the input with the speaker's knob doesn't notify the app, so the highlighted input only updates on the next connect (changes from the IR remote do show up).

## Ideas

Under consideration, not planned.

- Playback controls (prev / play-pause / next) via the AV transport service `DA6D0FB1`, as in KlipschRemote; play/pause is a stateless toggle, likely Bluetooth input only. Low value: when the phone is the one streaming, the lock screen and Control Center already control playback
