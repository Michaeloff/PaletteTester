//
//  BTServiceHelper.swift
//  Aegle-Palette
//
//  Created by Ryan Peters on 4/5/16.
//  Copyright © 2016 Aegle Palette. All rights reserved.
//


import Foundation
import CoreBluetooth
import UIKit

/* Services & Characteristics UUIDs */
let bleServiceUUID = CBUUID(string: "FFF0")
let notifyCharUUID = CBUUID(string: "FFF4")
let writeCharUUID = CBUUID(string: "FFF2")

var previousPrecisionWeight: Double = 0
var previousKitchenWeight: Double = 0


class BTServiceHelper: NSObject {
    
    var peripheral: CBPeripheral?
    var notifyCharacteristic: CBCharacteristic?
    var writeCharacteristic: CBCharacteristic?
    
    init(initWithPeripheral peripheral: CBPeripheral) {
        
        super.init()
        
        print("PALETTE UUID: \(peripheral.identifier.uuidString)")
        self.peripheral = peripheral
        self.peripheral?.delegate = self
    }
    
    deinit {
        self.reset()
    }
    
    func startDiscoveringServices() {
        self.peripheral?.discoverServices([bleServiceUUID])
    }
    
    func reset() {
        if peripheral != nil {
            peripheral = nil
        }
    }
    
    func displayUpdateBytes(_ dataArray: [UInt8]) {
        var byteNum = 0
        
        for byte in dataArray {
            let hexFormat = byte < 0x10 ? "0" : ""
            print("Byte \(byteNum): 0x" + hexFormat + String(format: "%X", byte))
            byteNum += 1
        }
    }
    
    func sendBTServiceNotificationWithIsBluetoothConnected(_ isBluetoothConnected: Bool) {
        
        let connectionDetails = ["isConnected": isBluetoothConnected]
        NotificationCenter.default.post(name: Notification.Name(rawValue: "bleStatusChanged"), object: self, userInfo: connectionDetails)

        if (isBluetoothConnected == true) {
            flashLight()
        }
    }
    
    func turnOnLight(){
        
        if let writeCharacteristic = self.writeCharacteristic {
            
            let dataHelper = BTDataHelper()
            let data = dataHelper.getDataForLightOn() //as! Data
            self.peripheral?.writeValue(data, for: writeCharacteristic, type: CBCharacteristicWriteType.withResponse)
        }
    }
    
    func turnOffLight(){
        
        if let writeCharacteristic = self.writeCharacteristic {
            
            let dataHelper = BTDataHelper()
            let data = dataHelper.getDataForLightOff()
            self.peripheral?.writeValue(data, for: writeCharacteristic, type: CBCharacteristicWriteType.withResponse)
        }
    }
    
    func flashLight(){
        
        if let writeCharacteristic = self.writeCharacteristic {
            
            let dataHelper = BTDataHelper()
            let data = dataHelper.getDataForFlashLight() //as! Data
            self.peripheral?.writeValue(data, for: writeCharacteristic, type: CBCharacteristicWriteType.withResponse)
        }
    }
    
    func turnOffUnit(){
        
        if let writeCharacteristic = self.writeCharacteristic {
            
            let dataHelper = BTDataHelper()
            let data = dataHelper.getDataForUnitOff()
            self.peripheral?.writeValue(data, for: writeCharacteristic, type: CBCharacteristicWriteType.withResponse)
        }
    }
    
    func enterCalibrationMode(){
        
        if let writeCharacteristic = self.writeCharacteristic {
            
            let dataHelper = BTDataHelper()
            let data = dataHelper.getDataForCalibration()
            self.peripheral?.writeValue(data, for: writeCharacteristic, type: CBCharacteristicWriteType.withResponse)
        }
    }
    
    func tareScale() {
        
        // See if characteristic has been discovered before writing to it
        if let writeCharacteristic = self.writeCharacteristic {
            
            let dataHelper = BTDataHelper()
            let data = dataHelper.getDataForTare()
            
            self.peripheral?.writeValue(data, for: writeCharacteristic, type: CBCharacteristicWriteType.withResponse)
            
        }
    }
}

extension BTServiceHelper: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        let uuidsForBTService: [CBUUID] = [notifyCharUUID, writeCharUUID]
        
        if (peripheral != self.peripheral) {
            // Wrong Peripheral
            return
        }
        
        if (error != nil) {
            return
        }
        
        if ((peripheral.services == nil) || (peripheral.services!.count == 0)) {
            // No Services
            return
        }
        
        for service in peripheral.services! {
            if service.uuid == bleServiceUUID {
                peripheral.discoverCharacteristics(uuidsForBTService, for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        let signalStrength = ["signalStrength": RSSI]
        NotificationCenter.default.post(name: Notification.Name(rawValue: "signalStrength"), object: self, userInfo: signalStrength)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        peripheral.readRSSI()
        
        if characteristic.uuid == notifyCharUUID {
            
            let dataBytes = characteristic.value
            let dataLength = dataBytes!.count
            
            var dataArray = [UInt8](repeating: 0, count: dataLength)
            (dataBytes! as NSData).getBytes(&dataArray, length: dataLength * MemoryLayout<UInt8>.size)
            
            if dataArray.count < 7 {
                displayUpdateBytes(dataArray)
                let notif = Notification(name: Notification.Name(rawValue: "weight"), object: self, userInfo: ["weight":0.0, "isNegative":false, "dict":dataArray, "isOverload": false])
                NotificationCenter.default.post(notif)
                return
            }
            
            let weight = Double(dataArray[4]) * 256 + Double(dataArray[5])
            
            var isNegative = false
            
            if [0x04,
                0x05,
                0x14,
                0x15,
                0x24,
                0x25,
                0x34,
                0x35,
                4,
                5,
                14,
                15,
                24,
                25,
                34,
                35,
                0x3C,
                0x3D,
                0x0C,
                0x0D,
                0x1C,
                0x1D,
                0x2C,
                0x2D].contains(dataArray[1]){
                
                isNegative = true
            }
            
            var isOverload = false
            if dataArray[3] == 0x01{
                isOverload = true
            }
            
            let notif = Notification(name: Notification.Name(rawValue: "weight"), object: self, userInfo: ["weight":weight, "isNegative":isNegative, "dict":dataArray, "isOverload": isOverload])
            NotificationCenter.default.post(notif)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if (peripheral != self.peripheral) {
            // Wrong Peripheral
            return
        }
        
        if (error != nil) {
            return
        }
        
        if let characteristics = service.characteristics {
            
            for characteristic in characteristics {
                
                if characteristic.uuid == notifyCharUUID {
                    
                    self.notifyCharacteristic = (characteristic)
                    //var bin16:UInt16 = 0
                    //let wrapin: NSNumber = NSNumber(value: 0 as UInt16)
                    //bin16 = wrapin.uint16Value
                    
                    peripheral.setNotifyValue(true, for: characteristic)
                    
                    // Send notification that BLE is connected and all required characteristics are discovered
                    self.sendBTServiceNotificationWithIsBluetoothConnected(true)
                    
                }
                
                if characteristic.uuid == writeCharUUID {
                    self.writeCharacteristic = (characteristic)
                }
            }
        }
    }
}








