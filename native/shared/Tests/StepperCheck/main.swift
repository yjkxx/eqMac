import Foundation
import Shared

private let tolerance = 1e-10

private func check(_ condition: @autoclosure () -> Bool, _ message: String) {
  guard condition() else {
    fputs("StepperCheck failed: \(message)\n", stderr)
    exit(1)
  }
}

private func approximatelyEqual(_ lhs: Double, _ rhs: Double, tolerance allowedDifference: Double = tolerance) -> Bool {
  return abs(lhs - rhs) <= allowedDifference
}

let oneDecibelDown = SoftwareVolumeStepper.step(
  gain: 1,
  muted: false,
  direction: .down,
  boostEnabled: false
)
check(
  approximatelyEqual(oneDecibelDown.gain, pow(10, -1.0 / 20)),
  "normal step is not -1 dB"
)

let fineDown = SoftwareVolumeStepper.step(
  gain: 1,
  muted: false,
  direction: .down,
  stepDecibels: SoftwareVolumeStepper.fineStepDecibels,
  boostEnabled: false
)
check(
  approximatelyEqual(fineDown.gain, pow(10, -0.25 / 20)),
  "fine step is not -0.25 dB"
)

var fourFineGain = 1.0
for _ in 0..<4 {
  fourFineGain = SoftwareVolumeStepper.step(
    gain: fourFineGain,
    muted: false,
    direction: .down,
    stepDecibels: SoftwareVolumeStepper.fineStepDecibels,
    boostEnabled: false
  ).gain
}
check(
  approximatelyEqual(fourFineGain, oneDecibelDown.gain),
  "four fine steps do not equal one normal step"
)

var floorResult = SoftwareVolumeStepResult(gain: 1, muted: false)
for _ in 0..<63 {
  floorResult = SoftwareVolumeStepper.step(
    gain: floorResult.gain,
    muted: floorResult.muted,
    direction: .down,
    boostEnabled: false
  )
}
check(
  approximatelyEqual(floorResult.gain, SoftwareVolumeStepper.minimumAudibleGain),
  "63 steps do not land on -63 dB"
)
check(!floorResult.muted, "-63 dB should still be audible")

floorResult = SoftwareVolumeStepper.step(
  gain: floorResult.gain,
  muted: floorResult.muted,
  direction: .down,
  boostEnabled: false
)
check(floorResult.muted, "the step below -63 dB should mute")

let restored = SoftwareVolumeStepper.step(
  gain: SoftwareVolumeStepper.amplitude(fromDecibels: -20),
  muted: true,
  direction: .up,
  boostEnabled: false
)
check(!restored.muted, "Volume Up should restore a muted level")
check(
  approximatelyEqual(restored.gain, SoftwareVolumeStepper.amplitude(fromDecibels: -20)),
  "unmute should preserve the remembered level"
)

let boosted = SoftwareVolumeStepper.step(
  gain: 1,
  muted: false,
  direction: .up,
  boostEnabled: true
)
let expectedBoostGain = 1 + (pow(10, 1.0 / 20) - 1) / 5
check(approximatelyEqual(boosted.gain, expectedBoostGain), "boost step is not +1 dB")

let arbitraryStartDecibels = -20.37
let arbitraryStep = SoftwareVolumeStepper.step(
  gain: SoftwareVolumeStepper.amplitude(fromDecibels: arbitraryStartDecibels),
  muted: false,
  direction: .up,
  boostEnabled: false
)
check(
  approximatelyEqual(
    SoftwareVolumeStepper.decibels(fromModelGain: arbitraryStep.gain),
    arbitraryStartDecibels + 1
  ),
  "an arbitrary starting level did not move by exactly 1 dB"
)

let invalidStep = SoftwareVolumeStepper.step(
  gain: .nan,
  muted: false,
  direction: .down,
  boostEnabled: false
)
check(invalidStep.muted, "an invalid persisted gain was not safely muted")

check(
  approximatelyEqual(
    Double(SoftwareVolumeStepper.driverScalar(fromModelGain: SoftwareVolumeStepper.minimumAudibleGain)),
    1.0 / 64.0,
    tolerance: 1e-6
  ),
  "driver scalar does not reserve zero for mute"
)

print("StepperCheck passed: constant-dB stepping and boundaries are correct")
