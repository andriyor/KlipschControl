//
//  KlipschControlApp.swift
//  KlipschControl
//
//  Created by William Leese on 17/02/2024.
//

import SwiftUI
import Foundation
import CoreBluetooth
import Combine

import os.log

let logger = Logger(subsystem: "KlipschControl", category: "Speaker")

let DEVICE_NAME = "Klipsch The Fives"

class Speaker: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate, ObservableObject {
    
    let VOLUME_UUID = "DA6D0FA2-0D18-442C-BABE-F85B5BAA6F11"
    let INPUT_UUID = "DA6D0FD2-0D18-442C-BABE-F85B5BAA6F11"
    let SERVICE_UUID = "DA6D0FA1-0D18-442C-BABE-F85B5BAA6F11"
    
    let objectWillChange = ObservableObjectPublisher()
    
    // Publish so our view is updated
    @Published var bluetoothReady = false
    @Published var deviceReady = false
    @Published var volume = Data([0x01])
    @Published var activeInput = Data([0x01])
    @Published var statusText = "Disconnected"
    
    var UUIDS: [String] = []
    
    // Core Bluetooth properties
    var centralManager: CBCentralManager!
    
    var connectedPeripheral: CBPeripheral?
    
    var characteristics: [String: CBCharacteristic] = [:]
    var descriptors: [String: [CBDescriptor]] = [:]
    
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
            descriptors.removeAll()
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
            logger.info("Bluetooth powered on; starting scan")
            triggerScan()
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
        self.statusText = "Restoring state"
        if bluetoothReady {
            if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
                logger.info("willRestoreState received \(peripherals.count) peripheral(s)")
                for peripheral in peripherals {
                    logger.info("Restoring peripheral: \(peripheral.name ?? "unknown") [\(peripheral.identifier.uuidString)]")
                    connectedPeripheral = peripheral
                    connectedPeripheral?.delegate = self
                    centralManager.connect(peripheral, options: nil)
                }
            } else {
                logger.info("willRestoreState received no peripherals to restore")
            }
        } else {
            self.statusText = "Bluetooth not ready for restore"
            logger.warning("willRestoreState called while bluetoothReady is false")
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
        descriptors.removeAll()
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
                peripheral.discoverDescriptors(for: characteristic)
                
                // read the volume value
                if characteristic.uuid.uuidString == VOLUME_UUID {
                    logger.info("Reading initial volume value from \(characteristic.uuid.uuidString)")
                    peripheral.readValue(for: characteristic)
                }
                
                // read the input value
                if characteristic.uuid.uuidString == INPUT_UUID {
                    logger.info("Reading initial input value from \(characteristic.uuid.uuidString)")
                    peripheral.readValue(for: characteristic)
                }
            }
        })

        // Some devices do not expose descriptors for every characteristic.
        // Mark the device as ready once all required characteristics are present.
        if characteristics.count == UUIDS.count {
            self.statusText = "" // We're good, no need for status text
            deviceReady = true
            logger.info("deviceReady set to true; discovered required characteristics: \(Array(self.characteristics.keys).sorted().joined(separator: ", "))")
        } else {
            logger.info("deviceReady still false; have \(self.characteristics.count)/\(self.UUIDS.count) required characteristics: \(Array(self.characteristics.keys).sorted().joined(separator: ", "))")
        }
    }
    
    // callback discovery of characteristic descriptors
    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        if UUIDS.contains(characteristic.uuid.uuidString) {
            descriptors[characteristic.uuid.uuidString] = characteristic.descriptors
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
            guard let data = characteristic.value else { return }
            let integerValue = data.withUnsafeBytes { $0.load(as: UInt8.self) }
            let percentage = Int((Double(integerValue) / 36.0) * 100.0)
            print("volume: \(integerValue) (\(percentage)%)")
            volume = data
            // Don't set deviceReady here - wait for all characteristics to be discovered
        }

        if characteristic.uuid.uuidString == INPUT_UUID {
            guard let data = characteristic.value else { return }
            activeInput = data
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
        connectedPeripheral = nil
        // Clear characteristics and descriptors on disconnect
        characteristics.removeAll()
        descriptors.removeAll()
        self.statusText = "Disconnected, reconnecting..."

        // Attempt to reconnect
        if bluetoothReady {
            logger.info("Bluetooth still ready after disconnect; restarting scan")
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        }
    }
    
    func disconnect() {
        if let connectedPeripheral {
            centralManager.cancelPeripheralConnection(connectedPeripheral)
        }
    }
    
    func switchInput(data: Data) {
        self.connectedPeripheral?.setNotifyValue(true, for: self.characteristics[INPUT_UUID]!)
        self.connectedPeripheral?.writeValue(data, for: self.characteristics[INPUT_UUID]!, type: .withResponse)
    }
    
    func volumeUp() {
        let integerValue = self.volume.withUnsafeBytes { $0.load(as: UInt8.self) }
        volume(data: Data([integerValue + 1]))
    }
    
    func volumeDown() {
        let integerValue = self.volume.withUnsafeBytes { $0.load(as: UInt8.self) }
        volume(data: Data([integerValue - 1]))
    }
    
    func volume(data: Data) {
        print("Characteristics: \(self.characteristics)")
        self.connectedPeripheral?.setNotifyValue(true, for: self.characteristics[VOLUME_UUID]!)
        self.connectedPeripheral?.writeValue(data, for: self.characteristics[VOLUME_UUID]!, type: .withResponse)
    }
}

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
