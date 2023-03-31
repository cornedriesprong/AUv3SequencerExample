//
//  AUv3ExtensionExampleApp.swift
//  AUv3ExtensionExample
//
//  Created by Corné Driesprong on 31/03/2023.
//

import CoreMIDI
import SwiftUI

@main
class AUv3ExtensionExampleApp: App {
    @ObservedObject private var hostModel = AudioUnitHostModel()

    required init() {}

    var body: some Scene {
        WindowGroup {
            ContentView(hostModel: hostModel)
        }
    }
}
