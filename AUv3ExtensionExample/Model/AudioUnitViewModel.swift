//
//  AudioUnitViewModel.swift
//  AUv3ExtensionExample
//
//  Created by Corné Driesprong on 31/03/2023.
//

import SwiftUI
import AudioToolbox
import CoreAudioKit

struct AudioUnitViewModel {
    var showAudioControls: Bool = false
    var showMIDIContols: Bool = false
    var title: String = "-"
    var message: String = "No Audio Unit loaded.."
    var viewController: ViewController?
}
