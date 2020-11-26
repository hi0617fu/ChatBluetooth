//
//  CentralViewController.swift
//  ChatBluetooth
//
//  Created by se on 2020/11/06.
//

import UIKit
import os
import Firebase
import FirebaseFirestore

class CentralChatBox: UIViewController {
     // UIViewController overrides, properties specific to this class, private helper methods, etc.

     @IBOutlet var textView: UITextView!
     @IBOutlet var textField2: UITextField!
     @IBOutlet var textField: UITextField!
     @IBOutlet var sendButton: UIButton!

     var defaultstore: Firestore!
     var date = Date()
     var formatter = DateFormatter()
     
     override func viewDidLoad() {
         super.viewDidLoad()
         Timer.scheduledTimer(timeInterval: 30, target: self, selector: #selector(matchTime), userInfo: nil, repeats: true)

         textView.isUserInteractionEnabled = true
         textView.isEditable = false
         textView.isSelectable = false
         textField.delegate = self
         textField2.delegate = self
         
         formatter.setLocalizedDateFormatFromTemplate("H")
         let Chat = formatter.string(from: date)
        defaultstore = Firestore.firestore()
        //Firestoreからデータを取得し、TextViewに表示する
        defaultstore.collection(Chat).order(by: "minute").addSnapshotListener { (snapShot, error) in
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
                        self.defaultstore.collection(Chat).document().delete()
                    } else {
                        if nowMonth != oldMonth {
                            self.defaultstore.collection(Chat).document().delete()
                        } else {
                            //TextViewの一番下に新しいメッセージ内容を追加する
                            self.textView.text =  "\(self.textView.text!).\n\(name) : \(message)"
                        }
                    }
                }
            }
        }
     }
     
     override func viewWillDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        NotificationCenter.default.removeObserver(self)
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
            print("View Refresh")
            refreshView()
        }
    }
    
    func refreshView() {
        self.textView.text = ""
        let date = Date()
        formatter.setLocalizedDateFormatFromTemplate("H")
        let Chat1 = formatter.string(from: date)
        defaultstore = Firestore.firestore()
        //Firestoreからデータを取得し、TextViewに表示する
        defaultstore.collection(Chat1).order(by: "minute").addSnapshotListener { [self] (snapShot, error) in
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
                        self.defaultstore.collection(Chat1).document().delete()
                    } else {
                        if nowMonth != oldMonth {
                            self.defaultstore.collection(Chat1).document().delete()
                        } else {
                            //TextViewの一番下に新しいメッセージ内容を追加する
                                self.textView.text =  "\(self.textView.text!)\n\(name) : \(message)"
                        }
                    }
                }
            }
        }
    }
    
     @IBAction func clickSendAction(_ sender: AnyObject) {
        print("送信が押されたよ")

        //キーボードを閉じる
        textField.resignFirstResponder()
        textField2.resignFirstResponder()
        guard let name =  textField2.text else {return}
        guard let message = textField.text else {return}
        let date = Date()
        let day = DateFormatter()
        let month = DateFormatter()
        let minute = DateFormatter()
        let second = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("H")
        let Chat = formatter.string(from: date)
        month.dateFormat = "M"
        day.dateFormat = "d"
        minute.dateFormat = "m"
        second.dateFormat =  "s"
        let stringMinute = minute.string(from: date)
        let stringSecond = second.string(from: date)
        let realTime = Int(stringMinute)!*100+Int(stringSecond)!
        let messageData: [String: String] = ["name":name, "message":message, "day": day.string(from: date), "month": month.string(from: date),"minute": String(format: "%04d", realTime), "hour": Chat]
        formatter.setLocalizedDateFormatFromTemplate("H")
        //Firestoreに送信する
        defaultstore.collection(Chat).addDocument(data: messageData)
        //メッセージの中身を空にする
        textField.text = ""
     }
 }
extension CentralChatBox:UITextFieldDelegate {
     func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            print("returnが押されたよ")

        //キーボードを閉じる
        textField.resignFirstResponder()
        textField2.resignFirstResponder()
        //messageに入力されたテキストを変数に入れる。nilの場合はFirestoreへ行く処理をしない
        guard let message = textField.text else {
            return true
        }
        guard let name = textField2.text else {
            return true
        }

        //messageが空欄の場合はFirestoreへ行く処理をしない
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
        month.dateFormat = "M"
        day.dateFormat = "d"
        minute.dateFormat = "m"
        second.dateFormat  = "s"
        let stringMinute = minute.string(from: date)
        let stringSecond = second.string(from: date)
        let realTime = Int(stringMinute)!*100+Int(stringSecond)!
        let messageData: [String: String] = ["name":name, "message":message, "day": day.string(from: date), "month": month.string(from: date),"minute": String(format: "%04d", realTime), "hour": Chat]

        //Firestoreに送信する
        defaultstore.collection(Chat).addDocument(data: messageData)

        //メッセージの中身を空にする
        textField.text = ""

        return true
    }
}
