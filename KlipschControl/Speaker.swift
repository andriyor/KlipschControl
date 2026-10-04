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
        case .bluetooth: "dot.radiowaves.left.and.right"
        case .optical: "fibrechannel"
        case .usb: "cable.connector"
        case .aux: "cable.coaxial"
        case .phono: "opticaldisc"
        }
    }
}

let logger = Logger(subsystem: "KlipschControl", category: "Speaker")

let DEVICE_NAME = "Klipsch The Fives"

class Speaker: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate, ObservableObject {
    
    let VOLUME_UUID = "DA6D0FA2-0D18-442C-BABE-F85B5BAA6F11"
    let INPUT_UUID = "DA6D0FD2-0D18-442C-BABE-F85B5BAA6F11"
    let SERVICE_UUID = "DA6D0FA1-0D18-442C-BABE-F85B5BAA6F11"
    let MAX_VOLUME: UInt8 = 36
    
    // Publish so our view is updated
    @Published var bluetoothReady = false
    @Published var deviceReady = false
    @Published var volume: UInt8 = 1
    @Published var activeInput: Input?
    @Published var statusText = "Disconnected"
    
    var UUIDS: [String] = []
    
    // Core Bluetooth properties
    var centralManager: CBCentralManager!
    
    var connectedPeripheral: CBPeripheral?
    
    var characteristics: [String: CBCharacteristic] = [:]
    
    override init() {
        super.init()
        UUIDS = [VOLUME_UUID, INPUT_UUID]
        centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main, options: [CBCentralManagerOptionRestoreIdentifierKey: DEVICE_NAME])
    }
    
    func triggerScan() {
        self.statusText = "Looking for speaker"
        logger.info("triggerScan called; bluetoothReady: \(self.bluetoothReady), connected: \(self.connectedPeripheral != nil)")
        
        let connectedPeripherals = centralManager.retrieveConnectedPeripherals(withServices: [CBUUID(string: SERVICE_UUID)])
        
        if let peripheral = connectedPeripherals.first(where: { $0.name == DEVICE_NAME }) ?? connectedPeripherals.first {
            logger.info("Found already connected peripheral: \(peripheral.name ?? "unknown") [\(peripheral.identifier.uuidString)]")
            connectedPeripheral = peripheral
            connectedPeripheral?.delegate = self
            deviceReady = false
            characteristics.removeAll()
            peripheral.discoverServices(nil)
            self.statusText = "Connected to speaker"
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
            self.statusText = "Bluetooth is ready"
            if let peripheral = connectedPeripheral, peripheral.state == .disconnected {
                logger.info("Bluetooth powered on; reconnecting restored peripheral")
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
    
    // Restore the connection to the peripherals
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        // Called before centralManagerDidUpdateState, so only remember the peripheral here;
        // the connect happens once Bluetooth is powered on.
        self.statusText = "Restoring state"
        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral], let peripheral = peripherals.first {
            logger.info("Restoring peripheral: \(peripheral.name ?? "unknown") [\(peripheral.identifier.uuidString)]")
            connectedPeripheral = peripheral
            connectedPeripheral?.delegate = self
        } else {
            logger.info("willRestoreState received no peripherals to restore")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let advertisedLocalName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let discoveredName = advertisedLocalName ?? peripheral.name
        let candidateName = discoveredName ?? peripheral.name ?? advertisedLocalName ?? "unknown"
        
        if candidateName.localizedCaseInsensitiveContains("Klipsch") {
            logger.info("Klipsch discovery candidate: \(candidateName) [\(peripheral.identifier.uuidString)] RSSI: \(RSSI)")
        }
        
        if discoveredName == DEVICE_NAME {
            self.statusText = "Found our speaker"
            logger.info("Matched target device name: \(DEVICE_NAME)")
            
            connectedPeripheral = peripheral
            connectedPeripheral!.delegate = self
            
            // Request a connection to the peripheral
            logger.info("Attempting connection to discovered peripheral")
            centralManager.connect(connectedPeripheral!, options: nil)
            
            // Stop scanning for peripherals
            centralManager.stopScan()
            logger.info("Stopped scanning after finding target peripheral")
        }
    }
    
    // callback connect
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        logger.info("didConnect fired for peripheral: \(peripheral.name ?? "unknown") [\(peripheral.identifier.uuidString)]")
        connectedPeripheral = peripheral
        connectedPeripheral?.delegate = self
        deviceReady = false
        characteristics.removeAll()
        logger.info("Reset BLE state after connect; discovering services")
        peripheral.discoverServices(nil)
        self.statusText = "Connected to speaker"
    }
    
    // callback service
    func peripheral( _ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        self.statusText = "Discovering services"
        if let error = error {
            logger.error("didDiscoverServices failed: \(error.localizedDescription)")
        }
        guard let services = peripheral.services, error == nil else {
            self.statusText = "An error occurred discovering services"
            return
        }
        logger.info("didDiscoverServices found \(services.count) service(s): \(services.map { $0.uuid.uuidString }.joined(separator: ", "))")
        for service in services {
            self.statusText = "Found service \(peripheral.name as String?)"
            logger.info("Discovering characteristics for service \(service.uuid.uuidString)")
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    // callback found characteristic
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        self.statusText = "Discovered characteristic"
        if let error = error {
            self.statusText = "An error occurred discovering characteristics: " + error.localizedDescription
            logger.error("didDiscoverCharacteristicsFor service \(service.uuid.uuidString) failed: \(error.localizedDescription)")
        }
        
        let discoveredCharacteristicUUIDs = service.characteristics?.map { $0.uuid.uuidString }.joined(separator: ", ") ?? "none"
        logger.info("Service \(service.uuid.uuidString) reported characteristic(s): \(discoveredCharacteristicUUIDs)")
        
        service.characteristics?.forEach({ characteristic in
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
            self.statusText = "" // We're good, no need for status text
            deviceReady = true
            logger.info("deviceReady set to true; discovered required characteristics: \(Array(self.characteristics.keys).sorted().joined(separator: ", "))")
        } else {
            logger.info("deviceReady still false; have \(self.characteristics.count)/\(self.UUIDS.count) required characteristics: \(Array(self.characteristics.keys).sorted().joined(separator: ", "))")
        }
    }
    
    // callback update characteristic
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
    }
    
    // callback characteristic update value
    // using the read value also is done here
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
            // Don't set deviceReady here - wait for all characteristics to be discovered
        }

        if characteristic.uuid.uuidString == INPUT_UUID {
            // nil for OFF or an unknown byte, so no tile is highlighted
            activeInput = characteristic.value?.first.flatMap(Input.init(rawValue:))
        }
    }
    
    // handle fail to connects
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        logger.error("didFailToConnect for peripheral: \(peripheral.name ?? "unknown") [\(peripheral.identifier.uuidString)] error: \(error?.localizedDescription ?? "none")")
        if let error = error {
            self.statusText = "Failed to connect: \(error.localizedDescription)"
        }
    }
    
    // handle disconnects
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
