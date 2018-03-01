//
//  BluetoothDataHelper.swift
//  Aegle-Palette
//
//  Created by Ryan Peters on 4/7/16.
//  Copyright © 2016 Aegle Palette. All rights reserved.
//

import Foundation

class BTDataHelper: NSObject {
    
    func getDataForTare() -> Foundation.Data {
        
        let header: UInt8 = 0xFA
        let ctrlCmd: UInt8 = 0x01
        let dataBytes: [UInt8] = [header, ctrlCmd,0x00,0x00,0x00,0x00,0xFB]
        
        return Foundation.Data(bytes: UnsafePointer<UInt8>(dataBytes), count: 7)
    }
    
    func getDataForLightOn() -> Foundation.Data{
        
        let header: UInt8 = 0xFA
        let ctrlCmd: UInt8 = 0x03
        let dataBytes: [UInt8] = [header, ctrlCmd,0x00,0x00,0x00,0xF9]
        
        return Foundation.Data(bytes: UnsafePointer<UInt8>(dataBytes), count: 6)
    }
    
    func getDataForLightOff() -> Foundation.Data{
        
        let header: UInt8 = 0xFA
        let ctrlCmd: UInt8 = 0x04
        let dataBytes: [UInt8] = [header, ctrlCmd,0x00,0x00,0x00,0xFE]
        
        return Foundation.Data(bytes: UnsafePointer<UInt8>(dataBytes), count: 6)
    }
    
    func getDataForFlashLight() -> Foundation.Data{
        
        let header: UInt8 = 0xFA
        let ctrlCmd: UInt8 = 0x06
        let dataBytes: [UInt8] = [header, ctrlCmd,0x00,0x00,0x00,0x00,0xFC]
        
        return Foundation.Data(bytes: UnsafePointer<UInt8>(dataBytes), count: 7)
    }
    
    func getDataForUnitOff() -> Foundation.Data{
        
        let header: UInt8 = 0xFA
        let ctrlCmd: UInt8 = 0x02
        let dataBytes: [UInt8] = [header, ctrlCmd,0x00,0x00,0x00,0x00,0xF8]
        
        return Foundation.Data(bytes: UnsafePointer<UInt8>(dataBytes), count: 7)
    }

    func getDataForCalibration() -> Foundation.Data{
        
        let header: UInt8 = 0xFA
        let ctrlCmd: UInt8 = 0x05
        let dataBytes: [UInt8] = [header, ctrlCmd,0x00,0x00,0x00,0x00,0xFF]
        
        return Foundation.Data(bytes: UnsafePointer<UInt8>(dataBytes), count: 7)
    }
    
}

