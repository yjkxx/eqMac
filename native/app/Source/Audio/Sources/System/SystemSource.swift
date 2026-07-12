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
  // Kept type-erased so the app can retain the macOS 14.2-only tap while the
  // project continues to compile with its older deployment target.
  private let tapOwner: AnyObject

  init () {
    guard #available(macOS 14.2, *) else {
      fatalError("eqMac dB system-audio capture requires macOS 14.2 or newer")
    }

    let audioTap: SystemAudioTap
    do {
      audioTap = try SystemAudioTap(
        outputDeviceUID: Constants.DRIVER_DEVICE_UID,
        clockDeviceUID: Application.selectedDevice?.uid ?? Constants.TARGET_OUTPUT_DEVICE_UID
      )
    } catch {
      fatalError("Could not create the eqMac dB system-audio tap: \(error)")
    }
    tapOwner = audioTap
    super.init(device: audioTap.device)
  }
}

private enum SystemAudioTapError: Error, CustomStringConvertible {
  case createTap(OSStatus)
  case createAggregate(OSStatus)
  case lookupAggregate(AudioObjectID)
  case aggregateInputTimeout(AudioObjectID)

  var description: String {
    switch self {
    case .createTap(let status):
      return "AudioHardwareCreateProcessTap failed (\(status))"
    case .createAggregate(let status):
      return "AudioHardwareCreateAggregateDevice failed (\(status))"
    case .lookupAggregate(let id):
      return "Core Audio did not expose aggregate device \(id)"
    case .aggregateInputTimeout(let id):
      return "Core Audio aggregate device \(id) did not publish its tap input stream"
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

  init(outputDeviceUID: String, clockDeviceUID: String) throws {
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
      // AVAudioEngine's legacy HAL input helper only accepts a duplex current
      // device. The target DAC supplies the aggregate's muted output side and
      // clock; the process tap remains its sole input source.
      kAudioAggregateDeviceSubDeviceListKey: [[
        kAudioSubDeviceUIDKey: clockDeviceUID
      ]],
      kAudioAggregateDeviceMainSubDeviceKey: clockDeviceUID,
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

    // HAL publishes a newly-created aggregate's tap stream asynchronously.
    // AVAudioEngine sees a 0 Hz / 0 channel format if it is attached too soon.
    for _ in 0..<100 where aggregateDevice.channels(direction: .recording) == 0
      || aggregateDevice.channels(direction: .playback) == 0 {
      usleep(20_000)
    }
    guard aggregateDevice.channels(direction: .recording) > 0,
          aggregateDevice.channels(direction: .playback) > 0 else {
      AudioHardwareDestroyAggregateDevice(aggregateID)
      AudioHardwareDestroyProcessTap(tapID)
      aggregateID = AudioObjectID(kAudioObjectUnknown)
      tapID = AudioObjectID(kAudioObjectUnknown)
      throw SystemAudioTapError.aggregateInputTimeout(newAggregateID)
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
