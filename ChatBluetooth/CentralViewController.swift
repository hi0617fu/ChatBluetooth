//
//  CentralViewController.swift
//  ChatBluetooth
//
//  Created by se on 2020/11/09.
//
import Foundation
import UIKit
import CoreBluetooth
import os

var rxCharacteristic: CBCharacteristic?
var txCharacteristic: CBCharacteristic?
var characteristicASCIIValue = NSString()
var discoveredPeripheral:  CBPeripheral?

class CentralViewController: UIViewController {

    @IBOutlet weak var baseTableView: UITableView!
    @IBOutlet weak var refreshButton: UIBarButtonItem!

    var peripherals: [CBPeripheral] = []
    var characteristicValue = [CBUUID: NSData]()
    var timer = Timer()
    var characteristics = [String : CBCharacteristic]()

     var centralManager: CBCentralManager!
     var peripheralManager: CBPeripheralManager?
     var transferCharacteristic: CBCharacteristic?
     var writeIterationsComplete = 0
     var connectionIterationsComplete = 0
     private var consoleAsciiText: NSAttributedString? = NSAttributedString(string: "")
     let defaultIterations = 5
     var data = Data()
     
     override func viewDidLoad() {
         centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: true])
        self.baseTableView.delegate = self
        self.baseTableView.dataSource = self
        self.baseTableView.reloadData()
        let backButton = UIBarButtonItem(title: "Disconnect", style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backButton
     }
     
     override func viewWillDisappear(_ animated: Bool) {
         // Don't keep it going while we're not showing.
         centralManager.stopScan()
         os_log("Scanning stopped")
         data.removeAll(keepingCapacity: false)
         super.viewWillDisappear(animated)
     }

     private func retrievePeripheral() {
         
         let connectedPeripherals: [CBPeripheral] = (centralManager.retrieveConnectedPeripherals(withServices: [TransferService.serviceUUID]))
         
         os_log("Found connected Peripherals with transfer service: %@", connectedPeripherals)
         
         if let connectedPeripheral = connectedPeripherals.last {
             os_log("Connecting to peripheral %@", connectedPeripheral)
             discoveredPeripheral = connectedPeripheral
             centralManager.connect(connectedPeripheral, options: nil)
         } else {
             // We were not connected to our counterpart, so start scanning
             centralManager.scanForPeripherals(withServices: [TransferService.serviceUUID],
                                                options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
         }
     }
     
     private func cleanup() {
         // Don't do anything if we're not connected
         guard let discoveredPeripheral = discoveredPeripheral,
             case .connected = discoveredPeripheral.state else { return }
         
         for service in (discoveredPeripheral.services ?? [] as [CBService]) {
             for characteristic in (service.characteristics ?? [] as [CBCharacteristic]) {
                 if characteristic.uuid == TransferService.characteristic_Rx_UUID && characteristic.isNotifying {
                     // It is notifying, so unsubscribe
                     discoveredPeripheral.setNotifyValue(false, for: characteristic)
                 }
             }
         }
         
         // If we've gotten this far, we're connected, but we're not subscribed, so we just disconnect
         centralManager.cancelPeripheralConnection(discoveredPeripheral)
     }
    
    @IBAction func refreshAction(_ sender: AnyObject) {
        cleanup()
        self.peripherals = []
        self.baseTableView.reloadData()
        retrievePeripheral()
    }
 }

 extension CentralViewController: CBCentralManagerDelegate {
     internal func centralManagerDidUpdateState(_ central: CBCentralManager) {

         switch central.state {
         case .poweredOn:
             // ... so start working with the peripheral
             os_log("CBManager is powered on")
             retrievePeripheral()
         case .poweredOff:
             os_log("CBManager is not powered on")
             // In a real app, you'd deal with all the states accordingly
             return
         case .resetting:
             os_log("CBManager is resetting")
             // In a real app, you'd deal with all the states accordingly
             return
         case .unauthorized:
             return
         case .unknown:
             os_log("CBManager state is unknown")
             // In a real app, you'd deal with all the states accordingly
             return
         case .unsupported:
             os_log("Bluetooth is not supported on this device")
             // In a real app, you'd deal with all the states accordingly
             return
         @unknown default:
             os_log("A previously unknown central manager state occurred")
             // In a real app, you'd deal with yet unknown cases that might occur in the future
             return
         }
     }

     func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                         advertisementData: [String: Any], rssi RSSI: NSNumber) {
         
         // Reject if the signal strength is too low to attempt data transfer.
         // Change the minimum RSSI value depending on your app’s use case.
         guard RSSI.intValue >= -50
             else {
                 os_log("Discovered perhiperal not in expected range, at %d", RSSI.intValue)
                 return
         }
         
         os_log("Discovered %s at %d", String(describing: peripheral.name), RSSI.intValue)
         
         // Device is in range - have we already seen it?
         if discoveredPeripheral != peripheral {
             
             // Save a local copy of the peripheral, so CoreBluetooth doesn't get rid of it.
             discoveredPeripheral = peripheral
             
             // And finally, connect to the peripheral.
             os_log("Connecting to perhiperal %@", peripheral)
             centralManager.connect(peripheral, options: nil)
         }
     }

     /*
      *  If the connection fails for whatever reason, we need to deal with it.
      */
     func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
         os_log("Failed to connect to %@. %s", peripheral, String(describing: error))
         cleanup()
     }
     
     /*
      *  We've connected to the peripheral, now we need to discover the services and characteristics to find the 'transfer' characteristic.
      */
     func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
         os_log("Peripheral Connected")
         
         // Stop scanning
         centralManager.stopScan()
         os_log("Scanning stopped")
         
         // set iteration info
         connectionIterationsComplete += 1
         writeIterationsComplete = 0
         
         // Clear the data that we may already have
         data.removeAll(keepingCapacity: false)
         
         // Make sure we get the discovery callbacks
         peripheral.delegate = self
         
         // Search only for services that match our UUID
         peripheral.discoverServices([TransferService.serviceUUID])
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let centralChatBox = storyboard.instantiateViewController(withIdentifier: "CentralChatBox") as! CentralChatBox
        
        navigationController?.pushViewController(centralChatBox, animated: true)
     }
     
     /*
      *  Once the disconnection happens, we need to clean up our local copy of the peripheral
      */
     func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
         os_log("Perhiperal Disconnected")
         discoveredPeripheral = nil
         
         // We're disconnected, so start scanning again
         if connectionIterationsComplete < defaultIterations {
             retrievePeripheral()
         } else {
             os_log("Connection iterations completed")
         }
     }

 }

 extension CentralViewController: CBPeripheralDelegate {
     func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
         
         for service in invalidatedServices where service.uuid == TransferService.serviceUUID {
             os_log("Transfer service is invalidated - rediscover services")
             peripheral.discoverServices([TransferService.serviceUUID])
         }
     }

     /*
      *  The Transfer Service was discovered
      */
     func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
         if let error = error {
             os_log("Error discovering services: %s", error.localizedDescription)
             cleanup()
             return
         }
         
         // Discover the characteristic we want...
         
         // Loop through the newly filled peripheral.services array, just in case there's more than one.
         guard let peripheralServices = peripheral.services else { return }
         for service in peripheralServices {
             peripheral.discoverCharacteristics([TransferService.characteristic_Rx_UUID, TransferService.characteristic_Tx_UUID], for: service)
         }
     }
     
     /*
      *  The Transfer characteristic was discovered.
      *  Once this has been found, we want to subscribe to it, which lets the peripheral know we want the data it contains
      */
     func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
         // Deal with errors (if any).
         if let error = error {
             os_log("Error discovering characteristics: %s", error.localizedDescription)
             cleanup()
             return
         }
         
         // Again, we loop through the array, just in case and check if it's the right one
         guard let serviceCharacteristics = service.characteristics else { return }
         for characteristic in serviceCharacteristics where characteristic.uuid == TransferService.characteristic_Tx_UUID {
             // If it is, subscribe to it
             transferCharacteristic = characteristic
             peripheral.setNotifyValue(true, for: characteristic)
         }
         
         // Once this is complete, we just need to wait for the data to come in.
     }
     
     /*
      *   This callback lets us know more data has arrived via notification on the characteristic
      */
     func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
         // Deal with errors (if any)
         if let error = error {
             os_log("Error discovering characteristics: %s", error.localizedDescription)
             cleanup()
             return
         }
         
         guard let characteristicData = characteristic.value,
             let stringFromData = String(data: characteristicData, encoding: .utf8) else { return }
         
         os_log("Received %d bytes: %s", characteristicData.count, stringFromData)
         
     }

     /*
      *  The peripheral letting us know whether our subscribe/unsubscribe happened or not
      */
     func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
         // Deal with errors (if any)
         if let error = error {
             os_log("Error changing notification state: %s", error.localizedDescription)
             return
         }
         
         // Exit if it's not the transfer characteristic
         guard characteristic.uuid == TransferService.characteristic_Rx_UUID else { return }
         
         if characteristic.isNotifying {
             // Notification has started
             os_log("Notification began on %@", characteristic)
         } else {
             // Notification has stopped, so disconnect from the peripheral
             os_log("Notification stopped on %@. Disconnecting", characteristic)
             cleanup()
         }
         
     }
 }
extension CentralViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.peripherals.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        //Connect to device where the peripheral is connected
        let cell = tableView.dequeueReusableCell(withIdentifier: "BlueCell") as! PeripheralTableViewCell
        let peripheral = self.peripherals[indexPath.row]
        
        if peripheral.name == nil {
            cell.peripheralLabel.text = "nil"
        } else {
            cell.peripheralLabel.text = peripheral.name
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        discoveredPeripheral = peripherals[indexPath.row]
        tableView.deselectRow(at: indexPath, animated: true)
        // 別の画面に遷移
        performSegue(withIdentifier: "CentralChatBox", sender: nil)
    }
}

