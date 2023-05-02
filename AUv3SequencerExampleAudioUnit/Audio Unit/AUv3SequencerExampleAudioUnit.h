//
//  AUv3SequencerExampleAudioUnit.h
//  AUv3SequencerExample
//
//  Created by Corné Driesprong on 31/03/2023.
//

#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

#define NOTE_ON             0x90
#define NOTE_OFF            0x80
#define MAX_EVENT_COUNT     256
#define BUFFER_LENGTH       16384

typedef struct MIDIEvent {
    double timestamp;
    uint8_t status;
    uint8_t data1;
    uint8_t data2;
} MIDIEvent;

typedef struct MIDISequence {
    double length;
    int eventCount;
    struct MIDIEvent events[MAX_EVENT_COUNT];
} MIDISequence;

enum SequenceOperationType { Add, Delete };

struct SequenceOperation {
    enum SequenceOperationType type;
    MIDIEvent event;
};

@interface AUv3SequencerExampleAudioUnit : AUAudioUnit
- (void)addEvent:(MIDIEvent)event;
- (void)deleteEvent:(MIDIEvent)event;
@end
