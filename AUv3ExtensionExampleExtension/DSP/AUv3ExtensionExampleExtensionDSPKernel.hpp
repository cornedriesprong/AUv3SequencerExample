//
//  AUv3ExtensionExampleExtensionDSPKernel.hpp
//  AUv3ExtensionExampleExtension
//
//  Created by Corné Driesprong on 31/03/2023.
//

#pragma once

#import <AudioToolbox/AudioToolbox.h>
#import <algorithm>
#import <vector>

#import "AUv3ExtensionExampleExtension-Swift.h"
#import "AUv3ExtensionExampleExtensionParameterAddresses.h"

constexpr uint16_t kMaxVelocity = std::numeric_limits<std::uint16_t>::max();

/*
 AUv3ExtensionExampleExtensionDSPKernel
 As a non-ObjC class, this is safe to use from render thread.
 */
class AUv3ExtensionExampleExtensionDSPKernel {
public:
    void initialize(double inSampleRate) {
        mSampleRate = inSampleRate;
    }
    
    void deInitialize() {
    }
    
    // MARK: - Bypass
    bool isBypassed() {
        return mBypassed;
    }
    
    void setBypass(bool shouldBypass) {
        mBypassed = shouldBypass;
    }
    
    // MARK: - Parameter Getter / Setter
    // Add a case for each parameter in AUv3ExtensionExampleExtensionParameterAddresses.h
    void setParameter(AUParameterAddress address, AUValue value) {
        switch (address) {
            case AUv3ExtensionExampleExtensionParameterAddress::midiNoteNumber:
                mNextNoteToSend = (uint8_t)value;
                break;
            case AUv3ExtensionExampleExtensionParameterAddress::sendNote:
                mShouldSendNoteOn = (bool)value;
                break;
        }
    }
    
    AUValue getParameter(AUParameterAddress address) {
        // Return the goal. It is not thread safe to return the ramping value.
        
        switch (address) {
            case AUv3ExtensionExampleExtensionParameterAddress::midiNoteNumber:
                return (AUValue)mNextNoteToSend;
                
            case AUv3ExtensionExampleExtensionParameterAddress::sendNote:
                return (AUValue)mShouldSendNoteOn;
                
            default: return 0.f;
        }
    }
    
    // MARK: - Maximum Frames To Render
    AUAudioFrameCount maximumFramesToRender() const {
        return mMaxFramesToRender;
    }
    
    void setMaximumFramesToRender(const AUAudioFrameCount &maxFrames) {
        mMaxFramesToRender = maxFrames;
    }
    
    // MARK: - Musical Context
    void setMusicalContextBlock(AUHostMusicalContextBlock contextBlock) {
        mMusicalContextBlock = contextBlock;
    }
    
    // MARK: - MIDI Output
    void setMIDIOutputEventBlock(AUMIDIEventListBlock midiOutBlock) {
        mMIDIOutBlock = midiOutBlock;
    }
    
    // MARK: - MIDI Protocol
    MIDIProtocolID AudioUnitMIDIProtocol() const {
        return kMIDIProtocol_2_0;
    }
    
    /**
     MARK: - Internal Process
     
     This function does the core siginal processing.
     Do your custom MIDI processing here.
     */
    void process(AUEventSampleTime bufferStartTime, AUAudioFrameCount frameCount) {
        
        if (mBypassed) { return; }
        
        // Use this to get Musical context info from the Plugin Host,
        // Replace nullptr with &memberVariable according to the AUHostMusicalContextBlock function signature
        if (mMusicalContextBlock) {
            mMusicalContextBlock(nullptr /* currentTempo */,
                                 nullptr /* timeSignatureNumerator */,
                                 nullptr /* timeSignatureDenominator */,
                                 nullptr /* currentBeatPosition */,
                                 nullptr /* sampleOffsetToNextBeat */,
                                 nullptr /* currentMeasureDownbeatPosition */);
        }
        
        /*
         // If you require sample-accurate sequencing, calculate your midi events based on the frame and buffer offsets
         
         for (int frameIndex = 0; frameIndex < frameCount; ++frameIndex) {
         const int frameOffset = int(frameIndex + frameOffset);
         // Do sample-accurate sequencing here
         }
         */
        
        // Do your midi processing here
        
        if (mShouldSendNoteOn && !mNoteIsCurrentlyOn) {
            // note was not on, but should be - send a new note-on
            sendNoteOn(bufferStartTime, mNextNoteToSend, kMaxVelocity);
            mLastSentNote = mNextNoteToSend;
            mNoteIsCurrentlyOn = true;
            
        } else if (mShouldSendNoteOn && mNoteIsCurrentlyOn && mLastSentNote != mNextNoteToSend) {
            // note was on, but the note number changed - send a note off for the old note, and send a note-on for the new one
            sendNoteOff(bufferStartTime, mLastSentNote, 0);
            sendNoteOn(bufferStartTime, mNextNoteToSend, kMaxVelocity);
            mLastSentNote = mNextNoteToSend;
            
        } else if (!mShouldSendNoteOn && mNoteIsCurrentlyOn) {
            // note was on but should turn off
            sendNoteOff(bufferStartTime, mLastSentNote, 0);
            mNoteIsCurrentlyOn = false;
        }
        
    }
    
    void sendNoteOn(AUEventSampleTime sampleTime, uint8_t noteNum, uint16_t velocity) {
        auto message = MIDI2NoteOn(0, 0, noteNum, 0, 0, velocity);
        MIDIEventList eventList = {};
        MIDIEventPacket *packet = MIDIEventListInit(&eventList, kMIDIProtocol_2_0);
        packet = MIDIEventListAdd(&eventList, sizeof(MIDIEventList), packet, 0, 2, (UInt32 *)&message);
        mMIDIOutBlock(sampleTime, 0, &eventList);
    }
    
    void sendNoteOff(AUEventSampleTime sampleTime, uint8_t noteNum, uint16_t velocity) {
        auto message = MIDI2NoteOff(0, 0, noteNum, 0, 0, velocity);
        MIDIEventList eventList = {};
        MIDIEventPacket *packet = MIDIEventListInit(&eventList, kMIDIProtocol_2_0);
        packet = MIDIEventListAdd(&eventList, sizeof(MIDIEventList), packet, 0, 2, (UInt32 *)&message);
        mMIDIOutBlock(sampleTime, 0, &eventList);
    }
    
    void handleOneEvent(AUEventSampleTime now, AURenderEvent const *event) {
        switch (event->head.eventType) {
            case AURenderEventParameter: {
                handleParameterEvent(now, event->parameter);
                break;
            }
                
            case AURenderEventMIDIEventList: {
                handleMIDIEventList(now, &event->MIDIEventsList);
                break;
            }
                
            default:
                break;
        }
    }

    void handleMIDIEventList(AUEventSampleTime now, AUMIDIEventList const* midiEvent) {
        /*
         // Parse UMP messages
         auto visitor = [] (void* context, MIDITimeStamp timeStamp, MIDIUniversalMessage message) {
         auto thisObject = static_cast<AUv3ExtensionExampleExtensionDSPKernel *>(context);

         switch (message.type) {
         case kMIDIMessageTypeChannelVoice2: {
         }
         break;

         default:
         break;
         }
         };
         MIDIEventListForEachEvent(&midiEvent->eventList, visitor, this);
         */
        if (mMIDIOutBlock)
        {
            mMIDIOutBlock(now, 0, &midiEvent->eventList);
        }
    }
    
    void handleParameterEvent(AUEventSampleTime now, AUParameterEvent const& parameterEvent) {
        // Implement handling incoming Parameter events as needed
    }
    
    // MARK: Member Variables
    AUHostMusicalContextBlock mMusicalContextBlock;
    
    double mSampleRate = 44100.0;
    bool mBypassed = false;
    AUAudioFrameCount mMaxFramesToRender = 1024;
    
    bool mShouldSendNoteOn = false;  //  Should we send a note-on next process?
    bool mNoteIsCurrentlyOn = false;  //  Have we sent a note-on without a matching note off?
    uint8_t mLastSentNote = 255;
    uint8_t mNextNoteToSend = 255;
    AUMIDIEventListBlock mMIDIOutBlock;
};
