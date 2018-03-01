//
//  BTDiscoveryHelper.swift
//  Aegle-Palette
//
//  Created by Ryan Peters on 4/5/16.
//  Copyright © 2016 Aegle Palette. All rights reserved.
//


import Foundation
import CoreBluetooth
import UIKit

let btDiscoverySharedInstance = BTDiscoveryHelper()

class BTDiscoveryHelper: NSObject {
    
    fileprivate var centralManager: CBCentralManager?
    fileprivate var peripheralBLE: CBPeripheral?
    
    override init() {
        super.init()
    }
    
    func initCentralManager() {
        let centralQueue = DispatchQueue(label: "com.aeglepalette", attributes: [])
        centralManager = CBCentralManager(delegate: self, queue: centralQueue)
    }
    
    func startScanning() {
        if let central = centralManager {
            print ("BLE UUID: \(bleServiceUUID)")
            central.scanForPeripherals(withServices: [bleServiceUUID], options: nil)
            
            // Notify observers if a palette is already connected
            if let peripheral = peripheralBLE {
                if (peripheral.state == CBPeripheralState.connected) {
                    let palette = ["palette": peripheral]
                    NotificationCenter.default.post(name: Notification.Name(rawValue: "paletteFound"), object: self, userInfo: palette)
                }
            }
        }
    }
    
    func stopScanning() {
        if let central = centralManager {
            central.stopScan()
        }
    }
    
    func peripheralConnected() -> Bool {
        if let peripheral = peripheralBLE {
            if peripheral.state == CBPeripheralState.connected {
                return true
            }
        }
        return false
    }
    
    func connectPalette(peripheral: CBPeripheral) {
        print("connectPalette: \(peripheral.identifier.uuidString)")
        
        // If not already connected to this peripheral, then attempt to connect
        if (peripheral.state == CBPeripheralState.disconnected) {
            
            // Retain the peripheral before trying to connect
            self.peripheralBLE = peripheral
                
            // Reset service
            self.bleService = nil
                
            // Connect to peripheral
            if let central = centralManager {
                central.connect(peripheral, options: nil)
            }
        }
        else {
            print("not disconnected yet")
        }
    }
    
    func disconnectPalette() {
        if let peripheral = peripheralBLE, let central = centralManager {
            print("disconnectPalette \(peripheral.identifier.uuidString)")
            // If connected, then attempt to disconnect
            if (peripheral.state == CBPeripheralState.connected) {
                central.cancelPeripheralConnection(peripheral)
            }
        }
    }
    
    func clearDevices() {
        self.bleService = nil
        self.peripheralBLE = nil
    }
    
    var bleService: BTServiceHelper? {
        didSet {
            if let service = self.bleService {
                service.startDiscoveringServices()
            }
        }
    }
}

// Extension for CBCentralManagerDelegate methods. Used for code cleanliness.
extension BTDiscoveryHelper: CBCentralManagerDelegate {
    
    // Called when a CBCentralManager object is created
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        switch (central.state) {
        case .poweredOff:
            break
        case .unauthorized:
            // Indicate to user that the iOS device does not support BLE.
            break
        case .unknown:
            // Wait for another event
            break
        case .poweredOn:
            let isPoweredOn = ["isPoweredOn": true]
            NotificationCenter.default.post(name: Notification.Name(rawValue: "isPoweredOn"), object: self, userInfo: isPoweredOn)
            break
        case .resetting:
            break
        case .unsupported:
            break
        }
    }
    
    // Called after centralManager.scanForPeripherals() when a peripheral is discovered
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
 
        // Notify observers that a palette was discovered
        let palette = ["palette": peripheral]
        NotificationCenter.default.post(name: Notification.Name(rawValue: "paletteFound"), object: self, userInfo: palette)
    }
    
    // Called after centralManager.connect() when a peripheral connects
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {

        // Create new service class
        if (peripheral == self.peripheralBLE) {
            print ("new service")
            self.bleService = BTServiceHelper(initWithPeripheral: peripheral)
        }
    }
    
    // Called after centralManager.connect() when a peripheral disconnects
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        
        // See if it was our Palette that disconnected
        if (peripheral == self.peripheralBLE) {
            self.clearDevices()
            
            let connectionDetails = ["isConnected": false]
            NotificationCenter.default.post(name: Notification.Name(rawValue: "bleStatusChanged"), object: self, userInfo: connectionDetails)
        }
    }
}
