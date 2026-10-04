//
//  Speaker.swift
//  KlipschControl
//
//  Created by William Leese on 17/02/2024.
//

import Foundation
import CoreBluetooth
import Combine

import os.log

let logger = Logger(subsystem: "KlipschControl", category: "Speaker")

// Only the state-restoration key now; changing it would drop restoration for existing installs
let RESTORE_IDENTIFIER = "Klipsch The Fives"

// The Fives, Sevens and Nines (incl. McLaren) share one protocol. Match any of them like
// KlipschRemote: by name, or by Klipsch's own service UUIDs, which a renamed speaker still advertises.
let KLIPSCH_UUID_SUFFIX = "-442C-BABE-F85B5BAA6F11"

class Speaker: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate, ObservableObject {
    
    let VOLUME_UUID = "DA6D0FA2-0D18-442C-BABE-F85B5BAA6F11"
    let INPUT_UUID = "DA6D0FD2-0D18-442C-BABE-F85B5BAA6F11"
    let SERVICE_UUID = "DA6D0FA1-0D18-442C-BABE-F85B5BAA6F11"
    let INPUT_SERVICE_UUID = "DA6D0FD1-0D18-442C-BABE-F85B5BAA6F11"
    let EQ_SERVICE_UUID = "DA6D0F01-0D18-442C-BABE-F85B5BAA6F11"
    // Bass, mid, treble; one byte each, level + 10 (flat = 10)
    let EQ_UUIDS = [
        "DA6D0F02-0D18-442C-BABE-F85B5BAA6F11",
        "DA6D0F03-0D18-442C-BABE-F85B5BAA6F11",
        "DA6D0F04-0D18-442C-BABE-F85B5BAA6F11",
    ]
    // On/off modes in the EQ service; one byte, 0 or 1. Each switch writes only its own value and
    // the speaker's notifications drive the other, because the speaker links them (tested on
    // The Fives): Night Mode on turns Dynamic Bass off and remembers its value; leaving Night Mode
    // (Night Mode off, or Dynamic Bass on) restores that remembered value a moment later. Hiding
    // this behind a single Off / Dynamic Bass / Night Mode picker needed sequenced writes and still
    // flickered, so the switches show what the speaker does instead.
    let NIGHT_MODE_UUID = "DA6D0F05-0D18-442C-BABE-F85B5BAA6F11"
    let DYNAMIC_BASS_UUID = "DA6D0F14-0D18-442C-BABE-F85B5BAA6F11"
    let MAX_VOLUME: UInt8 = 36
    
    @Published var bluetoothReady = false
    @Published var deviceReady = false
    @Published var volume: UInt8 = 1
    @Published var activeInput: Input?
    @Published var eqLevels: [String: Int] = [:]
    @Published var nightMode = false
    @Published var dynamicBass = false
    @Published var statusText = "Disconnected"
    @Published var modelName: String?

    // Device Information Service: model number and hardware revision, read once for the model name
    let INFO_SERVICE_UUID = "180A"
    let MODEL_NUMBER_UUID = "2A24"
    let HARDWARE_REVISION_UUID = "2A27"
    private var deviceInfo: [String: String] = [:]
    
    var UUIDS: [String] = []
    
    var centralManager: CBCentralManager!
    
    var connectedPeripheral: CBPeripheral?
    
    var characteristics: [String: CBCharacteristic] = [:]
    
    override init() {
        super.init()
        UUIDS = [VOLUME_UUID, INPUT_UUID, NIGHT_MODE_UUID, DYNAMIC_BASS_UUID] + EQ_UUIDS
        centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main, options: [CBCentralManagerOptionRestoreIdentifierKey: RESTORE_IDENTIFIER])
    }
    
    func triggerScan() {
        self.statusText = "Looking for speaker"
        logger.info("triggerScan called; bluetoothReady: \(self.bluetoothReady), connected: \(self.connectedPeripheral != nil)")
        
        let connectedPeripherals = centralManager.retrieveConnectedPeripherals(withServices: [CBUUID(string: SERVICE_UUID)])
        
        // Everything returned here exposes Klipsch's volume service
        if let peripheral = connectedPeripherals.first {
            logger.info("Found already connected peripheral: \(peripheral.name ?? "unknown") [\(peripheral.identifier.uuidString)]")
            discoverServices(peripheral)
            return
        }
        
        logger.info("No connected peripheral found; starting BLE scan")
        centralManager.scanForPeripherals(withServices: nil, options: nil)
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        logger.info("centralManagerDidUpdateState: \(central.state.rawValue)")
        switch central.state {
        case .poweredOn:
            bluetoothReady = true
            if let peripheral = connectedPeripheral, peripheral.state == .disconnected {
                logger.info("Bluetooth powered on; reconnecting restored peripheral")
                self.statusText = "Connecting to speaker"
                central.connect(peripheral, options: nil)
            } else {
                logger.info("Bluetooth powered on; starting scan")
                triggerScan()
            }
        default:
            deviceReady = false
            bluetoothReady = false
            self.statusText = "Bluetooth not ready"
            logger.warning("Bluetooth not ready; state raw value: \(central.state.rawValue)")
            break
        }
    }
    
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        // Called before centralManagerDidUpdateState, so only remember the peripheral here;
        // the connect happens once Bluetooth is powered on.
        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral], let peripheral = peripherals.first {
            logger.info("Restoring peripheral: \(peripheral.name ?? "unknown") [\(peripheral.identifier.uuidString)]")
            connectedPeripheral = peripheral
            connectedPeripheral?.delegate = self
        } else {
            logger.info("willRestoreState received no peripherals to restore")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name ?? "unknown"
        let services = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        let isKlipsch = name.localizedCaseInsensitiveContains("Klipsch")
            || services.contains { $0.uuidString.uppercased().hasSuffix(KLIPSCH_UUID_SUFFIX) }

        if isKlipsch {
            self.statusText = "Connecting to speaker"
            logger.info("Matched Klipsch speaker: \(name) [\(peripheral.identifier.uuidString)] RSSI: \(RSSI)")
            
            connectedPeripheral = peripheral
            connectedPeripheral!.delegate = self
            
            logger.info("Attempting connection to discovered peripheral")
            centralManager.connect(connectedPeripheral!, options: nil)
            
            centralManager.stopScan()
            logger.info("Stopped scanning after finding target peripheral")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        logger.info("didConnect fired for peripheral: \(peripheral.name ?? "unknown") [\(peripheral.identifier.uuidString)]")
        discoverServices(peripheral)
    }

    // Resets BLE state and starts discovery; readiness comes back via didDiscoverCharacteristicsFor
    private func discoverServices(_ peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        connectedPeripheral?.delegate = self
        deviceReady = false
        characteristics.removeAll()
        logger.info("Reset BLE state; discovering services")
        peripheral.discoverServices([SERVICE_UUID, INPUT_SERVICE_UUID, EQ_SERVICE_UUID, INFO_SERVICE_UUID].map { CBUUID(string: $0) })
        self.statusText = "Connecting to speaker"
    }
    
    func peripheral( _ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            logger.error("didDiscoverServices failed: \(error.localizedDescription)")
        }
        guard let services = peripheral.services, error == nil else {
            self.statusText = "An error occurred discovering services"
            return
        }
        logger.info("didDiscoverServices found \(services.count) service(s): \(services.map { $0.uuid.uuidString }.joined(separator: ", "))")
        for service in services {
            logger.info("Discovering characteristics for service \(service.uuid.uuidString)")
            peripheral.discoverCharacteristics((UUIDS + [MODEL_NUMBER_UUID, HARDWARE_REVISION_UUID]).map { CBUUID(string: $0) }, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            self.statusText = "An error occurred discovering characteristics: " + error.localizedDescription
            logger.error("didDiscoverCharacteristicsFor service \(service.uuid.uuidString) failed: \(error.localizedDescription)")
        }
        
        let discoveredCharacteristicUUIDs = service.characteristics?.map { $0.uuid.uuidString }.joined(separator: ", ") ?? "none"
        logger.info("Service \(service.uuid.uuidString) reported characteristic(s): \(discoveredCharacteristicUUIDs)")
        
        service.characteristics?.forEach({ characteristic in
            // Not part of readiness: the model name is cosmetic
            if [MODEL_NUMBER_UUID, HARDWARE_REVISION_UUID].contains(characteristic.uuid.uuidString) {
                peripheral.readValue(for: characteristic)
            }
            if UUIDS.contains(characteristic.uuid.uuidString) {
                logger.info("Found tracked characteristic \(characteristic.uuid.uuidString)")
                characteristics[characteristic.uuid.uuidString] = characteristic

                // Subscribe right away so changes made on the speaker (remote, knob) reach the app
                if characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) {
                    peripheral.setNotifyValue(true, for: characteristic)
                } else {
                    logger.warning("Characteristic \(characteristic.uuid.uuidString) does not support notifications")
                }

                logger.info("Reading initial value from \(characteristic.uuid.uuidString)")
                peripheral.readValue(for: characteristic)
            }
        })

        // Mark the device as ready once all required characteristics are present.
        if characteristics.count == UUIDS.count {
            self.statusText = "Connected"
            deviceReady = true
            logger.info("deviceReady set to true; discovered required characteristics: \(Array(self.characteristics.keys).sorted().joined(separator: ", "))")
        } else {
            logger.info("deviceReady still false; have \(self.characteristics.count)/\(self.UUIDS.count) required characteristics: \(Array(self.characteristics.keys).sorted().joined(separator: ", "))")
        }
    }
    
    // Fires for both notifications and readValue results
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let e = error {
            self.statusText = "Error didUpdateValue \(e.localizedDescription)"
            return
        }

        if characteristic.uuid.uuidString == VOLUME_UUID {
            // Ignore empty values instead of storing them as the volume
            guard let value = characteristic.value?.first else { return }
            let percentage = Int((Double(value) / 36.0) * 100.0)
            print("volume: \(value) (\(percentage)%)")
            volume = value
        }

        if characteristic.uuid.uuidString == INPUT_UUID {
            // nil for OFF or an unknown byte, so no tile is highlighted
            activeInput = characteristic.value?.first.flatMap(Input.init(rawValue:))
        }

        if [MODEL_NUMBER_UUID, HARDWARE_REVISION_UUID].contains(characteristic.uuid.uuidString), let data = characteristic.value {
            deviceInfo[characteristic.uuid.uuidString] = String(decoding: data, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters))
            modelName = klipschModelName(modelNumber: deviceInfo[MODEL_NUMBER_UUID], hardwareRevision: deviceInfo[HARDWARE_REVISION_UUID])
            logger.info("Device info \(characteristic.uuid.uuidString): \(self.deviceInfo[characteristic.uuid.uuidString] ?? ""), model: \(self.modelName ?? "unknown")")
        }

        if EQ_UUIDS.contains(characteristic.uuid.uuidString), let byte = characteristic.value?.first {
            eqLevels[characteristic.uuid.uuidString] = Int(byte) - 10
        }

        if let byte = characteristic.value?.first {
            if characteristic.uuid.uuidString == NIGHT_MODE_UUID { nightMode = byte != 0 }
            if characteristic.uuid.uuidString == DYNAMIC_BASS_UUID { dynamicBass = byte != 0 }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        logger.error("didFailToConnect for peripheral: \(peripheral.name ?? "unknown") [\(peripheral.identifier.uuidString)] error: \(error?.localizedDescription ?? "none")")
        if let error = error {
            self.statusText = "Failed to connect: \(error.localizedDescription)"
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        logger.info("didDisconnectPeripheral for peripheral: \(peripheral.name ?? "unknown") [\(peripheral.identifier.uuidString)] error: \(error?.localizedDescription ?? "none")")
        deviceReady = false
        characteristics.removeAll()

        // A nil error means we called cancelPeripheralConnection ourselves; don't undo that
        guard error != nil, bluetoothReady else {
            connectedPeripheral = nil
            self.statusText = "Disconnected"
            return
        }

        // A pending connect never times out and works in the background, unlike a nameless scan
        self.statusText = "Disconnected, reconnecting..."
        logger.info("Unexpected disconnect; requesting reconnect")
        central.connect(peripheral, options: nil)
    }
    
    func disconnect() {
        if let connectedPeripheral {
            centralManager.cancelPeripheralConnection(connectedPeripheral)
        }
    }
    
    func switchInput(_ input: Input) {
        guard deviceReady, let characteristic = characteristics[INPUT_UUID] else { return }
        self.connectedPeripheral?.writeValue(Data([input.rawValue]), for: characteristic, type: .withResponse)
    }
    
    // nil when the bands don't match any preset (set from another app)
    var activePreset: EQPreset? {
        EQPreset.allCases.first { preset in
            zip(EQ_UUIDS, preset.levels).allSatisfy { eqLevels[$0] == $1 }
        }
    }

    func applyPreset(_ preset: EQPreset) {
        for (uuid, level) in zip(EQ_UUIDS, preset.levels) {
            setEQLevel(uuid, level)
        }
    }

    // level in -10...+6
    func setEQLevel(_ uuid: String, _ level: Int) {
        guard deviceReady, let characteristic = characteristics[uuid] else { return }
        connectedPeripheral?.writeValue(Data([UInt8(level + 10)]), for: characteristic, type: .withResponse)
        // The speaker may not notify EQ changes, so show the level right away
        eqLevels[uuid] = level
    }

    func setNightMode(_ on: Bool) {
        guard writeToggle(NIGHT_MODE_UUID, on) else { return }
        nightMode = on
    }

    func setDynamicBass(_ on: Bool) {
        guard writeToggle(DYNAMIC_BASS_UUID, on) else { return }
        dynamicBass = on
    }

    // Shown right away; the speaker's notifications then update both switches
    private func writeToggle(_ uuid: String, _ on: Bool) -> Bool {
        guard deviceReady, let characteristic = characteristics[uuid] else { return false }
        connectedPeripheral?.writeValue(Data([on ? 1 : 0]), for: characteristic, type: .withResponse)
        return true
    }

    func volumeUp() {
        guard volume < MAX_VOLUME else { return }
        setVolume(volume + 1)
    }

    func volumeDown() {
        guard volume > 0 else { return }
        setVolume(volume - 1)
    }

    func setVolume(_ value: UInt8) {
        guard deviceReady, let characteristic = characteristics[VOLUME_UUID] else { return }
        self.connectedPeripheral?.writeValue(Data([value]), for: characteristic, type: .withResponse)
    }
}
