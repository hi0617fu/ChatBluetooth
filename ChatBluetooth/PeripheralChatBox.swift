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
import Foundation


class PeripheralViewController: UIViewController {

    @IBOutlet var textView: UITextView!
    @IBOutlet var advertisingSwitch: UISwitch!
    @IBOutlet var textField: UITextField!
    @IBOutlet var textField2: UITextField!
    @IBOutlet var sendButton: UIButton!

    var peripheralManager: CBPeripheralManager!
    var transferCharacteristic: CBMutableCharacteristic?
    var connectedCentral: CBCentral?
    var characteristic: CBCharacteristic!
   // var dataToSend = Data()
   // var sendDataIndex: Int = 0
    var defaultstore: Firestore!
    var date = Date()
    var formatter = DateFormatter()
    var udid:String! = UIDevice.current.identifierForVendor!.uuidString
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil, options: [CBPeripheralManagerOptionShowPowerAlertKey: true])
        super.viewDidLoad()
        Timer.scheduledTimer(timeInterval: 30, target: self, selector: #selector(matchTime), userInfo: nil, repeats: true)
        textView.isUserInteractionEnabled = true //キーボードを出したくない
        textView.isEditable = false //キーボードを出したくない
        textView.text = ""
        textField.delegate = self
        textField2.delegate = self
        formatter.setLocalizedDateFormatFromTemplate("H")
        let Chat1 = formatter.string(from: date)
        let device: String = udid + "," + Chat1
        defaultstore = Firestore.firestore()
        //Firestoreからデータを取得し、TextViewに表示する
        print("Perihperal:", device)
        defaultstore.collection(device).order(by: "minute").addSnapshotListener { [self] (snapShot, error) in
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
                    guard let oldDay = chatData["day"]  else {
                        return
                    }
                    guard let oldMonth = chatData["month"] else {
                        return
                    }
                    
                    let date = Date()
                    let day = DateFormatter()
                    let month = DateFormatter()
                    day.dateFormat = "d"
                    month.dateFormat = "M"
                    let nowDay = day.string(from: date)
                    let nowMonth = month.string(from: date)
                    if nowDay !=  oldDay {
                        self.defaultstore.collection(device).document().delete()
                    } else {
                        if nowMonth != oldMonth {
                            self.defaultstore.collection(device).document().delete()
                        } else {
                            //TextViewの一番下に新しいメッセージ内容を追加する
                            self.textView.text =  "\(self.textView.text!)\n\(name) : \(message)"
                            
                        }
                    }
                }
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        peripheralManager.stopAdvertising()
        super.viewWillDisappear(animated)
    }
    
    @objc func matchTime() {
        let time = Date()
        let modifiedDate = Calendar.current.date(byAdding: .second, value: -30, to: time)!
        let oldHour = DateFormatter()
        let newHour = DateFormatter()
        oldHour.dateFormat = "H"
        newHour.dateFormat = "H"
        let stringOldHour = oldHour.string(from: time)
        let stringNewHour = newHour.string(from: modifiedDate)
        if stringOldHour != stringNewHour {
            print("View refresh")
            refreshView()
        }
    }
    
    func refreshView() {
        self.textView.text = ""
        let date = Date()
        formatter.setLocalizedDateFormatFromTemplate("H")
        let Chat1 = formatter.string(from: date)
        let device: String = udid + "," + Chat1
        defaultstore = Firestore.firestore()
        defaultstore.collection(device).order(by: "minute").addSnapshotListener { [self] (snapShot, error) in
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
                    guard let oldDay = chatData["day"]  else {
                        return
                    }
                    guard let oldMonth = chatData["month"] else {
                        return
                    }
                    
                    let date = Date()
                    let day = DateFormatter()
                    let month = DateFormatter()
                    day.dateFormat = "d"
                    month.dateFormat = "M"
                    let nowDay = day.string(from: date)
                    let nowMonth = month.string(from: date)
                    if nowDay !=  oldDay {
                        self.defaultstore.collection(device).document().delete()
                    } else {
                        if nowMonth != oldMonth {
                            self.defaultstore.collection(device).document().delete()
                        } else {
                            //TextViewの一番下に新しいメッセージ内容を追加す
                                self.textView.text =  "\(self.textView.text!)\n\(name) : \(message)"
                        }
                    }
                }
            }
        }
    }
    
    @IBAction func switchChanged(_ sender: Any) {
        // All we advertise is our service's UUID.
        if advertisingSwitch.isOn {
            peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [TransferService.serviceUUID]])
        } else {
            peripheralManager.stopAdvertising()
        }
    }
    
    @IBAction func clickSendAction(_ sender: AnyObject) {
        print("送信が押されました")
        guard let textField = self.textField,
              let textField2 = self.textField2 else {
                  return
        }
        // 文字数が0の場合(""空文字)もtourokuButtonを非活性に
      let text: String = textField.text  ?? ""
      let text2: String  = textField2.text ?? ""
        if text.count == 0 || text2.count == 0 {
            return
        }
        //キーボードを閉じる
        textField.resignFirstResponder()
        guard let name =  textField2.text else {return}
        guard let message = textField.text else {return}
        let date = Date()
        let day = DateFormatter()
        let month = DateFormatter()
        let minute = DateFormatter()
        let second = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("H")
        let Chat = formatter.string(from: date)
        let device: String = udid + "," + Chat
        month.dateFormat = "M"
        day.dateFormat = "d"
        minute.dateFormat = "m"
        second.dateFormat = "s"
        let stringMinute = minute.string(from: date)
        let stringSecond = second.string(from: date)
        let realTime = Int(stringMinute)!*100+Int(stringSecond)!
        let messageData: [String: String] = ["name":name, "message":message, "day": day.string(from: date), "month": month.string(from: date),"minute": String(format: "%04d", realTime), "hour": Chat]

        //Firestoreに送信する
        defaultstore.collection(device).addDocument(data: messageData)
        //メッセージの中身を空にする
        textField.text = ""

    }

    private func setupPeripheral() {
        
        let transferCharacteristic = CBMutableCharacteristic(type: TransferService.characteristic_UUID,
                                                             properties: [.notify, .write],
                                                         value: nil,
                                                         permissions: [.readable])
        
        let transferService = CBMutableService(type: TransferService.serviceUUID, primary: true)
        transferService.characteristics = [transferCharacteristic]
        peripheralManager.add(transferService)
        self.transferCharacteristic = transferCharacteristic
    }
    
    private func validate() {
          guard let textField = self.textField,
                let textField2 = self.textField2 else {
                  self.sendButton.isEnabled = false
                    return
          }

        let text: String = textField.text  ?? ""
        let text2: String  = textField2.text ?? ""
          if text.count == 0 || text2.count == 0 {
              self.sendButton.isEnabled = false
              return
          }
          self.sendButton.isEnabled = true
    }
}

extension PeripheralViewController: CBPeripheralManagerDelegate {

    internal func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        
        advertisingSwitch.isEnabled = peripheral.state == .poweredOn
        
        switch peripheral.state {
        case .poweredOn:
            os_log("CBManager is powered on")
            setupPeripheral()
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
            os_log("A previously unknown peripheral manager state occurred")
            return
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        os_log("Central subscribed to characteristic")
        connectedCentral = central
        let udidData:Data? = udid.data(using: .utf8)
        transferCharacteristic?.value = udidData
        peripheralManager.updateValue(udidData!, for: transferCharacteristic!, onSubscribedCentrals: nil)
        print("Send ",udidData!)

    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        os_log("Central unsubscribed from characteristic")
        connectedCentral = nil
    }
}

extension PeripheralViewController:UITextFieldDelegate {
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            print("returnが押されました")
            validate()
            textField.resignFirstResponder()
            guard let message = textField.text else {
                return true
            }
            guard let name = textField2.text else {
                return true
            }

            if textField.text == "" {
                return true
            }
            if textField2.text == "" {
                return true
            }
            let date = Date()
            let day = DateFormatter()
            let month = DateFormatter()
            let minute = DateFormatter()
            let second = DateFormatter()
            formatter.setLocalizedDateFormatFromTemplate("H")
            let Chat = formatter.string(from: date)
            let device: String = udid + "," + Chat
            month.dateFormat = "M"
            day.dateFormat = "d"
            minute.dateFormat = "m"
            second.dateFormat = "s"
            let stringMinute = minute.string(from: date)
            let stringSecond = second.string(from: date)
            let realTime = Int(stringMinute)!*100+Int(stringSecond)!
            let messageData: [String: String] = ["name":name, "message":message, "day": day.string(from: date), "month": month.string(from: date),"minute": String(format: "%04d", realTime), "hour": Chat]

            //Firestoreに送信する
            defaultstore.collection(device).addDocument(data: messageData)

            //メッセージの中身を空にする
            textField.text = ""

            return true
    }
}


