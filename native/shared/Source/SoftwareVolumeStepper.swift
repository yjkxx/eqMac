//
//  SoftwareVolumeStepper.swift
//  eqMac dB
//

import Foundation

public enum SoftwareVolumeStepDirection {
  case up
  case down
}

public struct SoftwareVolumeStepResult: Equatable {
  public let gain: Double
  public let muted: Bool

  public init(gain: Double, muted: Bool) {
    self.gain = gain
    self.muted = muted
  }
}

/// Converts eqMac's model gain to audible amplitude and advances it in dB.
///
/// Model gain is direct amplitude from 0...1. With boost enabled, 1...2 is
/// mapped by eqMac's mixer to audible amplitude 1...6.
public enum SoftwareVolumeStepper {
  public static let normalStepDecibels = 1.0
  public static let fineStepDecibels = 0.25
  public static let minimumAudibleDecibels = -63.0
  public static let maximumBoostAmplitude = 6.0
  public static let maximumModelGain = 2.0

  public static var minimumAudibleGain: Double {
    return amplitude(fromDecibels: minimumAudibleDecibels)
  }

  public static func step(
    gain: Double,
    muted: Bool,
    direction: SoftwareVolumeStepDirection,
    stepDecibels: Double = normalStepDecibels,
    boostEnabled: Bool
  ) -> SoftwareVolumeStepResult {
    let sanitizedGain = sanitize(gain: gain, boostEnabled: boostEnabled)

    if muted {
      if direction == .down {
        return SoftwareVolumeStepResult(gain: sanitizedGain, muted: true)
      }

      // Volume Up first restores the remembered level. Invalid legacy zero
      // values restart at the quietest audible level.
      return SoftwareVolumeStepResult(
        gain: sanitizedGain > 0 ? sanitizedGain : minimumAudibleGain,
        muted: false
      )
    }

    let safeStep = stepDecibels.isFinite ? max(0, stepDecibels) : normalStepDecibels
    var currentDecibels = decibels(fromModelGain: sanitizedGain)
    if !currentDecibels.isFinite {
      currentDecibels = minimumAudibleDecibels
    }

    switch direction {
    case .down:
      if currentDecibels <= minimumAudibleDecibels + 1e-9 {
        return SoftwareVolumeStepResult(gain: minimumAudibleGain, muted: true)
      }

      let targetDecibels = max(minimumAudibleDecibels, currentDecibels - safeStep)
      return SoftwareVolumeStepResult(
        gain: modelGain(fromAudibleAmplitude: amplitude(fromDecibels: targetDecibels)),
        muted: false
      )

    case .up:
      let maximumDecibels = boostEnabled
        ? decibels(fromAmplitude: maximumBoostAmplitude)
        : 0
      let targetDecibels = min(maximumDecibels, currentDecibels + safeStep)
      return SoftwareVolumeStepResult(
        gain: modelGain(fromAudibleAmplitude: amplitude(fromDecibels: targetDecibels)),
        muted: false
      )
    }
  }

  public static func audibleAmplitude(fromModelGain gain: Double) -> Double {
    if gain <= 1 {
      return max(0, gain)
    }
    return 1 + 5 * (min(maximumModelGain, gain) - 1)
  }

  public static func modelGain(fromAudibleAmplitude amplitude: Double) -> Double {
    if amplitude <= 1 {
      return max(0, amplitude)
    }
    return min(maximumModelGain, 1 + (amplitude - 1) / 5)
  }

  public static func decibels(fromModelGain gain: Double) -> Double {
    return decibels(fromAmplitude: audibleAmplitude(fromModelGain: gain))
  }

  public static func decibels(fromAmplitude amplitude: Double) -> Double {
    guard amplitude > 0 else { return -.infinity }
    return 20 * log10(amplitude)
  }

  public static func amplitude(fromDecibels decibels: Double) -> Double {
    return pow(10, decibels / 20)
  }

  /// Maps actual software gain to the virtual driver's normalized dB control.
  /// Gain above unity is represented as 1 because the driver has no boost range.
  public static func driverScalar(fromModelGain gain: Double) -> Float32 {
    guard gain.isFinite, gain > 0 else { return 0 }
    return VolumeConverter.toScalar(Float32(min(gain, 1)))
  }

  /// Converts the virtual driver's normalized dB control back to software gain.
  public static func modelGain(fromDriverScalar scalar: Float32) -> Double {
    let clamped = min(max(scalar, 0), 1)
    return Double(VolumeConverter.fromScalar(clamped))
  }

  private static func sanitize(gain: Double, boostEnabled: Bool) -> Double {
    guard gain.isFinite else { return minimumAudibleGain }
    guard gain > 0 else { return 0 }
    let maximum = boostEnabled ? maximumModelGain : 1
    return min(max(gain, minimumAudibleGain), maximum)
  }
}
