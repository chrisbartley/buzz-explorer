//
//  ViewController.swift
//  Buzz Explorer
//
//  Created by Chris Bartley on 9/4/20.
//  Copyright © 2020 Chris Bartley. All rights reserved.
//

import UIKit
import BuzzBLE
import BirdbrainBLE

class ViewController: UIViewController {
   @IBOutlet var scanningStackView: UIStackView!
   @IBOutlet var queryingDeviceStackView: UIStackView!
   @IBOutlet var mainStackView: UIStackView!

   @IBOutlet var buzzIdLabel: UILabel!
   @IBOutlet var serialNumberLabel: UILabel!

   @IBOutlet var productLineLabel: UILabel!
   @IBOutlet var boardRevisionLabel: UILabel!
   @IBOutlet var versionNumberLabel: UILabel!
   @IBOutlet var userImageVersionLabel: UILabel!
   @IBOutlet var factoryImageVersionLabel: UILabel!
   @IBOutlet var softDeviceImageVersionLabel: UILabel!
   @IBOutlet var bootloaderImageVersionLabel: UILabel!
   @IBOutlet var nrfBootloaderImageVersionLabel: UILabel!
   @IBOutlet var batteryLabel: UILabel!

   @IBOutlet var motor0Slider: UISlider!
   @IBOutlet var motor1Slider: UISlider!
   @IBOutlet var motor2Slider: UISlider!
   @IBOutlet var motor3Slider: UISlider!
   @IBOutlet var motor0ValueLabel: UILabel!
   @IBOutlet var motor1ValueLabel: UILabel!
   @IBOutlet var motor2ValueLabel: UILabel!
   @IBOutlet var motor3ValueLabel: UILabel!

   private var motorSliders = [UISlider]()
   private var motorSliderValueLabels = [UILabel]()

   private let buzzManager = BuzzManager()
   private var buzz: Buzz?

   override func viewDidLoad() {
      super.viewDidLoad()

      motorSliders.append(motor0Slider)
      motorSliders.append(motor1Slider)
      motorSliders.append(motor2Slider)
      motorSliders.append(motor3Slider)
      motorSliderValueLabels.append(motor0ValueLabel)
      motorSliderValueLabels.append(motor1ValueLabel)
      motorSliderValueLabels.append(motor2ValueLabel)
      motorSliderValueLabels.append(motor3ValueLabel)

      buzzManager.delegate = self
   }

   // TODO: Changing multiple sliders too fast results in unknownCommand errors. Deal with it another day.
   @IBAction func sliderChanged(_ slider: UISlider) {
      let value: UInt8 = UInt8(slider.value)
      motorSliderValueLabels[slider.tag].text = String(value)

      buzz?.setMotorVibration(UInt8(motor0Slider.value),
                              UInt8(motor1Slider.value),
                              UInt8(motor2Slider.value),
                              UInt8(motor3Slider.value))
   }
}

extension ViewController: BuzzManagerDelegate {
   private func scan() {
      scanningStackView.isHidden = false
      queryingDeviceStackView.isHidden = true
      mainStackView.isHidden = true

      if buzzManager.startScanning(timeoutSecs: -1, assumeDisappearanceAfter: 1) {
         print("Scanning...")
      } else {
         // TODO:
         print("Failed to start scanning!")
      }
   }

   func didUpdateState(to state: BuzzManagerState) {
      print("BuzzManagerDelegate.didUpdateState: \(state)")
      if state == .enabled {
         scan()
      }
   }

   func didDiscover(uuid: UUID, advertisementData: [String: Any], rssi: NSNumber) {
      if buzzManager.connectToBuzz(havingUUID: uuid) {
         print("BuzzManagerDelegate.didDiscover: uuid=\(uuid), attempting to connect...")
      } else {
         print("Cannot connect!")
      }
   }

   func didRediscover(uuid: UUID, advertisementData: [String: Any], rssi: NSNumber) {
      // print("BuzzManagerDelegate.didRediscover: uuid=\(uuid)")
   }

   func didDisappear(uuid: UUID) {
      print("BuzzManagerDelegate.didDisappear: uuid=\(uuid)")
   }

   func didConnectTo(uuid: UUID) {
      if let buzz = buzzManager.getBuzz(uuid: uuid) {
         print("BuzzManagerDelegate.didConnectTo: uuid=\(uuid)")

         // stop scanning
         if buzzManager.stopScanning() {
            print("Scanning stopped")
         } else {
            print("Failed to stop scanning!")
         }

         self.buzz = buzz

         // register self as delegate and enable communication
         buzz.delegate = self
         buzz.enableCommuication()

         DispatchQueue.main.async {
            self.scanningStackView.isHidden = true
            self.queryingDeviceStackView.isHidden = false
            self.mainStackView.isHidden = true

            // reset motor sliders
            for i in 0..<self.motorSliders.count {
               self.motorSliders[i].setValue(0, animated: false)
               self.motorSliderValueLabels[i].text = "0"
            }
         }
      } else {
         print("BuzzManagerDelegate.didConnectTo: received didConnectTo, but buzzManager doesn't recognize UUID \(uuid)")
      }
   }

   func didDisconnectFrom(uuid: UUID, error: Error?) {
      print("BuzzManagerDelegate.didDisconnectFrom: uuid=\(uuid)")

      buzz = nil

      scan()
   }

   func didFailToConnectTo(uuid: UUID, error: Error?) {
      print("BuzzManagerDelegate.didFailToConnectTo: uuid=\(uuid)")
   }
}

extension ViewController: BuzzDelegate {
   func buzz(_ buzz: Buzz, isCommunicationEnabled: Bool, error: Error?) {
      if let error = error {
         print("BuzzDelegate.isCommunicationEnabled: \(isCommunicationEnabled), error: \(error))")
      } else {
         if isCommunicationEnabled {
            print("BuzzDelegate.isCommunicationEnabled: communication enabled, requesting device and battery info and then authorizing...")
            buzz.requestBatteryInfo() // TODO: Add a timer to update battery level periodically
            buzz.requestDeviceInfo()
            buzz.authorize()
         } else {
            // TODO:
            print("BuzzDelegate.isCommunicationEnabled: failed to enable communication. Um...darn.")
         }
      }
   }

   func buzz(_ buzz: Buzz, isAuthorized: Bool, errorMessage: String?) {
      if isAuthorized {
         // now that we're authorized, disable the mic, enable motors, and stop the motors
         buzz.disableMic()
         buzz.enableMotors()
         buzz.clearMotorsQueue()
      } else {
         // TODO:
         print("Failed to authorize: \(String(describing: errorMessage))")
      }
   }

   func buzz(_ buzz: Buzz, batteryInfo: Buzz.BatteryInfo) {
      print("BuzzDelegate.batteryInfo: \(batteryInfo)")
      DispatchQueue.main.async {
         self.batteryLabel.text = "\(batteryInfo.level)%"
      }
   }

   func buzz(_ buzz: Buzz, deviceInfo: Buzz.DeviceInfo) {
      print("BuzzDelegate.deviceInfo: \(deviceInfo)")

      DispatchQueue.main.async {
         self.buzzIdLabel.text = "Buzz \(deviceInfo.id)"
         self.serialNumberLabel.text = deviceInfo.serialNumber
         self.versionNumberLabel.text = deviceInfo.version.description
         self.userImageVersionLabel.text = deviceInfo.userImageVersion.description
         self.factoryImageVersionLabel.text = deviceInfo.factoryImageVersion.description
         self.softDeviceImageVersionLabel.text = deviceInfo.softDeviceVersion.description
         self.bootloaderImageVersionLabel.text = deviceInfo.bootloaderVersion.description
         self.nrfBootloaderImageVersionLabel.text = deviceInfo.nrfBootloaderVersion.description
         self.boardRevisionLabel.text = "\(deviceInfo.boardRevision)"
         self.productLineLabel.text = "\(deviceInfo.productLine)"

         self.queryingDeviceStackView.isHidden = true
         self.mainStackView.isHidden = false
      }
   }

   func buzz(_ buzz: Buzz, isMicEnabled: Bool) {
      print("BuzzDelegate.isMicEnabled: \(isMicEnabled)")
   }

   func buzz(_ buzz: Buzz, areMotorsEnabled: Bool) {
      print("BuzzDelegate.areMotorsEnabled: \(areMotorsEnabled)")
   }

   func buzz(_ buzz: Buzz, isMotorsQueueCleared: Bool) {
      print("BuzzDelegate.isMotorsQueueCleared: \(isMotorsQueueCleared)")
   }

   func buzz(_ buzz: Buzz, responseError error: Error) {
      print("BuzzDelegate.responseError: \(error)")
   }

   func buzz(_ buzz: Buzz, unknownCommand command: String) {
      print("BuzzDelegate.unknownCommand: \(command) length (\(command.count))")
   }

   func buzz(_ buzz: Buzz, badRequestFor command: Buzz.Command, errorMessage: String?) {
      print("BuzzDelegate.badRequestFor: \(command), error: \(String(describing: errorMessage))")
   }

   func buzz(_ buzz: Buzz, failedToParse responseMessage: String, forCommand command: Buzz.Command) {
      print("BuzzDelegate.failedToParse: \(responseMessage) forCommand \(command)")
   }
}
