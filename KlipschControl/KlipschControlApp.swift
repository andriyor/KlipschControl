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
    let POWER_UUID = "DA6D0FE7-0D18-442C-BABE-F85B5BAA6F11"
    let INPUT_UUID = "DA6D0FD2-0D18-442C-BABE-F85B5BAA6F11"
    
    let objectWillChange = ObservableObjectPublisher()
    
    // Publish so our view is updated
    @Published var bluetoothReady = false
    @Published var deviceReady = false
    @Published var powerOn = false
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
        UUIDS = [VOLUME_UUID, POWER_UUID, INPUT_UUID]
        centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main, options: [CBCentralManagerOptionRestoreIdentifierKey: DEVICE_NAME])
    }
    
    func triggerScan() {
        self.statusText = "Looking for speaker"
        centralManager.scanForPeripherals(withServices: nil, options: nil)
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            bluetoothReady = true
            self.statusText = "Bluetooth is ready"
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        default:
            deviceReady = false
            powerOn = false
            bluetoothReady = false
            self.statusText = "Bluetooth not ready"
            break
        }
    }
    
    // Restore the connection to the peripherals
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        self.statusText = "Restoring state"
        if bluetoothReady {
            if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
                for peripheral in peripherals {
                    centralManager.connect(peripheral, options: nil)
                }
            }
        } else {
            self.statusText = "Bluetooth not ready for restore"
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        if peripheral.name == DEVICE_NAME {
            self.statusText = "Found our speaker"
            
            connectedPeripheral = peripheral
            connectedPeripheral!.delegate = self
            
            // Request a connection to the peripheral
            centralManager.connect(connectedPeripheral!, options: nil)
            
            // Stop scanning for peripherals
            centralManager.stopScan()
        }
    }
    
    // callback connect
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedPeripheral?.discoverServices(nil)
        self.statusText = "Connected to speaker"
    }
    
    // callback service
    func peripheral( _ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        self.statusText = "Discovering services"
        guard let services = peripheral.services, error == nil else {
            self.statusText = "An error occurred discovering services"
            return
        }
        for service in services {
            self.statusText = "Found service \(peripheral.name as String?)"
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    // callback found characteristic
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        self.statusText = "Discovered characteristic"
        if let error = error {
            self.statusText = "An error occurred discovering characteristics: " + error.localizedDescription
        }
        
        service.characteristics?.forEach({ characteristic in
            if UUIDS.contains(characteristic.uuid.uuidString) {
                characteristics[characteristic.uuid.uuidString] = characteristic
                peripheral.discoverDescriptors(for: characteristic)
                
                // read the volume value
                if characteristic.uuid.uuidString == VOLUME_UUID {
                    peripheral.readValue(for: characteristic)
                }
                
                // read the input value
                if characteristic.uuid.uuidString == INPUT_UUID {
                    peripheral.readValue(for: characteristic)
                }
                
                // read the power value
                if characteristic.uuid.uuidString == POWER_UUID {
                    peripheral.readValue(for: characteristic)
                }
            }
        })
    }
    
    // callback discovery of characteristic descriptors
    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        if UUIDS.contains(characteristic.uuid.uuidString) {
            descriptors[characteristic.uuid.uuidString] = characteristic.descriptors
            self.statusText = "" // We're good, no need for status text
            deviceReady = true
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
            volume = data
            deviceReady = true
        }
        
        if characteristic.uuid.uuidString == INPUT_UUID {
            guard let data = characteristic.value else { return }
            activeInput = data
        }
        
        if characteristic.uuid.uuidString == POWER_UUID {
            guard let data = characteristic.value else { return }
            if data == Data([0x01]) {
                powerOn = true
            } else {
                connectedPeripheral?.setNotifyValue(true, for: characteristic)
                connectedPeripheral?.writeValue(Data([0x01]), for: characteristic, type: .withResponse)
            }
        }
    }
    
    // handle fail to connects
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if let error = error {
            self.statusText = "Failed to connect: \(error.localizedDescription)"
        }
    }
    
    // handle disconnects
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        // no reason to yet..
    }
    
    func disconnect() {
        if let connectedPeripheral {
            centralManager.cancelPeripheralConnection(connectedPeripheral)
        }
    }
    
    func switchInput(data: Data) {
        ensureOn()
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
//        ensureOn()
        print("Characteristics: \(self.characteristics)")
        self.connectedPeripheral?.setNotifyValue(true, for: self.characteristics[VOLUME_UUID]!)
        self.connectedPeripheral?.writeValue(data, for: self.characteristics[VOLUME_UUID]!, type: .withResponse)
    }
    
    func ensureOn() {
        if !powerOn {
            self.connectedPeripheral?.setNotifyValue(true, for: self.characteristics[POWER_UUID]!)
            self.connectedPeripheral?.writeValue(Data([0x01]), for: self.characteristics[POWER_UUID]!, type: .withResponse)
        }
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
