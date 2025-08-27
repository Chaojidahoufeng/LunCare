import Foundation
import CoreBluetooth

protocol BluetoothManagerDelegate: AnyObject {
    func bluetoothManagerDidUpdateState(_ manager: BluetoothManager)
    func bluetoothManager(_ manager: BluetoothManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber)
    func bluetoothManager(_ manager: BluetoothManager, didConnect peripheral: CBPeripheral)
    func bluetoothManager(_ manager: BluetoothManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?)
    func bluetoothManager(_ manager: BluetoothManager, didReceiveData data: Data)
    func bluetoothManager(_ manager: BluetoothManager, didFailToConnect peripheral: CBPeripheral, error: Error?)
}

class BluetoothManager: NSObject {
    static let shared = BluetoothManager()
    
    weak var delegate: BluetoothManagerDelegate?
    
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var readCharacteristic: CBCharacteristic?
    
    // Service and Characteristic UUIDs (matching Android app's UUID)
    private let serviceUUID = CBUUID(string: "00001101-0000-1000-8000-00805F9B34FB")
    private let characteristicUUID = CBUUID(string: "00001101-0000-1000-8000-00805F9B34FB")
    
    private var discoveredPeripherals: [CBPeripheral] = []

    // 添加初始化方法
    private override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    var isScanning: Bool {
        return centralManager.isScanning
    }
    
    var isConnected: Bool {
        return connectedPeripheral?.state == .connected
    }
    
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            print("Bluetooth is not powered on")
            return
        }
        
        discoveredPeripherals.removeAll()
        centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }
    
    func stopScanning() {
        centralManager.stopScan()
    }
    
    func connect(to peripheral: CBPeripheral) {
        stopScanning()
        connectedPeripheral = peripheral
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
    }
    
    func disconnect() {
        guard let peripheral = connectedPeripheral else { return }
        centralManager.cancelPeripheralConnection(peripheral)
    }
    
    func sendData(_ data: Data) -> Bool {
        guard let peripheral = connectedPeripheral,
              let characteristic = writeCharacteristic,
              peripheral.state == .connected else {
            return false
        }
        
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
        return true
    }
    
    func sendCommand(_ command: String) -> Bool {
        guard let data = command.data(using: .utf8) else { return false }
        return sendData(data)
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        delegate?.bluetoothManagerDidUpdateState(self)
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        if !discoveredPeripherals.contains(peripheral) {
            discoveredPeripherals.append(peripheral)
        }
        delegate?.bluetoothManager(self, didDiscover: peripheral, advertisementData: advertisementData, rssi: RSSI)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([serviceUUID])
        delegate?.bluetoothManager(self, didConnect: peripheral)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectedPeripheral = nil
        writeCharacteristic = nil
        readCharacteristic = nil
        delegate?.bluetoothManager(self, didDisconnectPeripheral: peripheral, error: error)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        delegate?.bluetoothManager(self, didFailToConnect: peripheral, error: error)
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            if characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse) {
                writeCharacteristic = characteristic
            }
            
            if characteristic.properties.contains(.read) || characteristic.properties.contains(.notify) {
                readCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        delegate?.bluetoothManager(self, didReceiveData: data)
    }
}
