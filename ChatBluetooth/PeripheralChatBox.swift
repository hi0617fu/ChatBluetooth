/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A class to advertise, send notifications and receive data from central looking for transfer service and characteristic.
*/
import SwiftUI
import UIKit
import CoreBluetooth
import os
import Firebase
import FirebaseFirestore

class PeripheralViewController: UIViewController {

    @IBOutlet var textView: UITextView!
    @IBOutlet var advertisingSwitch: UISwitch!
    @IBOutlet var textField: UITextField!
    @IBOutlet var sendButton: UIButton!

    var peripheralManager: CBPeripheralManager!
    var transferCharacteristic: CBMutableCharacteristic?
    var connectedCentral: CBCentral?
    var dataToSend = Data()
    var sendDataIndex: Int = 0
    var defaultstore: Firestore!
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil, options: [CBPeripheralManagerOptionShowPowerAlertKey: true])
        super.viewDidLoad()
        textField.delegate = self
        defaultstore = Firestore.firestore()
        //Firestoreからデータを取得し、TextViewに表示する
         defaultstore.collection("chat").addSnapshotListener { (snapShot, error) in
             guard let value = snapShot else {
                 print("snapShot is nil")
                 return
             }
            value.documentChanges.forEach{diff in
            //更新内容が追加だったときの処理
                if diff.type == .added {
                    //追加データを変数に入れる
                    let chatDataOp = diff.document.data() as? Dictionary<String, String>
                    print(diff.document.data())
                    guard let chatData = chatDataOp else {
                        return
                    }
                    guard let message = chatData["message"] else {
                        return
                    }
                    guard let name = chatData["name"] else {
                        return
                    }
                    //TextViewの一番下に新しいメッセージ内容を追加する
                    self.textView.text =  "\(self.textView.text!)\n\(name) : \(message)"
                }
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        // Don't keep advertising going while we're not showing.
        peripheralManager.stopAdvertising()

        super.viewWillDisappear(animated)
    }
    
    // MARK: - Switch Methods

    @IBAction func switchChanged(_ sender: Any) {
        // All we advertise is our service's UUID.
        if advertisingSwitch.isOn {
            peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [TransferService.serviceUUID]])
        } else {
            peripheralManager.stopAdvertising()
        }
    }
    @IBAction func clickSendAction(_ sender: AnyObject) {
        print("送信が押されたよ")

        //キーボードを閉じる
        textField.resignFirstResponder()
        //入力された値を配列に入れる
        let message: String!
        message = textField.text
        let messageData: [String: String] = ["name":"Peripheral", "message":message]

        //Firestoreに送信する
        defaultstore.collection("chat").addDocument(data: messageData)

        //メッセージの中身を空にする
        textField.text = ""

    }

    // MARK: - Helper Methods

    /*
     *  Sends the next amount of data to the connected central
     */
    static var sendingEOM = false
    
    private func sendData() {
        
        guard let transferCharacteristic = transferCharacteristic else {
            return
        }
        
        // First up, check if we're meant to be sending an EOM
        if PeripheralViewController.sendingEOM {
            // send it
            let didSend = peripheralManager.updateValue("EOM".data(using: .utf8)!, for: transferCharacteristic, onSubscribedCentrals: nil)
            // Did it send?
            if didSend {
                // It did, so mark it as sent
                PeripheralViewController.sendingEOM = false
                os_log("Sent: EOM")
            }
            // It didn't send, so we'll exit and wait for peripheralManagerIsReadyToUpdateSubscribers to call sendData again
            return
        }
        
        // We're not sending an EOM, so we're sending data
        // Is there any left to send?
        if sendDataIndex >= dataToSend.count {
            // No data left.  Do nothing
            return
        }
        
        // There's data left, so send until the callback fails, or we're done.
        var didSend = true
        while didSend {
            
            // Work out how big it should be
            var amountToSend = dataToSend.count - sendDataIndex
            if let mtu = connectedCentral?.maximumUpdateValueLength {
                amountToSend = min(amountToSend, mtu)
            }
            
            // Copy out the data we want
            let chunk = dataToSend.subdata(in: sendDataIndex..<(sendDataIndex + amountToSend))
            
            // Send it
            didSend = peripheralManager.updateValue(chunk, for: transferCharacteristic, onSubscribedCentrals: nil)
            
            // If it didn't work, drop out and wait for the callback
            if !didSend {
                return
            }
            
            let stringFromData = String(data: chunk, encoding: .utf8)
            os_log("Sent %d bytes: %s", chunk.count, String(describing: stringFromData))
            
            // It did send, so update our index
            sendDataIndex += amountToSend
            // Was it the last one?
            if sendDataIndex >= dataToSend.count {
                // It was - send an EOM
                
                // Set this so if the send fails, we'll send it next time
                PeripheralViewController.sendingEOM = true
                
                //Send it
                let eomSent = peripheralManager.updateValue("EOM".data(using: .utf8)!,
                                                             for: transferCharacteristic, onSubscribedCentrals: nil)
                
                if eomSent {
                    // It sent; we're all done
                    PeripheralViewController.sendingEOM = false
                    os_log("Sent: EOM")
                }
                return
            }
        }
    }

    private func setupPeripheral() {
        
        // Build our service.
        
        // Start with the CBMutableCharacteristic.
        let transferCharacteristic = CBMutableCharacteristic(type: TransferService.characteristic_Rx_UUID,
                                                         properties: [.notify, .writeWithoutResponse],
                                                         value: nil,
                                                         permissions: [.readable, .writeable])
        
        // Create a service from the characteristic.
        let transferService = CBMutableService(type: TransferService.serviceUUID, primary: true)
        
        // Add the characteristic to the service.
        transferService.characteristics = [transferCharacteristic]
        
        // And add it to the peripheral manager.
        peripheralManager.add(transferService)
        
        // Save the characteristic for later.
        self.transferCharacteristic = transferCharacteristic

    }
}

extension PeripheralViewController: CBPeripheralManagerDelegate {

    internal func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        
        advertisingSwitch.isEnabled = peripheral.state == .poweredOn
        
        switch peripheral.state {
        case .poweredOn:
            // ... so start working with the peripheral
            os_log("CBManager is powered on")
            setupPeripheral()
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
            os_log("A previously unknown peripheral manager state occurred")
            // In a real app, you'd deal with yet unknown cases that might occur in the future
            return
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        os_log("Central subscribed to characteristic")
        
        // Get the data
        dataToSend = textView.text.data(using: .utf8)!
        
        // Reset the index
        sendDataIndex = 0
        
        // save central
        connectedCentral = central
        
        // Start sending
        sendData()
    }
    
    /*
     *  Recognize when the central unsubscribes
     */
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        os_log("Central unsubscribed from characteristic")
        connectedCentral = nil
    }
    
    /*
     *  This callback comes in when the PeripheralManager is ready to send the next chunk of data.
     *  This is to ensure that packets will arrive in the order they are sent
     */
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        // Start sending again
        sendData()
    }
    
    /*
     * This callback comes in when the PeripheralManager received write to characteristics
     */
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for aRequest in requests {
            guard let requestValue = aRequest.value,
                let stringFromData = String(data: requestValue, encoding: .utf8) else {
                    continue
            }
            
            os_log("Received write request of %d bytes: %s", requestValue.count, stringFromData)
            self.textView.text = stringFromData
        }
    }
}

extension PeripheralViewController: UITextViewDelegate {
    // implementations of the UITextViewDelegate methods

    /*
     *  This is called when a change happens, so we know to stop advertising
     */
    func textViewDidChange(_ textView: UITextView) {
        // If we're already advertising, stop
        if advertisingSwitch.isOn {
            advertisingSwitch.isOn = false
            peripheralManager.stopAdvertising()
        }
    }
    
    /*
     *  Adds the 'Done' button to the title bar
     */
    func textViewDidBeginEditing(_ textView: UITextView) {
        // We need to add this manually so we have a way to dismiss the keyboard
        let rightButton = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(dismissKeyboard))
        navigationItem.rightBarButtonItem = rightButton
    }
    
    /*
     * Finishes the editing
     */
    @objc
    func dismissKeyboard() {
        textView.resignFirstResponder()
        navigationItem.rightBarButtonItem = nil
    }
}
    
extension PeripheralViewController:UITextFieldDelegate {
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            print("returnが押されたよ")

            //キーボードを閉じる
            textField.resignFirstResponder()
            //messageに入力されたテキストを変数に入れる。nilの場合はFirestoreへ行く処理をしない
            guard let message = textField.text else {
                return true
            }

            //messageが空欄の場合はFirestoreへ行く処理をしない
            if textField.text == "" {
                return true
            }

            //入力された値を配列に入れる
            let messageData: [String: String] = ["name":"Peripheral", "message":message]

            //Firestoreに送信する
            defaultstore.collection("chat").addDocument(data: messageData)

            //メッセージの中身を空にする
            textField.text = ""

            return true
    }
}


