import UIKit
import CoreBluetooth

class MainViewController: UIViewController{
    // MARK: - IBOutlets
    @IBOutlet weak var connectButton: UIButton!
    @IBOutlet weak var connectionStatusLabel: UILabel!

    @IBOutlet weak var rtcDateLabel: UILabel!
    @IBOutlet weak var rtcTimeLabel: UILabel!
    @IBOutlet weak var levelLabel: UILabel!
    @IBOutlet weak var freqLabel: UILabel!
    @IBOutlet weak var setTimeLabel: UILabel!

    @IBOutlet weak var levelPicker: UIPickerView!
    @IBOutlet weak var freqPicker: UIPickerView!
    @IBOutlet weak var startHourPicker: UIPickerView!
    @IBOutlet weak var startMinPicker: UIPickerView!
    @IBOutlet weak var stopHourPicker: UIPickerView!
    @IBOutlet weak var stopMinPicker: UIPickerView!

    @IBOutlet weak var setButton: UIButton!
    @IBOutlet weak var rtcButton: UIButton!
    
    // MARK: - Properties
    private let bluetoothManager = BluetoothManager.shared
    
    private let levels = ["1", "2", "3"]
    private let freqs = Array(1...30).map { String(format: "%02d", $0) }
    private let hours = Array(0...23).map { String(format: "%02d", $0) }
    private let minutes = Array(0...59).map { String(format: "%02d", $0) }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBluetooth()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateConnectionStatus()
    }
    
    private func setupUI() {
        title = "智能跳蛋"
        
        // Setup buttons
        connectButton.backgroundColor = UIColor.systemBlue
        connectButton.setTitleColor(.white, for: .normal)
        connectButton.layer.cornerRadius = 8
        
        setButton.backgroundColor = UIColor.systemGreen
        setButton.setTitleColor(.white, for: .normal)
        setButton.layer.cornerRadius = 8
        setButton.setTitle("设置参数", for: .normal)
        
        rtcButton.backgroundColor = UIColor.systemOrange
        rtcButton.setTitleColor(.white, for: .normal)
        rtcButton.layer.cornerRadius = 8
        rtcButton.setTitle("校准时间", for: .normal)
        
        // Setup pickers
        setupPickers()
        
        // Setup labels
        setupLabels()
        
        updateConnectionStatus()
    }
    
    private func setupPickers() {
        levelPicker.delegate = self
        levelPicker.dataSource = self
        freqPicker.delegate = self
        freqPicker.dataSource = self
        startHourPicker.delegate = self
        startHourPicker.dataSource = self
        startMinPicker.delegate = self
        startMinPicker.dataSource = self
        stopHourPicker.delegate = self
        stopHourPicker.dataSource = self
        stopMinPicker.delegate = self
        stopMinPicker.dataSource = self
        
        // Set default values
        levelPicker.selectRow(0, inComponent: 0, animated: false)
        freqPicker.selectRow(0, inComponent: 0, animated: false)
    }
    
    private func setupLabels() {
        rtcDateLabel.text = "*"
        rtcTimeLabel.text = "*"
        levelLabel.text = "*"
        freqLabel.text = "*"
        setTimeLabel.text = "*"
    }
    
    private func setupBluetooth() {
        bluetoothManager.delegate = self
    }
    
    private func updateConnectionStatus() {
        if bluetoothManager.isConnected {
            connectButton.setTitle("已连接", for: .normal)
            connectButton.backgroundColor = UIColor.systemGreen
            connectionStatusLabel.text = "设备已连接"
            connectionStatusLabel.textColor = UIColor.systemGreen
            
            // Request current status when connected
            syncRTC()
        } else {
            connectButton.setTitle("连接设备", for: .normal)
            connectButton.backgroundColor = UIColor.systemBlue
            connectionStatusLabel.text = "未连接"
            connectionStatusLabel.textColor = UIColor.systemRed
            
            // Reset display
            setupLabels()
        }
    }
    
    private func syncRTC() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"
        let timeString = formatter.string(from: Date())
        let command = "*RTC\(timeString)#"
        
        if bluetoothManager.sendCommand(command) {
            print("RTC sync command sent: \(command)")
        }
    }
    
    // MARK: - IBActions
    @IBAction func connectButtonTapped(_ sender: UIButton) {
        if bluetoothManager.isConnected {
            bluetoothManager.disconnect()
        } else {
            performSegue(withIdentifier: "showDeviceList", sender: self)
        }
    }
    
    @IBAction func setButtonTapped(_ sender: UIButton) {
        guard bluetoothManager.isConnected else {
            showAlert(title: "未连接", message: "请先连接设备")
            return
        }
        
        let level = levels[levelPicker.selectedRow(inComponent: 0)]
        let freq = freqs[freqPicker.selectedRow(inComponent: 0)]
        let startHour = startHourPicker.selectedRow(inComponent: 0)
        let startMin = startMinPicker.selectedRow(inComponent: 0)
        let stopHour = stopHourPicker.selectedRow(inComponent: 0)
        let stopMin = stopMinPicker.selectedRow(inComponent: 0)
        
        let startTime = startHour * 60 + startMin
        let stopTime = stopHour * 60 + stopMin
        
        let command = String(format: "*LED%@LEVEL%@TS%04dTE%04d#", freq, level, startTime, stopTime)
        
        if bluetoothManager.sendCommand(command) {
            print("Set command sent: \(command)")
            showAlert(title: "成功", message: "参数设置已发送")
        } else {
            showAlert(title: "错误", message: "发送失败")
        }
    }
    
    @IBAction func rtcButtonTapped(_ sender: UIButton) {
        guard bluetoothManager.isConnected else {
            showAlert(title: "未连接", message: "请先连接设备")
            return
        }
        
        syncRTC()
        showAlert(title: "成功", message: "时间校准已发送")
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    private func processReceivedMessage(_ message: String) {
        print("Received message: \(message)")
        
        var processedMessage = message.replacingOccurrences(of: "*", with: "")
        processedMessage = processedMessage.replacingOccurrences(of: "#", with: "")
        processedMessage = processedMessage.replacingOccurrences(of: "\r", with: "")
        processedMessage = processedMessage.replacingOccurrences(of: "\n", with: "")
        
        if processedMessage.contains("RT") && processedMessage.contains("TS") &&
           processedMessage.contains("TE") && processedMessage.contains("L") {
            
            DispatchQueue.main.async {
                self.parseStatusMessage(processedMessage)
            }
        }
    }
    
    private func parseStatusMessage(_ message: String) {
        // Parse date
        if let rdRange = message.range(of: "RD"),
           let rtRange = message.range(of: "RT") {
            let dateStr = String(message[rdRange.upperBound..<rtRange.lowerBound])
            rtcDateLabel.text = dateStr
        }
        
        // Parse time
        if let rtRange = message.range(of: "RT"),
           let tsRange = message.range(of: "TS") {
            let timeStr = String(message[rtRange.upperBound..<tsRange.lowerBound])
            rtcTimeLabel.text = timeStr
        }
        
        // Parse start time
        var startTime = 0
        if let tsRange = message.range(of: "TS"),
           let teRange = message.range(of: "TE") {
            let startTimeStr = String(message[tsRange.upperBound..<teRange.lowerBound])
            startTime = Int(startTimeStr) ?? 0
        }
        
        // Parse stop time
        var stopTime = 0
        if let teRange = message.range(of: "TE"),
           let lRange = message.range(of: "L") {
            let stopTimeStr = String(message[teRange.upperBound..<lRange.lowerBound])
            stopTime = Int(stopTimeStr) ?? 0
        }
        
        // Parse level
        if let lRange = message.range(of: "L"),
           let fRange = message.range(of: "F") {
            let levelStr = String(message[lRange.upperBound..<fRange.lowerBound])
            levelLabel.text = levelStr
        }
        
        // Parse frequency
        if let fRange = message.range(of: "F") {
            let freqStr = String(message[fRange.upperBound...])
            freqLabel.text = freqStr
        }
        
        // Format and display set time
        let startHour = startTime / 60
        let startMin = startTime % 60
        let stopHour = stopTime / 60
        let stopMin = stopTime % 60
        
        setTimeLabel.text = String(format: "%02d:%02d~%02d:%02d", startHour, startMin, stopHour, stopMin)
    }
    
}

// MARK: - UIPickerViewDataSource & UIPickerViewDelegate
extension MainViewController: UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        switch pickerView {
        case levelPicker:
            return levels.count
        case freqPicker:
            return freqs.count
        case startHourPicker, stopHourPicker:
            return hours.count
        case startMinPicker, stopMinPicker:
            return minutes.count
        default:
            return 0
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        switch pickerView {
        case levelPicker:
            return levels[row]
        case freqPicker:
            return freqs[row]
        case startHourPicker, stopHourPicker:
            return hours[row]
        case startMinPicker, stopMinPicker:
            return minutes[row]
        default:
            return nil
        }
    }
}

// MARK: - BluetoothManagerDelegate
extension MainViewController: BluetoothManagerDelegate {
    func bluetoothManagerDidUpdateState(_ manager: BluetoothManager) {
        DispatchQueue.main.async {
            self.updateConnectionStatus()
        }
    }
    
    func bluetoothManager(_ manager: BluetoothManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) {
        // Not used in main view
    }
    
    func bluetoothManager(_ manager: BluetoothManager, didConnect peripheral: CBPeripheral) {
        DispatchQueue.main.async {
            self.updateConnectionStatus()
        }
    }
    
    func bluetoothManager(_ manager: BluetoothManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async {
            self.updateConnectionStatus()
        }
    }
    
    func bluetoothManager(_ manager: BluetoothManager, didReceiveData data: Data) {
        if let message = String(data: data, encoding: .utf8) {
            processReceivedMessage(message)
        }
    }
    
    func bluetoothManager(_ manager: BluetoothManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async {
            self.updateConnectionStatus()
        }
    }
}
