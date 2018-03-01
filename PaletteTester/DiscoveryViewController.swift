//
//  DiscoveryViewController.swift
//  PaletteTester
//
//  Created by David Michaeloff on 2/7/17.
//  Copyright © 2017 David Michaeloff. All rights reserved.
//

import UIKit
import CoreBluetooth

class DiscoveryViewController: UIViewController {

    @IBOutlet weak var tableViewPalettes: UITableView!
    @IBOutlet weak var labelSelectPalette: UILabel!
    
    let textCellIdentifier = "TextCell"
    var paletteItems: [CBPeripheral] = []
    var managerPoweredOn = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.initTable()
        self.addObservers()
        btDiscoverySharedInstance.initCentralManager()
    }

    override func viewDidAppear(_ animated: Bool) {
        if managerPoweredOn {
            discoverPalettes()
        }
    }
    
    func addObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.isPoweredOn),
            name: NSNotification.Name(rawValue: "isPoweredOn"),
            object: nil)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.addDiscoveredPalettes),
            name: NSNotification.Name(rawValue: "paletteFound"),
            object: nil)
    }
    
    func isPoweredOn(_ notification: Notification) {
        guard
            let userInfo = (notification as NSNotification).userInfo
            else { return }
        
        if let isPoweredOn = userInfo["isPoweredOn"] as? Bool {
            self.managerPoweredOn = isPoweredOn
        }
    }
    
    func addDiscoveredPalettes(_ notification: Notification) {
        guard
            let userInfo = (notification as NSNotification).userInfo
            else { return }
        
        if let palette = userInfo["palette"] as? CBPeripheral {
            if !paletteItems.contains(palette) {
                paletteItems.append(palette)
                updateTable()
            }
        }
    }
    
    func updateTable() {
        DispatchQueue.main.async {
            self.tableViewPalettes.reloadData()
        }
    }
    
    func discoverPalettes() {
        paletteItems.removeAll()
        updateTable()
        btDiscoverySharedInstance.startScanning()
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if let paletteIndex = tableViewPalettes.indexPathForSelectedRow?.row,
            paletteItems.count > paletteIndex {
            return true
        }
        return false
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destination = segue.destination as? ConnectViewController,
            let paletteIndex = tableViewPalettes.indexPathForSelectedRow?.row {
            destination.palette = paletteItems[paletteIndex]
            btDiscoverySharedInstance.stopScanning()
        }
    }
    
    @IBAction func buttonTouchedDiscoverPalettes(_ sender: UIButton) {
        discoverPalettes()
    }
}

// Extension for table-related methods. Used for code cleanliness.
extension DiscoveryViewController: UITableViewDelegate, UITableViewDataSource  {
    
    func initTable() {
        tableViewPalettes.delegate = self
        tableViewPalettes.dataSource = self
        tableViewPalettes.layer.borderWidth = 1.0
        tableViewPalettes.layer.borderColor = UIColor.lightGray.cgColor
        tableViewPalettes.contentInset = UIEdgeInsetsMake(-60, 0, 0, 0)
    }
    
    // Table methods
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if paletteItems.count == 0 {
            return 1 // Loads dummy cell notifying user that there are no Palettes found
        }
        else {
            return paletteItems.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableViewPalettes.dequeueReusableCell(withIdentifier: textCellIdentifier, for: indexPath)
        if paletteItems.count > 0 {
            let palette = paletteItems[indexPath.row]
            let paletteUuid = palette.identifier.uuidString
            let paletteName = UserDefaults.standard.string(forKey: paletteUuid)
            let isConnected = (palette.state == CBPeripheralState.connected) ? " (connected)" : ""
            cell.textLabel?.text = (paletteName ?? paletteUuid) + isConnected
            labelSelectPalette.isHidden = false
        }
        else {
            cell.textLabel?.text = "<No Palettes Found>"
            labelSelectPalette.isHidden = true
        }
        return cell
    }
}
