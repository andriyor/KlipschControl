//
//  Klipsch.swift
//  KlipschControl
//
//  Protocol tables for The Fives/Sevens/Nines; the BLE code lives in Speaker.swift.
//

// Input byte map for The Fives/Sevens/Nines, ported from KlipschRemote.
// Declared in UI tile order; OFF (0) is left out because power-off is unreliable.
enum Input: UInt8, CaseIterable {
  case tv = 1
  case bluetooth = 2
  case optical = 3
  case usb = 5
  case aux = 4
  case phono = 6

  var label: String {
    switch self {
    case .tv: "TV"
    case .bluetooth: "Bluetooth"
    case .optical: "Optical"
    case .usb: "USB"
    case .aux: "Analog"
    case .phono: "Phono"
    }
  }

  var icon: String {
    switch self {
    case .tv: "tv"
    case .bluetooth: "dot.radiowaves.left.and.right"  // unused: the tile draws BluetoothRune
    case .optical: "fibrechannel"
    case .usb: "cable.connector"
    case .aux: "cable.coaxial"
    case .phono: "opticaldisc"
    }
  }
}

// EQ presets from KlipschRemote, as (bass, mid, treble) levels in -10...+6. The speaker's own
// preset characteristic errors on this line, so a preset just writes the three bands.
enum EQPreset: CaseIterable {
  case flat, vocal, bass, rock, boom

  var label: String {
    switch self {
    case .flat: "Flat"
    case .vocal: "Vocal"
    case .bass: "Bass"
    case .rock: "Rock"
    case .boom: "Boom"
    }
  }

  var levels: [Int] {
    switch self {
    case .flat: [0, 0, 0]
    case .vocal: [-3, 6, 0]
    case .bass: [6, 0, 0]
    case .rock: [3, -1, 3]
    case .boom: [6, -10, -10]
    }
  }
}

// Model from the standard Device Information Service, using KlipschRemote's table (models.py).
// The Fives and Fives McLaren share a model number and differ only by hardware revision.
func klipschModelName(modelNumber: String?, hardwareRevision: String?) -> String? {
  let rev = hardwareRevision.flatMap { Int($0) }
  switch modelNumber {
  case "1067563", "1067562": return rev == 3 ? "The Fives McLaren" : "The Fives"
  case "1071199", "1071202": return "The Sevens"
  case "1071200", "1071201": return "The Nines"
  case "1071482": return "The Nines McLaren"
  default: break
  }
  switch rev {
  case 1, 2: return "The Fives"
  case 3: return "The Fives McLaren"
  case 4: return "The Sevens"
  case 5: return "The Nines"
  case 8: return "The Nines McLaren"
  default: return nil
  }
}
