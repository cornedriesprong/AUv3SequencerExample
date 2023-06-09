//
//  AUv3SequencerExampleAudioUnit.mm
//  AUv3SequencerExample
//
//  Created by Corné Driesprong on 31/03/2023.
//

#import "AUv3SequencerExampleAudioUnit.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreAudioKit/AUViewController.h>
#import <CoreMIDI/CoreMIDI.h>
#import "TPCircularBuffer.h"

@interface AUv3SequencerExampleAudioUnit ()

@property AUAudioUnitBusArray *inputBusArray;
@property AUAudioUnitBusArray *outputBusArray;
@property (nonatomic, readonly) AUAudioUnitBus *outputBus;
@end

TPCircularBuffer fifoBuffer;
MIDISequence sequence = {};

@implementation AUv3SequencerExampleAudioUnit

- (instancetype)initWithComponentDescription:(AudioComponentDescription)componentDescription options:(AudioComponentInstantiationOptions)options error:(NSError **)outError {
    self = [super initWithComponentDescription:componentDescription options:options error:outError];
    
    if (self == nil) { return nil; }
   
    // initialize FIFO buffer
    TPCircularBufferInit(&fifoBuffer, BUFFER_LENGTH);
   
    // initialize sequence
    sequence = {};
    sequence.eventCount = 0;
    sequence.length = 4;
   
    // initialize output bus
    AVAudioFormat *format = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100 channels:2];
    _outputBus = [[AUAudioUnitBus alloc] initWithFormat:format error:nil];
    _outputBus.maximumChannelCount = 8;
    
    // then an array with it
    _outputBusArray = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self
                                                             busType:AUAudioUnitBusTypeOutput
                                                              busses: @[_outputBus]];
    
    return self;
}

#pragma mark - AUAudioUnit Overrides

// If an audio unit has input, an audio unit's audio input connection points.
// Subclassers must override this property getter and should return the same object every time.
// See sample code.
- (AUAudioUnitBusArray *)inputBusses {
    return _inputBusArray;
}

// An audio unit's audio output connection points.
// Subclassers must override this property getter and should return the same object every time.
// See sample code.
- (AUAudioUnitBusArray *)outputBusses {
    return _outputBusArray;
}

// Allocate resources required to render.
// Subclassers should call the superclass implementation.
- (BOOL)allocateRenderResourcesAndReturnError:(NSError **)outError {
    [super allocateRenderResourcesAndReturnError:outError];
    
    return YES;
}

// Deallocate resources allocated in allocateRenderResourcesAndReturnError:
// Subclassers should call the superclass implementation.
- (void)deallocateRenderResources {
    [super deallocateRenderResources];
}

# pragma mark - Add/remove events

- (void)addEvent:(MIDIEvent)event {
    
    uint32_t availableBytes = 0;
    SequenceOperation *head = (SequenceOperation *)TPCircularBufferHead(&fifoBuffer, &availableBytes);
    SequenceOperation op = { Add, event };
    head = &op;
    TPCircularBufferProduceBytes(&fifoBuffer, head, sizeof(SequenceOperation));
}

- (void)deleteEvent:(MIDIEvent)event {
    
    uint32_t availableBytes = 0;
    SequenceOperation *head = (SequenceOperation *)TPCircularBufferHead(&fifoBuffer, &availableBytes);
    SequenceOperation op = { Delete, event };
    head = &op;
    TPCircularBufferProduceBytes(&fifoBuffer, head, sizeof(SequenceOperation));
}

#pragma mark - MIDI

- (NSArray<NSString *>*) MIDIOutputNames {
    return @[@"midiOut"];
}

#pragma mark - AUAudioUnit (AUAudioUnitImplementation)

- (AUInternalRenderBlock)internalRenderBlock {
    
    // cache the musical context and MIDI output blocks provided by the host
//    __block TPCircularBuffer buffer = self->_fifoBuffer;
    __block AUHostMusicalContextBlock musicalContextBlock = self.musicalContextBlock;
    __block AUMIDIOutputEventBlock midiOutputBlock = self.MIDIOutputEventBlock;
    
    // get the current sample rate from the output bus
    __block double sampleRate = self.outputBus.format.sampleRate;
    
    return ^AUAudioUnitStatus(AudioUnitRenderActionFlags 				*actionFlags,
                              const AudioTimeStamp       				*timestamp,
                              AVAudioFrameCount           				frameCount,
                              NSInteger                   				outputBusNumber,
                              AudioBufferList            				*outputData,
                              const AURenderEvent        				*realtimeEventListHead,
                              AURenderPullInputBlock __unsafe_unretained pullInputBlock) {
        
        // move MIDI events from FIFO buffer to internal sequencer buffer
        uint32_t bytes = -1;
        while (bytes != 0) {
            SequenceOperation *op = (SequenceOperation *)TPCircularBufferTail(&fifoBuffer, &bytes);
            if (op) {
                switch (op->type) {
                    case Add: {
                        sequence.events[sequence.eventCount] = op->event;
                        sequence.eventCount++;
                        TPCircularBufferConsume(&fifoBuffer, sizeof(SequenceOperation));
                        break;
                    }
                    case Delete: {
                        for (int i = 0; i < sequence.eventCount; i++) {
                            if (sequence.events[i].timestamp == op->event.timestamp) {
                                for (int j = i; j < sequence.eventCount; j++) {
                                    sequence.events[j] = sequence.events[j + 1];
                                }
                                sequence.eventCount--;
                                TPCircularBufferConsume(&fifoBuffer, sizeof(SequenceOperation));
                            }
                        }
                        break;
                    }
                }
            }
        }
        
        // get the tempo and beat position from the musical context provided by the host
        double tempo;
        double beatPosition;
        musicalContextBlock(&tempo, NULL, NULL, &beatPosition, NULL, NULL);
       
        // the length of the sequencer loop in musical time (8.0 == 8 quarter notes)
        double lengthInSamples = sequence.length / tempo * 60. * sampleRate;
        double beatPositionInSamples = beatPosition / tempo * 60. * sampleRate;

        // the sample time at the start of the buffer, as given by the render block,
        // ...modulo the length of the sequencer loop
        double bufferStartTime = fmod(beatPositionInSamples, lengthInSamples);
        double bufferEndTime = bufferStartTime + frameCount;

        for (int i = 0; i < sequence.eventCount; i++) {
            // get the event timestamp, given in musical time (e.g., 1.25)
            MIDIEvent event = sequence.events[i];
            // convert the timestamp to sample time (e.g, 55125)
            double eventTime = event.timestamp / tempo * 60. * sampleRate;
            
            bool eventIsInCurrentBuffer = eventTime >= bufferStartTime && eventTime < bufferEndTime;
            // there is a loop transition in the current buffer
            bool loopsAround = bufferEndTime > lengthInSamples && eventTime < fmod(bufferEndTime, lengthInSamples);
            
            // check if the event should occur within the current buffer OR there is a loop transition
            if (eventIsInCurrentBuffer || loopsAround) {
                // the difference between the sample time of the event
                // and the beginning of the buffer gives us the offset, in samples
                double offset = eventTime - bufferStartTime;
                
                if (loopsAround) {
                    // in case of a loop transitition, add the remaining frames of the current buffer to the offset
                    double remainingFramesInBuffer = lengthInSamples - bufferStartTime;
                    offset = eventTime + remainingFramesInBuffer;
                }
               
                // pass events to the MIDI output block provided by the host
                AUEventSampleTime sampleTime = timestamp->mSampleTime + offset;
                uint8_t cable = 0;
                uint8_t midiData[] = { event.status, event.data1, event.data2 };
                midiOutputBlock(sampleTime, cable, sizeof(midiData), midiData);
            }
        }
       
        return noErr;
    };
}

@end
