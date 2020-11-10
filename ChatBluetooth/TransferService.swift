//
//  TransferService.swift
//  ChatBluetooth
//
//  Created by se on 2020/11/06.
//

import Foundation
import CoreBluetooth

struct TransferService {
    static let serviceUUID = CBUUID(string: "E20A39F4-73F5-4BC4-A12F-17D1AD07A961")
    static let characteristic_Tx_UUID = CBUUID(string: "08590F7E-DB05-467E-8757-72F6FAEB13D4")
    static let characteristic_Rx_UUID = CBUUID(string: "08590F7E-DB05-467E-8757-72F6FAEB13D5")
}
