//
//  AudioUnitViewController.swift
//  AUv3ExtensionExampleExtension
//
//  Created by Corné Driesprong on 31/03/2023.
//

import Combine
import CoreAudioKit
import os

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
     
        // schedule a note on/off event
        let noteOn = MIDIEvent(
            timestamp: 0,
            status: 0x90,
            data1: 60,
            data2: 100)
        audioUnit.add(noteOn)
        
        let noteOff = MIDIEvent(
            timestamp: 0.25,
            status: 0x80,
            data1: 60,
            data2: 0)
        audioUnit.add(noteOff)
        
        return audioUnit
    }
}
