//
//  System.swift
//  eqMac
//
//  Created by Roman Kisil on 13/08/2018.
//  Copyright © 2018 Roman Kisil. All rights reserved.
//

import Foundation
import ReSwift
import CoreAudio
import EmitterKit
import AMCoreAudio
import SwiftyUserDefaults

class SystemAudioSource: InputSource {
  private let tap: SystemAudioTap

  init () {
    guard #available(macOS 14.2, *) else {
      fatalError("eqMac dB system-audio capture requires macOS 14.2 or newer")
    }

    do {
      tap = try SystemAudioTap(outputDeviceUID: Constants.DRIVER_DEVICE_UID)
    } catch {
      fatalError("Could not create the eqMac dB system-audio tap: \(error)")
    }
    super.init(device: tap.device)
  }
}

private enum SystemAudioTapError: Error, CustomStringConvertible {
  case createTap(OSStatus)
  case createAggregate(OSStatus)
  case lookupAggregate(AudioObjectID)

  var description: String {
    switch self {
    case .createTap(let status):
      return "AudioHardwareCreateProcessTap failed (\(status))"
    case .createAggregate(let status):
      return "AudioHardwareCreateAggregateDevice failed (\(status))"
    case .lookupAggregate(let id):
      return "Core Audio did not expose aggregate device \(id)"
    }
  }
}

/// Captures only audio destined for eqMac dB's virtual output. Unlike the old
/// virtual-input path, this uses macOS System Audio Recording and never opens a
/// microphone/input device.
@available(macOS 14.2, *)
private final class SystemAudioTap {
  let device: AudioDevice
  private var tapID = AudioObjectID(kAudioObjectUnknown)
  private var aggregateID = AudioObjectID(kAudioObjectUnknown)

  init(outputDeviceUID: String) throws {
    let description = CATapDescription(
      excludingProcesses: [],
      deviceUID: outputDeviceUID,
      stream: 0
    )
    description.name = "eqMac dB System Audio"
    description.isPrivate = true
    description.muteBehavior = .unmuted

    var newTapID = AudioObjectID(kAudioObjectUnknown)
    let tapStatus = AudioHardwareCreateProcessTap(description, &newTapID)
    guard tapStatus == noErr else {
      throw SystemAudioTapError.createTap(tapStatus)
    }
    tapID = newTapID

    let aggregateUID = "com.local.eqmacdb.tap.\(UUID().uuidString)"
    let tapEntry: [String: Any] = [
      kAudioSubTapUIDKey: description.uuid.uuidString,
      kAudioSubTapDriftCompensationKey: true
    ]
    let aggregateDescription: [String: Any] = [
      kAudioAggregateDeviceNameKey: "eqMac dB Capture",
      kAudioAggregateDeviceUIDKey: aggregateUID,
      kAudioAggregateDeviceIsPrivateKey: true,
      kAudioAggregateDeviceTapAutoStartKey: true,
      kAudioAggregateDeviceTapListKey: [tapEntry]
    ]

    var newAggregateID = AudioObjectID(kAudioObjectUnknown)
    let aggregateStatus = AudioHardwareCreateAggregateDevice(
      aggregateDescription as CFDictionary,
      &newAggregateID
    )
    guard aggregateStatus == noErr else {
      AudioHardwareDestroyProcessTap(tapID)
      tapID = AudioObjectID(kAudioObjectUnknown)
      throw SystemAudioTapError.createAggregate(aggregateStatus)
    }
    aggregateID = newAggregateID

    guard let aggregateDevice = AudioDevice.lookup(by: aggregateID) else {
      AudioHardwareDestroyAggregateDevice(aggregateID)
      AudioHardwareDestroyProcessTap(tapID)
      aggregateID = AudioObjectID(kAudioObjectUnknown)
      tapID = AudioObjectID(kAudioObjectUnknown)
      throw SystemAudioTapError.lookupAggregate(newAggregateID)
    }
    device = aggregateDevice
  }

  deinit {
    if aggregateID != AudioObjectID(kAudioObjectUnknown) {
      AudioHardwareDestroyAggregateDevice(aggregateID)
    }
    if tapID != AudioObjectID(kAudioObjectUnknown) {
      AudioHardwareDestroyProcessTap(tapID)
    }
  }
}
