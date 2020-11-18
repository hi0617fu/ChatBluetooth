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
         textView.isUserInteractionEnabled = true
         textView.isEditable = false
         textView.isSelectable = false
         textField.delegate = self
         textField2.delegate = self
         
         formatter.setLocalizedDateFormatFromTemplate("H")
         let Chat = formatter.string(from: date)
         defaultstore = Firestore.firestore()
        //Firestoreからデータを取得し、TextViewに表示する
        defaultstore.collection(Chat).addSnapshotListener { (snapShot, error) in
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
        super.viewDidDisappear(animated)
        NotificationCenter.default.removeObserver(self)
     }


    
     @IBAction func clickSendAction(_ sender: AnyObject) {
        print("送信が押されたよ")

        //キーボードを閉じる
        textField.resignFirstResponder()
        textField2.resignFirstResponder()
        //入力された値を配列に入れる
        let message: String!
        let name: String!
        let date = Date()
        let df = DateFormatter()
        df.dateFormat = "yyyy/MM/dd HH:mm:ss"
        name = textField2.text
        message = textField.text
        let messageData: [String: String] = ["name":name, "message":message, "created at":  df.string(from: date)]
        formatter.setLocalizedDateFormatFromTemplate("H")
        let Chat = formatter.string(from: date)
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
        let df = DateFormatter()
        df.dateFormat = "yyyy/MM/dd HH:mm:ss"
        formatter.setLocalizedDateFormatFromTemplate("H")
        let Chat = formatter.string(from: date)

        //入力された値を配列に入れる
        let messageData: [String: String] = ["name":name, "message":message, "created at": df.string(from: date)]

        //Firestoreに送信する
        defaultstore.collection(Chat).addDocument(data: messageData)
            //メッセージの中身を空にする
            textField.text = ""

            return true
    }
}
