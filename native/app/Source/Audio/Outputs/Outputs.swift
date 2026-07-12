//
//  Outputs.swift
//  eqMac
//
//  Created by Romans Kisils on 04/11/2019.
//  Copyright © 2019 Romans Kisils. All rights reserved.
//

import Foundation
import AVFoundation
import AMCoreAudio
import CoreAudio

class Outputs {
  static var current: AudioDeviceID? {
    get {
      return Application.enabled ? Application.selectedDevice?.id : AudioDevice.currentOutputDevice.id
    }
  }
  
  static func isDeviceAllowed(_ device: AudioDevice) -> Bool {
    return device.transportType != nil
      && SUPPORTED_TRANSPORT_TYPES.contains(device.transportType!)
      && !device.isInputOnlyDevice()
      && !device.name.contains("CADefaultDeviceAggregate")
      && device.uid != Constants.DRIVER_DEVICE_UID
      && !Constants.LEGACY_DRIVER_UIDS.contains(device.uid ?? "")
  }
  
  static func shouldAutoSelect (_ device: AudioDevice) -> Bool {
    return isTargetDevice(device)
  }

  static func isTargetDevice(_ device: AudioDevice) -> Bool {
    // The exact UID identifies this DAC on the user's Mac. The name fallback
    // keeps activation working if the USB location/serial component changes.
    return device.uid == Constants.TARGET_OUTPUT_DEVICE_UID
      || device.name == Constants.TARGET_OUTPUT_DEVICE_NAME
  }
  
  static var allowedDevices: [AudioDevice] {
    return AudioDevice.allOutputDevices().filter({ isDeviceAllowed($0) })
  }
  
  static let SUPPORTED_TRANSPORT_TYPES = [
    TransportType.airPlay,
    TransportType.bluetooth,
    TransportType.bluetoothLE,
    TransportType.builtIn,
    TransportType.displayPort,
    TransportType.fireWire,
    TransportType.hdmi,
    TransportType.pci,
    TransportType.thunderbolt,
    TransportType.usb,
    TransportType.aggregate,
    TransportType.virtual
  ]
}
