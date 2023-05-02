//
//  AUv3ExtensionExampleExtensionAudioUnit.mm
//  AUv3ExtensionExampleExtension
//
//  Created by Corné Driesprong on 31/03/2023.
//

#import "AUv3ExtensionExampleExtensionAudioUnit.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreAudioKit/AUViewController.h>
#import <CoreMIDI/CoreMIDI.h>

@interface AUv3ExtensionExampleExtensionAudioUnit ()

@property (nonatomic, readwrite) AUParameterTree *parameterTree;
@property AUAudioUnitBusArray *inputBusArray;
@property AUAudioUnitBusArray *outputBusArray;
@property (nonatomic, readonly) AUAudioUnitBus *outputBus;
@end

@implementation AUv3ExtensionExampleExtensionAudioUnit

@synthesize parameterTree = _parameterTree;

- (instancetype)initWithComponentDescription:(AudioComponentDescription)componentDescription options:(AudioComponentInstantiationOptions)options error:(NSError **)outError {
    self = [super initWithComponentDescription:componentDescription options:options error:outError];
    
    if (self == nil) { return nil; }
    
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

#pragma mark - MIDI

- (NSArray<NSString *>*) MIDIOutputNames {
    return @[@"midiOut"];
}

#pragma mark - AUAudioUnit (AUAudioUnitImplementation)

- (AUInternalRenderBlock)internalRenderBlock {
    
    // cache the musical context and MIDI output blocks provided by the host
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
        
        // get the events from the sequencer buffer
        MIDISequence sequence;
        sequence.length = 2.;
       
        for (int i = 0; i < 8; i++) {
            MIDIEvent ev;
            ev.timestamp = (double)i * 0.25;
            ev.status = NOTE_ON;
            ev.data1 = 60;      // pitch
            ev.data2 = 110;     // velocity
            sequence.events[i] = ev;
        }
        
        sequence.eventCount = 8;
        
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
