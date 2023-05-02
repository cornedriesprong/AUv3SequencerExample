//
//  AUv3ExtensionExampleExtensionAudioUnit.h
//  AUv3ExtensionExampleExtension
//
//  Created by Corné Driesprong on 31/03/2023.
//

#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

#define NOTE_ON             0x90
#define NOTE_OFF            0x80
#define MAX_EVENT_COUNT     256

typedef struct SequencerSettings {
    double tempo;
    double sampleRate;
    const UInt32 frameCount;
} SequencerSettings;

typedef struct MIDIEvent {
    double timestamp;
    uint8_t status;
    uint8_t data1;
    uint8_t data2;
    double duration;
    bool queued;
} MIDIEvent;

typedef struct MIDISequence {
    double length;
    int eventCount;
    struct MIDIEvent events[MAX_EVENT_COUNT];
} MIDISequence;

@interface AUv3ExtensionExampleExtensionAudioUnit : AUAudioUnit
- (void)setupParameterTree:(AUParameterTree *)parameterTree;
@end
