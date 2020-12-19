//
//  ViewController.swift
//  UDPHeadTrack
//
//  Created by Cedric on 11/12/2020.
//
 
import UIKit
import CoreMotion
import Network
 
class ViewController: UIViewController {
    let defaults = UserDefaults.standard
    var enabled = false
    var dimmed = false
    var motion = CMMotionManager()
    var connection: NWConnection?
    let rates = [1, 5, 10, 15, 20, 33, 40, 50, 66, 100]
    let intervals = [1.000, 0.200, 0.100, 0.065, 0.050, 0.030, 0.025, 0.020, 0.015, 0.010]
    var currentBrightness: CGFloat!
    var timer: Timer!
    
    @IBOutlet weak var activeState: UILabel!
    @IBOutlet weak var ipAddress: UITextField!
    @IBOutlet weak var port: UITextField!
    @IBOutlet weak var rateDisplay: UILabel!
    @IBOutlet weak var rateStepper: UIStepper!
    @IBOutlet weak var enableSwitch: UISwitch!
    
    func radToDegData(value: Double) -> Data {
        return withUnsafeBytes(of: value*180/Double.pi) { Data($0) }
    }
    func startStream(hostUDP: NWEndpoint.Host, portUDP: NWEndpoint.Port) {
        self.connection = NWConnection(host: hostUDP, port: portUDP, using: .udp)
        self.connection?.start(queue: .global())
        motion.deviceMotionUpdateInterval = intervals[Int(rateStepper.value)]
        motion.startDeviceMotionUpdates(to: OperationQueue.current!){ (data, error) in
            guard let trueData = data else {
                return
            }
            let udpMessage = self.radToDegData(value: 0) + self.radToDegData(value: 0) + self.radToDegData(value: 0) + self.radToDegData(value: trueData.attitude.yaw) + self.radToDegData(value: trueData.attitude.pitch) + self.radToDegData(value: trueData.attitude.roll)
            self.sendUDP(udpMessage)
        }
    }
    func stopStream() {
        motion.stopDeviceMotionUpdates()
        self.connection?.cancel()
        self.connection = nil
    }
    @objc func screenTapped() {
        if enabled {
            timer.invalidate()
            timer = nil
            unDim()
            timer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(dim), userInfo: nil, repeats: false)
        } else {
            view.endEditing(true)
        }
    }
    @IBAction func ipDonePressed() {
        view.endEditing(true)
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        if defaults.object(forKey: "ipAddress") != nil {
            ipAddress.text = defaults.string(forKey: "ipAddress")
        }
        if defaults.object(forKey: "port") != nil {
            port.text = defaults.string(forKey: "port")
        }
        if defaults.object(forKey: "rate") != nil {
            rateStepper.value = defaults.double(forKey: "rate")
        }
        rateDisplay.text = "\(rates[Int(rateStepper.value)]) Hz"
        let tap = UITapGestureRecognizer(target: self, action: #selector(screenTapped))
        view.addGestureRecognizer(tap)
    }
    
    func sendUDP(_ content: Data) {
        guard let connection = self.connection else {
            return
        }
        connection.send(content: content, completion: NWConnection.SendCompletion.contentProcessed(({ (error) in if false {}})))
    }
    @objc func dim() {
        if !dimmed {
            self.currentBrightness = UIScreen.main.brightness
            UIScreen.main.brightness = CGFloat(0.0)
            rateStepper.isUserInteractionEnabled = false
            enableSwitch.isUserInteractionEnabled = false
            dimmed = true
        }
    }
    func unDim() {
        if dimmed {
            UIScreen.main.brightness = currentBrightness
            rateStepper.isUserInteractionEnabled = true
            enableSwitch.isUserInteractionEnabled = true
            dimmed = false
        }
    }
    
    @IBAction func ipEdited() {
        defaults.setValue(ipAddress.text, forKey: "ipAddress")
    }
    @IBAction func portEdited() {
        defaults.setValue(port.text, forKey: "port")
    }
    @IBAction func rateStepperChanged() {
        if enabled {
            stopStream()
            timer.invalidate()
            timer = nil
            timer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(dim), userInfo: nil, repeats: false)
        }
        rateDisplay.text = "\(rates[Int(rateStepper.value)]) Hz"
        if enabled {
            startStream(hostUDP: .init(ipAddress.text!), portUDP: NWEndpoint.Port(rawValue: UInt16(port.text ?? "4242")!) ?? NWEndpoint.Port.any)
        }
        defaults.setValue(rateStepper.value, forKey: "rate")
    }
    @IBAction func enableSwitched() {
        view.endEditing(true)
        enabled.toggle()
        if enabled {
            ipAddress.isUserInteractionEnabled = false
            ipAddress.textColor = UIColor.placeholderText
            port.isUserInteractionEnabled = false
            port.textColor = UIColor.placeholderText
            startStream(hostUDP: .init(ipAddress.text!), portUDP: NWEndpoint.Port(rawValue: UInt16(port.text ?? "4242")!) ?? NWEndpoint.Port.any)
            activeState.text = "Enabled"
            activeState.textColor = UIColor.systemBlue
            timer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(dim), userInfo: nil, repeats: false)
        } else {
            ipAddress.isUserInteractionEnabled = true
            ipAddress.textColor = UIColor.label
            port.isUserInteractionEnabled = true
            port.textColor = UIColor.label
            stopStream()
            activeState.text = "Disabled"
            activeState.textColor = UIColor.secondaryLabel
            timer.invalidate()
            timer = nil
        }
    }
}
