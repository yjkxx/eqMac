//
//  DeviceInput.swift
//  eqMac
//
//  Created by Roman Kisil on 06/11/2018.
//  Copyright © 2018 Roman Kisil. All rights reserved.
//

import Foundation
import AMCoreAudio

class InputSource {
  let device: AudioDevice
  
  public init(device: AudioDevice) {
    self.device = device
  }
}
