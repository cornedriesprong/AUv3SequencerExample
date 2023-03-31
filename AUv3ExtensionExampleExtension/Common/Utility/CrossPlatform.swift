//
//  CrossPlatform.swift
//  AUv3ExtensionExampleExtension
//
//  Created by Corné Driesprong on 31/03/2023.
//

import Foundation
import SwiftUI

#if os(iOS)
typealias HostingController = UIHostingController
#elseif os(macOS)
typealias HostingController = NSHostingController

extension NSView {
	
	func bringSubviewToFront(_ view: NSView) {
		// This function is a no-opp for macOS
	}
}
#endif
