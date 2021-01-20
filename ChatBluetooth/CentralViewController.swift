import Foundation
import UIKit
import CoreBluetooth
import os

var string: String!

class CentralViewController: UIViewController {

    @IBOutlet weak var baseTableView: UITableView!
    @IBOutlet weak var refreshButton: UIBarButtonItem!

    var centralManager: CBCentralManager! //Core Bluetoothを始動させるための変数
    var discoveredPeripheral:  CBPeripheral! //connectするPeripheralを格納する変数
    var start: Date! //Scanから検知までの時間を計測する変数
    var start2: Date! //Tapから接続、キャラクタリスティクス読み込みまでの時間を計測する変数
    var timer: Timer = Timer() //Scanの時間を決めるための変数
    var myUuids: NSMutableArray = NSMutableArray() //見つけたPeripheralのUUIDを格納するArray(配列)
    var myPeripheral: NSMutableArray = NSMutableArray() //見つけたPeripheralのCBPeripheralを格納する配列
    
     override func viewDidLoad() {
        // 画面に遷移した最初に行うこと.配列の初期化、tableViewの初期化、ボタンの配置、Scanの開始
        myUuids = NSMutableArray()
        myPeripheral = NSMutableArray()
        self.baseTableView.delegate = self
        self.baseTableView.dataSource = self
        self.view.addSubview(baseTableView)
        let backButton = UIBarButtonItem(title: "Disconnect", style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backButton
        self.retrievePeripheral()
     }
     
    override func viewWillDisappear(_ animated: Bool) {
        // 別の画面に映る瞬間に行うこと、保持していたPeripheralの情報を削除してtableviewから見れなくする.
        discoveredPeripheral = nil
        myUuids = []
        myPeripheral = []
        baseTableView.reloadData()
        super.viewWillDisappear(animated)
     }

     private func retrievePeripheral() {
        //Scan関数. timerを5秒に設定し、centralManagerを始動（①に移動）.5秒経ったらstopscan関数を実行
        print("retrieve")
        timer = Timer.scheduledTimer(timeInterval: 5.0,target: self, selector: #selector(self.stopscan), userInfo: nil, repeats: false)
        start = Date()
        centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: true])
     }
    
     @objc func stopscan() {
        //centralManagerのScanを止める
         print("5seconds stop Scan")
         centralManager.stopScan()
     }
     
     private func cleanup() {
        //.connected状態のPeripheralが存在すればそのPeripheralのservice,characteristicsを削除
         guard let discoveredPeripheral = discoveredPeripheral,
             case .connected = discoveredPeripheral.state else { return }
         
         for service in (discoveredPeripheral.services ?? [] as [CBService]) {
             for characteristic in (service.characteristics ?? [] as [CBCharacteristic]) {
                 if characteristic.uuid == TransferService.characteristic_UUID && characteristic.isNotifying {
                    self.discoveredPeripheral?.setNotifyValue(false, for: characteristic)
                    print("cleanup")
                 }
             }
         }
         centralManager.cancelPeripheralConnection(discoveredPeripheral)
     }
    
    @IBAction func refreshAction(_ sender: AnyObject) {
        //一旦保持しているPeripheralの情報を削除してtableviewを更新してからScan再開
        discoveredPeripheral = nil
        myUuids = []
        myPeripheral = []
        self.baseTableView.reloadData()
        self.retrievePeripheral()
    }
 }

 extension CentralViewController: CBCentralManagerDelegate {
     internal func centralManagerDidUpdateState(_ central: CBCentralManager) {
        //① 端末のBluetoothがONになっていればPeripheral端末の検知がstart.検知したら②に移動
         switch central.state {
         case .poweredOn:
             os_log("CBManager is powered on")
             centralManager.scanForPeripherals(withServices: [TransferService.serviceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
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
        //②見つけたPeripheralのCBPeripheral,identifierをそれぞれmyPeripheral,myUuidsに格納.ただし、同じ名前のものは再び入らないようにする.格納されたら③に移動
         guard RSSI.intValue >= -100
             else {
                 os_log("Discovered perhiperal not in expected range, at %d", RSSI.intValue)
                 return
         }
        if (myUuids.contains(peripheral.identifier.uuidString) || myPeripheral.contains(peripheral)){
            // スルー
        } else {
             os_log("Discovered %s at %d", String(describing: peripheral.name), RSSI.intValue)
            myPeripheral.add(peripheral)
            myUuids.add(peripheral.identifier.uuidString)
            //か、ここ
        }
            self.baseTableView.reloadData()
            let elapsed = Date().timeIntervalSince(start)
            print(elapsed)
     }

     func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        //centralManager.connectが失敗したらここに来る.本来使わないゾーン
         os_log("Failed to connect to %@. %s", peripheral, String(describing: error))
         cleanup()
     }
     
     func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
         os_log("Scanning stopped")
        //⑤接続したperipheralのserviceを探索serviceを見つけたら⑥に移動
         peripheral.delegate = self
         peripheral.discoverServices([TransferService.serviceUUID])
     }
     
     func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        //Peripheralとの接続を削除
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
        //⑥service内のcharacteristicsを探索.見つけたら⑦に移動
        peripheral.discoverCharacteristics([TransferService.characteristic_UUID], for: (peripheral.services?.first)!)
     }
     
     func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
         if let error = error {
             os_log("Error discovering characteristics: %s", error.localizedDescription)
             cleanup()
             return
         }
        //⑦見つけたcharacteristicsを通知する.通知がきたら⑧に移動
        peripheral.setNotifyValue(true, for: (service.characteristics?.first)!)
     }
     
     func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
         if let error = error {
             os_log("Error discovering characteristics: %s", error.localizedDescription)
             cleanup()
             return
         }
        //⑧受け取ったcharacteristicをstring型に直してチャットボックスに遷移
         guard let characteristicData = characteristic.value,
               let stringFromData = String(data: characteristicData, encoding: .utf8) else { return }
         os_log("Received %d bytes: %s", characteristicData.count, stringFromData)
         string =  stringFromData

         let elapsed2 = Date().timeIntervalSince(start2)
         print("end," ,elapsed2)
         performSegue(withIdentifier: "CentralChatBox", sender: nil)
     }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        //チャットボックスに遷移する際に、受け取ったcharacteristicをCentralChatBox内でも使えるように準備
        if (segue.identifier == "CentralChatBox") {
            let vc2: CentralChatBox = (segue.destination as? CentralChatBox)!
            vc2.udidData = string
        }
    }
 }

extension CentralViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        //③格納されたmyUuidsの数をそのままcellの個数に反映させる
        return myUuids.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        //③格納されたmyUuidsをtableViewに表示.ユーザがそれをタップしたら④に移動
        let cell = tableView.dequeueReusableCell(withIdentifier: "BlueCell") as! PeripheralTableViewCell
        cell.peripheralLabel!.text = "\(myUuids[indexPath.row])"
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        //④centralManagerのScanを止めて選択したPeripheralと接続.接続されたら⑤に移動
        self.discoveredPeripheral = myPeripheral[indexPath.row] as? CBPeripheral
        centralManager.stopScan()
        start2 = Date()
        centralManager.connect(self.discoveredPeripheral, options: nil)
        print("connect")
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

 
