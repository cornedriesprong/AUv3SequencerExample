//
//  AudioUnitViewController.swift
//  AUv3ExtensionExampleExtension
//
//  Created by Corné Driesprong on 31/03/2023.
//

import Combine
import CoreAudioKit
import os
import SwiftUI

private let log = Logger(subsystem: "cp3.io.AUv3ExtensionExampleExtension", category: "AudioUnitViewController")

public class AudioUnitViewController: AUViewController, AUAudioUnitFactory {
    var audioUnit: AUAudioUnit?
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        audioUnit = try AUv3ExtensionExampleExtensionAudioUnit(componentDescription: componentDescription, options: [])
        
        guard let audioUnit = self.audioUnit as? AUv3ExtensionExampleExtensionAudioUnit else {
            log.error("Unable to create AUv3ExtensionExampleExtensionAudioUnit")
            return audioUnit!
        }
        
        return audioUnit
    }
}
