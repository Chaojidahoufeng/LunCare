import UIKit
import CoreBluetooth

class DeviceListViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var scanButton: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    // 修改数据结构以包含advertisementData
    private var discoveredDevices: [(peripheral: CBPeripheral, rssi: NSNumber, advertisementData: [String: Any])] = []
    private let bluetoothManager = BluetoothManager.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bluetoothManager.delegate = self
    }
    
    private func setupUI() {
        title = "选择设备"
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "DeviceCell")
        
        scanButton.setTitle("扫描设备", for: .normal)
        scanButton.backgroundColor = UIColor.systemBlue
        scanButton.setTitleColor(.white, for: .normal)
        scanButton.layer.cornerRadius = 8
        
        activityIndicator.hidesWhenStopped = true
        
        updateScanButton()
    }
    
    private func updateScanButton() {
        if bluetoothManager.isScanning {
            scanButton.setTitle("停止扫描", for: .normal)
            activityIndicator.startAnimating()
        } else {
            scanButton.setTitle("扫描设备", for: .normal)
            activityIndicator.stopAnimating()
        }
    }

    @IBAction func scanButtonTapped(_ sender: UIButton) {
        if bluetoothManager.isScanning {
            bluetoothManager.stopScanning()
        } else {
            discoveredDevices.removeAll()
            tableView.reloadData()
            bluetoothManager.startScanning()
        }
        updateScanButton()
    }
    
    private func getDeviceName(from peripheral: CBPeripheral, advertisementData: [String: Any]) -> String {
        // 1. 首先尝试从advertisementData中的kCBAdvDataLocalName获取
        if let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String, !localName.isEmpty {
            return localName
        }
        
        // 2. 然后尝试从peripheral.name获取
        if let peripheralName = peripheral.name, !peripheralName.isEmpty {
            return peripheralName
        }
        
        // 3. 最后显示设备的UUID前8位作为标识
        let uuid = peripheral.identifier.uuidString
        return "设备-\(String(uuid.prefix(8)))"
    }
    
    private func connectToDevice(_ peripheral: CBPeripheral, advertisementData: [String: Any]) {
        bluetoothManager.connect(to: peripheral)
        
        let deviceName = getDeviceName(from: peripheral, advertisementData: advertisementData)
        let alert = UIAlertController(title: "连接中", message: "正在连接到 \(deviceName)", preferredStyle: .alert)
        present(alert, animated: true)
        
        // Auto dismiss after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            alert.dismiss(animated: true)
        }
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate
extension DeviceListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return discoveredDevices.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DeviceCell", for: indexPath)
        let device = discoveredDevices[indexPath.row]
        
        let deviceName = getDeviceName(from: device.peripheral, advertisementData: device.advertisementData)
        cell.textLabel?.text = deviceName
        cell.detailTextLabel?.text = "RSSI: \(device.rssi)"
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let device = discoveredDevices[indexPath.row]
        connectToDevice(device.peripheral, advertisementData: device.advertisementData)
    }
}

extension DeviceListViewController: BluetoothManagerDelegate {
    func bluetoothManagerDidUpdateState(_ manager: BluetoothManager) {
        // Handle bluetooth state changes
    }
    
    func bluetoothManager(_ manager: BluetoothManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) {
        // 打印调试信息，帮助你了解接收到的数据
        print("发现设备:")
        print("  peripheral.name: \(peripheral.name ?? "nil")")
        print("  advertisementData: \(advertisementData)")
        print("  RSSI: \(rssi)")
        
        // Update discovered devices
        if let index = discoveredDevices.firstIndex(where: { $0.peripheral == peripheral }) {
            discoveredDevices[index] = (peripheral: peripheral, rssi: rssi, advertisementData: advertisementData)
        } else {
            discoveredDevices.append((peripheral: peripheral, rssi: rssi, advertisementData: advertisementData))
        }
        
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    func bluetoothManager(_ manager: BluetoothManager, didConnect peripheral: CBPeripheral) {
        DispatchQueue.main.async {
            self.dismiss(animated: true) {
                self.navigationController?.popViewController(animated: true)
            }
        }
    }
    
    func bluetoothManager(_ manager: BluetoothManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        // Handle disconnection
    }
    
    func bluetoothManager(_ manager: BluetoothManager, didReceiveData data: Data) {
        // Handle received data
    }
    
    func bluetoothManager(_ manager: BluetoothManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async {
            self.dismiss(animated: true)
            let alert = UIAlertController(title: "连接失败", message: "无法连接到设备", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            self.present(alert, animated: true)
        }
    }
}

