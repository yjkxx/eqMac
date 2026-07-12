import XCTest
@testable import Shared

final class SoftwareVolumeStepperTests: XCTestCase {
  private let accuracy = 1e-10

  func testNormalStepIsOneDecibel() {
    let result = SoftwareVolumeStepper.step(
      gain: 1,
      muted: false,
      direction: .down,
      boostEnabled: false
    )

    XCTAssertEqual(result.gain, pow(10, -1.0 / 20), accuracy: accuracy)
    XCTAssertFalse(result.muted)
  }

  func testFineStepIsQuarterDecibel() {
    let result = SoftwareVolumeStepper.step(
      gain: 1,
      muted: false,
      direction: .down,
      stepDecibels: SoftwareVolumeStepper.fineStepDecibels,
      boostEnabled: false
    )

    XCTAssertEqual(result.gain, pow(10, -0.25 / 20), accuracy: accuracy)
  }

  func testFourFineStepsEqualOneNormalStep() {
    var gain = 1.0
    for _ in 0..<4 {
      gain = SoftwareVolumeStepper.step(
        gain: gain,
        muted: false,
        direction: .down,
        stepDecibels: SoftwareVolumeStepper.fineStepDecibels,
        boostEnabled: false
      ).gain
    }

    XCTAssertEqual(gain, pow(10, -1.0 / 20), accuracy: accuracy)
  }

  func testFloorThenMute() {
    var result = SoftwareVolumeStepResult(gain: 1, muted: false)
    for _ in 0..<63 {
      result = SoftwareVolumeStepper.step(
        gain: result.gain,
        muted: result.muted,
        direction: .down,
        boostEnabled: false
      )
    }

    XCTAssertEqual(result.gain, SoftwareVolumeStepper.minimumAudibleGain, accuracy: accuracy)
    XCTAssertFalse(result.muted)

    result = SoftwareVolumeStepper.step(
      gain: result.gain,
      muted: result.muted,
      direction: .down,
      boostEnabled: false
    )
    XCTAssertTrue(result.muted)
    XCTAssertEqual(result.gain, SoftwareVolumeStepper.minimumAudibleGain, accuracy: accuracy)
  }

  func testUpFromMuteRestoresBeforeStepping() {
    let remembered = SoftwareVolumeStepper.amplitude(fromDecibels: -20)
    let result = SoftwareVolumeStepper.step(
      gain: remembered,
      muted: true,
      direction: .up,
      boostEnabled: false
    )

    XCTAssertEqual(result.gain, remembered, accuracy: accuracy)
    XCTAssertFalse(result.muted)
  }

  func testLegacyMutedZeroRestartsAtFloor() {
    let result = SoftwareVolumeStepper.step(
      gain: 0,
      muted: true,
      direction: .up,
      boostEnabled: false
    )

    XCTAssertEqual(result.gain, SoftwareVolumeStepper.minimumAudibleGain, accuracy: accuracy)
    XCTAssertFalse(result.muted)
  }

  func testBoostUsesAudibleAmplitude() {
    let result = SoftwareVolumeStepper.step(
      gain: 1,
      muted: false,
      direction: .up,
      boostEnabled: true
    )

    let expectedModelGain = 1 + (pow(10, 1.0 / 20) - 1) / 5
    XCTAssertEqual(result.gain, expectedModelGain, accuracy: accuracy)
  }

  func testBoostDisabledClampsAtUnity() {
    let result = SoftwareVolumeStepper.step(
      gain: 1,
      muted: false,
      direction: .up,
      boostEnabled: false
    )

    XCTAssertEqual(result.gain, 1, accuracy: accuracy)
  }

  func testArbitraryLevelMovesByExactlyOneDecibel() {
    let startingDecibels = -20.37
    let result = SoftwareVolumeStepper.step(
      gain: SoftwareVolumeStepper.amplitude(fromDecibels: startingDecibels),
      muted: false,
      direction: .up,
      boostEnabled: false
    )

    XCTAssertEqual(
      SoftwareVolumeStepper.decibels(fromModelGain: result.gain),
      startingDecibels + 1,
      accuracy: accuracy
    )
  }

  func testUnityCrossingRoundTripsWithBoost() {
    let belowUnity = SoftwareVolumeStepper.amplitude(fromDecibels: -0.4)
    let aboveUnity = SoftwareVolumeStepper.step(
      gain: belowUnity,
      muted: false,
      direction: .up,
      boostEnabled: true
    )
    let roundTrip = SoftwareVolumeStepper.step(
      gain: aboveUnity.gain,
      muted: false,
      direction: .down,
      boostEnabled: true
    )

    XCTAssertGreaterThan(aboveUnity.gain, 1)
    XCTAssertEqual(roundTrip.gain, belowUnity, accuracy: accuracy)
  }

  func testInvalidPersistedGainIsSanitized() {
    let result = SoftwareVolumeStepper.step(
      gain: .nan,
      muted: false,
      direction: .down,
      boostEnabled: false
    )

    XCTAssertTrue(result.muted)
    XCTAssertEqual(result.gain, SoftwareVolumeStepper.minimumAudibleGain, accuracy: accuracy)
  }

  func testDriverScaleReservesZeroForSilence() {
    XCTAssertEqual(SoftwareVolumeStepper.driverScalar(fromModelGain: 0), 0)
    XCTAssertEqual(
      SoftwareVolumeStepper.driverScalar(fromModelGain: SoftwareVolumeStepper.minimumAudibleGain),
      1.0 / 64.0,
      accuracy: 1e-6
    )
    XCTAssertEqual(SoftwareVolumeStepper.modelGain(fromDriverScalar: 1), 1, accuracy: accuracy)
  }
}
