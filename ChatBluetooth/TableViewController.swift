//
//  TableViewController.swift
//  ChatBluetooth
//
//  Created by se on 2020/12/07.
//
import Foundation
import UIKit
import CoreBluetooth
import os

class TableViewController: UIViewController {

    @IBOutlet weak var label: UILabel!
    var receiveData: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()

        label.text = receiveData
    }

}
