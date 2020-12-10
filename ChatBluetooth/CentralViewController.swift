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

var string: String!

class CentralViewController: UIViewController {

    @IBOutlet weak var baseTableView: UITableView!
    @IBOutlet weak var refreshButton: UIBarButtonItem!

    var peripherals: [CBPeripheral?] = []
    var characteristicValue = [CBUUID: NSData]()
    var characteristics = [String : CBCharacteristic]()
    var centralManager: CBCentralManager!
    var peripheralManager: CBPeripheralManager?
    var transferCharacteristic: CBCharacteristic?
    var writeIterationsComplete = 0
    var connectionIterationsComplete = 0

    var discoveredPeripheral:  CBPeripheral?
     
     override func viewDidLoad() {
         centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: true])
        self.baseTableView.delegate = self
        self.baseTableView.dataSource = self
       // self.baseTableView.register(PeripheralTableViewCell.self, forCellReuseIdentifier: "BlueCell")
        self.view.addSubview(baseTableView)
        self.baseTableView.reloadData()
        let backButton = UIBarButtonItem(title: "Disconnect", style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backButton
        self.retrievePeripheral()
     }
     
     override func viewWillDisappear(_ animated: Bool) {
         // Don't keep it going while we're not showing.
         centralManager.stopScan()
         os_log("Scanning stopped")
       //  data.removeAll(keepingCapacity: false)
         super.viewWillDisappear(animated)
     }

     private func retrievePeripheral() {
        self.discoveredPeripheral = nil
         let connectedPeripherals: [CBPeripheral] = (centralManager.retrieveConnectedPeripherals(withServices: [TransferService.serviceUUID]))
        self.baseTableView.reloadData()
         
         os_log("Found connected Peripherals with transfer service: %@", connectedPeripherals)
         
         if let connectedPeripheral = connectedPeripherals.last {
             os_log("Connecting to peripheral %@", connectedPeripheral)
            self.discoveredPeripheral = connectedPeripheral
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
                 if characteristic.uuid == TransferService.characteristic_UUID && characteristic.isNotifying {
                     // It is notifying, so unsubscribe
                    self.discoveredPeripheral?.setNotifyValue(false, for: characteristic)
                    print("cleanup")
                 }
             }
         }
         centralManager.cancelPeripheralConnection(discoveredPeripheral)
     }
    
    @IBAction func refreshAction(_ sender: AnyObject) {
        print("refresh")
  //      discoveredPeripheral = nil
        peripherals = []
        self.baseTableView.reloadData()
        print("refresh2")
        centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: true])
        print("refresh3")
        self.baseTableView.reloadData()
        print("refresh4")
        /*
        self.baseTableView.reloadData()
        retrievePeripheral()
        print("test",peripherals)*/
    }
 }

 extension CentralViewController: CBCentralManagerDelegate {
     internal func centralManagerDidUpdateState(_ central: CBCentralManager) {

         switch central.state {
         case .poweredOn:
             os_log("CBManager is powered on")
             retrievePeripheral()
         case .poweredOff:
             os_log("CBManager is not powered on")
             return
         case .resetting:
             os_log("CBManager is resetting")
             return
         case .unauthorized:
             return
         case .unknown:
             os_log("CBManager state is unknown")
             return
         case .unsupported:
             os_log("Bluetooth is not supported on this device")
             return
         @unknown default:
             os_log("A previously unknown central manager state occurred")
             return
         }
     }

     func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                         advertisementData: [String: Any], rssi RSSI: NSNumber) {
        
        /*self.discoveredPeripheral = peripheral
        self.peripherals.append(peripheral)
        peripheral.delegate = self
        self.baseTableView.reloadData() */
         
         guard RSSI.intValue >= -50
             else {
                 os_log("Discovered perhiperal not in expected range, at %d", RSSI.intValue)
                 return
         }
         
        os_log("Discovered %s at %d", String(describing: discoveredPeripheral?.name), RSSI.intValue)
         
         if discoveredPeripheral != peripheral {
             discoveredPeripheral = peripheral
             os_log("Connecting to perhiperal %@", peripheral)
            self.peripherals.append(peripheral)
             centralManager.connect(peripheral, options: nil)
         }
     }


     func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
         os_log("Failed to connect to %@. %s", peripheral, String(describing: error))
         cleanup()
     }
     
     func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
         os_log("Peripheral Connected")
       // let udidData = transferCharacteristic
       // let udidString = String(data:udidData, encoding: .utf8)
       // print(udidString!)
         centralManager.stopScan()
         os_log("Scanning stopped")
        
         
         // set iteration info
         connectionIterationsComplete += 1
         writeIterationsComplete = 0

         peripheral.delegate = self
         peripheral.discoverServices([TransferService.serviceUUID])
        
         /*   let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let centralChatBox = storyboard.instantiateViewController(withIdentifier: "CentralChatBox") as! CentralChatBox
        
        navigationController?.pushViewController(centralChatBox, animated: true) */
     }
     
     func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
         os_log("Perhiperal Disconnected")
         discoveredPeripheral = nil
     }
 }

 extension CentralViewController: CBPeripheralDelegate {
     func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
         if let error = error {
             os_log("Error discovering services: %s", error.localizedDescription)
             cleanup()
             return
         }
         guard let peripheralServices = peripheral.services else { return }
         for service in peripheralServices {
             peripheral.discoverCharacteristics([TransferService.characteristic_UUID], for: service)
         }
     }
     
     func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
         if let error = error {
             os_log("Error discovering characteristics: %s", error.localizedDescription)
             cleanup()
             return
         }
        guard let serviceCharacteristics = service.characteristics else { return }
         for characteristic in serviceCharacteristics where characteristic.uuid == TransferService.characteristic_UUID {
             transferCharacteristic = characteristic
             peripheral.setNotifyValue(true, for: characteristic)
         }
     }
     
     func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
         if let error = error {
             os_log("Error discovering characteristics: %s", error.localizedDescription)
             cleanup()
             return
         }
         guard let characteristicData = characteristic.value,
            let stringFromData = String(data: characteristicData, encoding: .utf8) else { return }
        
         os_log("Received %d bytes: %s", characteristicData.count, stringFromData)
         print(stringFromData)
         string =  stringFromData
        if discoveredPeripheral != peripheral {
            discoveredPeripheral = peripheral
            os_log("Connecting to perhiperal %@", peripheral)
       /*   self.peripherals.append(peripheral)
           centralManager.connect(peripheral, options: nil)*/
        }
   
        self.baseTableView.reloadData()
        // performSegue(withIdentifier: "CentralChatBox", sender: nil)
     }
    /* override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
         if segue.identifier == "CentralChatBox" {
            let nextView = segue.destination as! CentralChatBox
            nextView.udidData = string
        }
    }*/
 }

extension CentralViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.peripherals.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        //Connect to device where the peripheral is connected
        let cell = tableView.dequeueReusableCell(withIdentifier: "BlueCell") as! PeripheralTableViewCell
        let peripheral = self.peripherals[indexPath.row]
        
        if peripheral?.name == nil {
            print("nill")
            cell.peripheralLabel?.text = nil
        } else {
            let string = peripheral?.identifier
            print("peripheralLabel")
            cell.peripheralLabel?.text = string?.uuidString
        }
    //    discoveredPeripheral = nil
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        discoveredPeripheral = peripherals[indexPath.row]
        tableView.deselectRow(at: indexPath, animated: true)
        // 別の画面に遷移
       performSegue(withIdentifier: "CentralChatBox", sender: nil)
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if (segue.identifier == "CentralChatBox") {
            let vc2: CentralChatBox = (segue.destination as? CentralChatBox)!
            // ViewControllerのtextVC2にメッセージを設定
            vc2.udidData = string
        }
    }

}

 
