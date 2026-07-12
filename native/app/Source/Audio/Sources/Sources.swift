//
//  Source.swift
//  eqMac
//
//  Created by Roman Kisil on 24/06/2018.
//  Copyright © 2018 Roman Kisil. All rights reserved.
//

import Foundation
import AppKit
import ReSwift
import EmitterKit
import Shared

public enum SourceType : String {
  //    case File = "File"
  //    case Input = "Input"
  case System = "System"
  static let allValues = [
    //        File.rawValue,
    //        Input.rawValue,
    System.rawValue
  ]
}

class Sources {
  //    typealias StoreSubscriberStateType = SourceState
  var source: SourceType! = .System {
    didSet {
      sourceChanged.emit(source)
    }
  }
  let sourceChanged = Event<SourceType>()
  var isReady = EmitterKit.Event<Void>()

  var system: SystemAudioSource!
  
  init () {
    Console.log("Creating Sources")
    initializeSystem()
  }

  func reset () {
    system = nil
  }
  
  func initializeSystem () {
    system = SystemAudioSource()
  }
}
