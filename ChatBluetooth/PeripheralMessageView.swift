//
//  PeripheralMessageView.swift
//  ChatBluetooth
//
//  Created by se on 2020/11/06.
//

import UIKit
import CoreBluetooth
import os
import SwiftUI

struct PeripheralMessageView: View {
    var name = ""
    @ObservedObject var messageVM = MessageViewModel()
    @State var typeMessage = ""

    var body: some View {
        VStack {
            List(messageVM.messages, id: \.id) {i in
                if i.name == self.name {
                    MessageRow(message: i.message, isMyMessage: true, user:i.name)
                } else {
                    MessageRow(message: i.message, isMyMessage: false, user:i.name)
                }
            }
            .navigationBarTitle("Chats",displayMode: .inline)
            HStack {
                TextField("Message", text: $typeMessage)
                .textFieldStyle(RoundedBorderTextFieldStyle())

                Button(action: {
                    self.messageVM.addMessage(message: self.typeMessage, user: self.name)
                    self.typeMessage = ""
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                }
            }
            .padding()
        }
    }
}

struct PeripheralMessageView_Previews: PreviewProvider {
    static var previews: some View {
        PeripheralMessageView(name: "Tester")
    }
}

