//
//  AUv3ExtensionExampleExtensionParameterAddresses.h
//  AUv3ExtensionExampleExtension
//
//  Created by Corné Driesprong on 31/03/2023.
//

#pragma once

#include <AudioToolbox/AUParameters.h>

#ifdef __cplusplus
namespace AUv3ExtensionExampleExtensionParameterAddress {
#endif

typedef NS_ENUM(AUParameterAddress, AUv3ExtensionExampleExtensionParameterAddress) {
    sendNote = 0,
    midiNoteNumber = 1
};

#ifdef __cplusplus
}
#endif
