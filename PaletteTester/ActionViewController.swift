//
//  ViewController.swift
//  PaletteTester
//
//  Created by David Michaeloff on 2/5/17.
//  Copyright © 2017 David Michaeloff. All rights reserved.
//

import UIKit

class ActionViewController: UIViewController {

    @IBOutlet weak var labelPaletteName: UILabel!
    @IBOutlet weak var textFieldWeight: UITextField!
    @IBOutlet weak var labelOverloaded: UILabel!
    @IBOutlet weak var textViewStatus: UITextView!
    
    var paletteName = ""
    var previousWeight = 0.0
    var previousWeightData: UInt8 = 0x00
    var updateCount = 0
    var isNegative = false
    let darkGreen = UIColor(red: 0, green: 170/255, blue: 0, alpha: 1)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.initControls()
        self.addObservers()
    }

    func initControls() {
        labelPaletteName.text = "Name: " + paletteName
        textViewStatus.layer.borderColor = UIColor.black.cgColor
        textViewStatus.layer.borderWidth = 1.0
        textViewStatus.layer.cornerRadius = 5
    }
    
    func addObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.updateConnectedLabel),
            name: NSNotification.Name(rawValue: "bleStatusChanged"),
            object: nil)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.updateWeightLabel),
            name: NSNotification.Name(rawValue: "weight"),
            object: nil)
    }
    
    func updateConnectedLabel(_ notification: Notification) {
        guard
            let userInfo = (notification as NSNotification).userInfo
            else { return }
        
        if let isConnected = userInfo["isConnected"] as? Bool {
            if !isConnected {
                DispatchQueue.main.async {
                    self.textViewStatus.text.append("** PALETTE DISCONNECTED **\n")
                    self.textViewStatus.scrollRangeToVisible(NSMakeRange(self.textViewStatus.text.characters.count - 1, 1))
                }
            }
        }
    }
    
    func updateWeightLabel(_ notification: Notification) {
        guard
            let userInfo = (notification as NSNotification).userInfo,
            let weight = userInfo["weight"] as? Double,
            let isNegative = userInfo["isNegative"] as? Bool,
            let isOverloaded = userInfo["isOverload"] as? Bool,
            let dataArray = userInfo["dict"] as? [UInt8]
            else {
                print("Unable to update weight, missing user info.")
                return
            }
        
        updateCount += 1
        if (self.updateCount % 100) == 0 {
            DispatchQueue.main.async {
                self.textViewStatus.text.append("Number of update calls: \(self.updateCount)\n")
            }
        }

        if dataArray.count < 7 {
            DispatchQueue.main.async {
                self.textViewStatus.text.append("** BYTES MISSING FROM DATA: \(self.formatDataBytesToString(dataArray))\n")
            }
        }

        let weightData = dataArray.count > 1 ? dataArray[1] : 0x00
        
        var weightChanged = false
        if (self.previousWeight != weight) {
            weightChanged = true
            self.previousWeight = weight
        }
        
        if (self.isNegative != isNegative) {
            weightChanged = true
            self.isNegative = isNegative
        }
        
        var dataChanged = false
        if (self.previousWeightData != weightData) {
            dataChanged = true
            self.previousWeightData = weightData
        }
        
        if weightChanged || dataChanged {
            let newWeight = isNegative ? String(-1 * self.previousWeight) : String(self.previousWeight)
            self.textFieldWeight.textColor = isNegative ? UIColor.red : self.darkGreen

            DispatchQueue.main.async {
                self.textFieldWeight.text = newWeight
                self.labelOverloaded.text = isOverloaded ? "Overloaded" : "grams"
                self.labelOverloaded.textColor = isOverloaded ? UIColor.red : UIColor.black
                
                self.textViewStatus.text.append("Data array: \(self.formatDataBytesToString(dataArray))\n")
                self.textViewStatus.text.append("Combo byte: \(weightData) = ")
                self.textViewStatus.text.append(self.getWeightString(dataByte: weightData))
                self.textViewStatus.text.append("Weight = \(newWeight)\n")
                self.textViewStatus.text.append("----------------------\n")

                self.textViewStatus.scrollRangeToVisible(NSMakeRange(self.textViewStatus.text.characters.count - 1, 1))
            }
        }
    }
    
    func formatDataBytesToString(_ dataArray: [UInt8]) -> String {
        var dataString = ""
   
        for byte in dataArray {
            let hexFormat = byte < 0x10 ? "0" : ""
            dataString.append(hexFormat + String(format: "%X", byte) + " ")
        }
        return dataString
    }
    
    @IBAction func buttonTare(_ sender: UIButton) {
        btDiscoverySharedInstance.bleService?.tareScale() // Tares scale, any other write functionality is handled the same way
        self.textViewStatus.text.append("Tare button touched\n")
        self.textViewStatus.scrollRangeToVisible(NSMakeRange(self.textViewStatus.text.characters.count - 1, 1))
    }
    
    @IBAction func buttonTurnBacklightOn(_ sender: UIButton) {
        btDiscoverySharedInstance.bleService?.turnOnLight()
        self.textViewStatus.text.append("Turn Light On button touched\n")
        self.textViewStatus.scrollRangeToVisible(NSMakeRange(self.textViewStatus.text.characters.count - 1, 1))
    }

    
    @IBAction func buttonTurnBacklightOff(_ sender: UIButton) {
        btDiscoverySharedInstance.bleService?.turnOffLight()
        self.textViewStatus.text.append("Turn Light Off button touched\n")
        self.textViewStatus.scrollRangeToVisible(NSMakeRange(self.textViewStatus.text.characters.count - 1, 1))
    }
    
    @IBAction func buttonFlashBacklight5x(_ sender: UIButton) {
        btDiscoverySharedInstance.bleService?.flashLight()
        self.textViewStatus.text.append("Blink On/Off button touched\n")
        self.textViewStatus.scrollRangeToVisible(NSMakeRange(self.textViewStatus.text.characters.count - 1, 1))
    }
    
    @IBAction func buttonPowerOff(_ sender: UIButton) {
        btDiscoverySharedInstance.bleService?.turnOffUnit()
        self.textViewStatus.text.append("Power Off button touched\n")
        self.textViewStatus.scrollRangeToVisible(NSMakeRange(self.textViewStatus.text.characters.count - 1, 1))
    }
    
    func getWeightString(dataByte: UInt8) -> String {
        var msg = ""
        switch dataByte {
        case 0x00: msg = "Dynamic weight, weight is postive, voltage > 2.8V\n"
        case 0x01: msg = "Stable weight, weight is postive, voltage > 2.8V\n"
        case 0x02: msg = "Calibration mode, voltage > 2.8V\n"
        case 0x04: msg = "Dynamic weight, weight is negative number, voltage > 2.8V\n"
        case 0x05: msg = "Stable weight, weight is negative number, voltage > 2.8V\n"
        case 0x08: msg = "Tared, dynamic weight, weight is positive number, voltage > 2.8V\n"
        case 0x09: msg = "Tared, stable weight, weight is positive number, voltage > 2.8V\n"
        case 0x0C: msg = "Tared, dynamic weight, weight is negative number, voltage > 2.8V\n"
        case 0x0D: msg = "Tared, stable weight, weight is negative number, voltage > 2.8V\n"
        case 0x10: msg = "Dynamic weight, weight is postive, 2.8V > voltage > 2.6V\n"
        case 0x11: msg = "Stable weight, weight is postive, 2.8V > voltage > 2.6V\n"
        case 0x12: msg = "Calibration mode, 2.8V > voltage > 2.6V\n"
        case 0x14: msg = "Dynamic weight, weight is negative number, 2.8V > voltage > 2.6V\n"
        case 0x15: msg = "Stable weight, weight is negative number, 2.8V > voltage > 2.6V\n"
        case 0x18: msg = "Tared, dynamic weight, weight is positive number, 2.8V > voltage > 2.6V\n"
        case 0x19: msg = "Tared, stable weight, weight is positive number, 2.8V > voltage > 2.6V\n"
        case 0x1C: msg = "Tared, dynamic weight, weight is negative number, 2.8V > voltage > 2.6V\n"
        case 0x1D: msg = "Tared, stable weight, weight is negative number, 2.8V > voltage > 2.6V\n"
        case 0x20: msg = "Dynamic weight, weight is postive, 2.6V > voltage > 2.5V\n"
        case 0x21: msg = "Stable weight, weight is postive, 2.6V > voltage > 2.5\n"
        case 0x22: msg = "Calibration mode, 2.6V > voltage > 2.5V\n"
        case 0x24: msg = "Dynamic weight, weight is negative number, 2.6V > voltage > 2.5V\n"
        case 0x25: msg = "Stable weight, weight is negative number, 2.6V > voltage > 2.5V\n"
        case 0x28: msg = "Tared, dynamic weight, weight is positive number, 2.6V > voltage > 2.5V\n"
        case 0x29: msg = "Tared, stable weight, weight is positive number, 2.6V > voltage > 2.5V\n"
        case 0x2C: msg = "Tared, dynamic weight, weight is negative number, 2.6V > voltage > 2.5V\n"
        case 0x2D: msg = "Tared, stable weight, weight is negative number, 2.6V > voltage > 2.5V\n"
        case 0x30: msg = "Dynamic weight, weight is postive, 2.5V > voltage > 2.3V\n"
        case 0x31: msg = "Stable weight, weight is postive, 2.5V > voltage > 2.3\n"
        case 0x32: msg = "Calibration mode, 2.5V > voltage > 2.3V\n"
        case 0x34: msg = "Dynamic weight, weight is negative number, 2.5V > voltage > 2.3V\n"
        case 0x35: msg = "Stable weight, weight is negative number, 2.5V > voltage > 2.3V\n"
        case 0x38: msg = "Tared, dynamic weight, weight is positive number, 2.5V > voltage > 2.3V\n"
        case 0x39: msg = "Tared, stable weight, weight is positive number, 2.5V > voltage > 2.3V\n"
        case 0x3C: msg = "Tared, dynamic weight, weight is negative number, 2.5V > voltage > 2.3V\n"
        case 0x3D: msg = "Tared, stable weight, weight is negative number, 2.5V > voltage > 2.3V\n"
        default: ()
        }
        return msg
    }
}


