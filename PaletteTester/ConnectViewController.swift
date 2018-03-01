//
//  ConnectViewController.swift
//  PaletteTester
//
//  Created by David Michaeloff on 2/7/17.
//  Copyright © 2017 David Michaeloff. All rights reserved.
//

import UIKit
import CoreBluetooth

class ConnectViewController: UIViewController {

    @IBOutlet weak var labelPaletteName: UILabel!
    @IBOutlet weak var labelPaletteStatus: UILabel!
    @IBOutlet weak var buttonConnect: UIButton!
    @IBOutlet weak var buttonName: UIButton!
    @IBOutlet weak var segSignalStrength: UISegmentedControl!
    @IBOutlet weak var labelSignalStrength: UILabel!
    @IBOutlet weak var buttonPaletteActions: UIButton!
    
    var palette: CBPeripheral?
    var paletteName = ""
    var paletteUuid = ""
    var isConnected = false
    var pendingConnect = false
    var versionNum = "N/A"
    let darkGreen = UIColor(red: 0, green: 180/255, blue: 0, alpha: 1)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.initControls()
        self.addObservers()
    }
    
    func initControls() {
        guard let palette = self.palette else { return }
        
        let paletteNameSaved = UserDefaults.standard.string(forKey: palette.identifier.uuidString)
        paletteUuid = palette.identifier.uuidString
        paletteName = (paletteNameSaved ?? paletteUuid)
        labelPaletteName.text = "Name: " + paletteName
        
        isConnected = (palette.state == CBPeripheralState.connected)
        let statusText = isConnected ? "Connected" : "Not Connected"
        labelPaletteStatus.text = "Status: " + statusText + ", Version: " + versionNum
        
        buttonConnect.setTitle((isConnected ? "Disconnect" : "Connect"), for: UIControlState.normal)
        if !isConnected { segSignalStrength.tintColor = UIColor.lightGray }
        segSignalStrength.isEnabled = isConnected ? true : false
        labelSignalStrength.textColor = isConnected ? UIColor.darkGray : UIColor.lightGray
        buttonPaletteActions.isEnabled = isConnected ? true : false
    }
    
    func addObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.updateConnectionStatus),
            name: NSNotification.Name(rawValue: "bleStatusChanged"),
            object: nil)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.updateVersionLabel),
            name: NSNotification.Name(rawValue: "weight"),
            object: nil)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.updateSignalStrength),
            name: NSNotification.Name(rawValue: "signalStrength"),
            object: nil)
    }
    
    func updateConnectionStatus(_ notification: Notification) {
        guard
            let userInfo = (notification as NSNotification).userInfo
            else { return }
        
        if let isConnected = userInfo["isConnected"] as? Bool {
            if pendingConnect && !isConnected {
                pendingConnect = false
                if let palette = self.palette {
                    btDiscoverySharedInstance.connectPalette(peripheral: palette)
                }
                return
            }
            if self.isConnected != isConnected {
                DispatchQueue.main.async {
                    self.initControls()
                    
                    if self.isConnected {
                        let hud = HUD(text: "Connected to \(self.paletteName)")
                        self.view.addSubview(hud)
                        hud.show()
                    }
                }
            }
        }
    }
    
    func updateVersionLabel(_ notification: Notification) {
        guard
            let userInfo = (notification as NSNotification).userInfo
            else { return }
        
        if let dataArray = userInfo["dict"] as? [UInt8] {
            if dataArray.count < 7 { return }
            
            versionNum = String(Double(dataArray[2]) / 10)
            
            // Notification is frequent, so once version is obtained remove it. Update: need notif for signal strength
            //NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "weight"), object: nil)
            
            DispatchQueue.main.async {
                self.initControls()
            }
        }
    }
    
    // High quality: 90% ~= -55db
    // Medium quality: 50% ~= -75db
    // Low quality: 30% ~= -85db
    // Unusable quality: 8% ~= -96db
    func updateSignalStrength(_ notification: Notification) {
        guard
            let userInfo = (notification as NSNotification).userInfo, isConnected
            else { return }
        
        if let signalStrength = userInfo["signalStrength"] as? NSNumber {

            DispatchQueue.main.async {
                switch Int(signalStrength) {
                case let x where x < -85:
                    self.segSignalStrength.selectedSegmentIndex = 0
                    self.segSignalStrength.tintColor = UIColor.red
                case -85 ..< -75:
                    self.segSignalStrength.selectedSegmentIndex = 1
                    self.segSignalStrength.tintColor = UIColor.orange
                case -75 ..< -55:
                    self.segSignalStrength.selectedSegmentIndex = 2
                    self.segSignalStrength.tintColor = self.darkGreen
                case let x where x > -55:
                    self.segSignalStrength.selectedSegmentIndex = 3
                    self.segSignalStrength.tintColor = self.darkGreen
                default: ()
                }
            }
        }
    }
    
    func namePalette() {
        let alert = UIAlertController(title: "Name Palette", message: "What would you like to name this Palette?", preferredStyle: .alert)
        alert.addTextField(configurationHandler: nil)
        alert.addAction(UIAlertAction(title: "Save", style: .default, handler: { action in
            let userEnteredName = alert.textFields?[0].text ?? ""
            if userEnteredName != "" {
                UserDefaults.standard.set(userEnteredName, forKey: self.paletteUuid)
                self.paletteName = userEnteredName
                self.labelPaletteName.text = "Name: " + self.paletteName
            }
        }))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    @IBAction func buttonTouchConnectPalette(_ sender: UIButton) {
        guard let palette = self.palette else { return }
        
        if isConnected {
            btDiscoverySharedInstance.disconnectPalette()
        }
        else if btDiscoverySharedInstance.peripheralConnected() {
            handleDifferentPaletteConnected()
        }
        else {
            btDiscoverySharedInstance.connectPalette(peripheral: palette)
        }
    }
    
    func handleDifferentPaletteConnected () {
        let alertController = UIAlertController(
            title: "Another Palette Connected",
            message: "A different Palette is already connected. Would you like to disconnect the other one and connect this one?",
            preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)

        let okAction = UIAlertAction(title: "OK", style: .default) { (action) in
            self.pendingConnect = true
            btDiscoverySharedInstance.disconnectPalette()
        }
        alertController.addAction(okAction)
        self.present(alertController, animated: true, completion: nil)
    }
    
    @IBAction func buttonTouchNamePalette(_ sender: UIButton) {
        namePalette()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destination = segue.destination as? ActionViewController {
            destination.paletteName = paletteName
        }
    }
}


class HUD: UIVisualEffectView {
    
    var text: String? {
        didSet {
            label.text = text
        }
    }
    let label: UILabel = UILabel()
    let blurEffect = UIBlurEffect(style: UIBlurEffectStyle.dark)
    let vibrancyView: UIVisualEffectView
    
    init(text: String) {
        self.text = text
        self.vibrancyView = UIVisualEffectView(effect: UIVibrancyEffect(blurEffect: blurEffect))
        super.init(effect: blurEffect)
        self.setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.text = ""
        self.vibrancyView = UIVisualEffectView(effect: UIVibrancyEffect(blurEffect: blurEffect))
        super.init(coder: aDecoder)
        self.setup()
        
    }
    
    func setup() {
        contentView.addSubview(vibrancyView)
        vibrancyView.contentView.addSubview(label)
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        
        if let superview = self.superview {
            
            let width = superview.frame.size.width / 1.4  // Changed from 2.3 to 1.4 for test app
            let height: CGFloat = 50.0
            print ("width: \(width)")
            print ("height: \(height)")
            print ("frame: \(superview.frame)")
            self.frame = CGRect(x: superview.frame.size.width / 2 - width / 2,
                                y: superview.frame.height / 2 - height / 2,
                                width: width,
                                height: height)
            vibrancyView.frame = self.bounds
            
            layer.cornerRadius = 8.0
            layer.masksToBounds = true
            label.text = text
            label.textAlignment = NSTextAlignment.center
            label.frame = CGRect(x: 0, y: 0, width: width, height: height)
            label.textColor = UIColor.black
            label.font = UIFont.boldSystemFont(ofSize: 16)
        }
    }
    
    func show() {
        self.isHidden = false
        self.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
        self.alpha = 0
        
        UIView.animate(withDuration: 0.3, animations:{
            
            self.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
            self.alpha = 1
            
        }, completion: {
            (value: Bool) in
            
            UIView.animate(withDuration: 0.3, delay: 1.5, options: UIViewAnimationOptions(), animations: {
                
                self.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
                self.alpha = 0
                
            },completion: {
                (value: Bool) in
                
                self.removeFromSuperview()
            })
        })
    }
}
