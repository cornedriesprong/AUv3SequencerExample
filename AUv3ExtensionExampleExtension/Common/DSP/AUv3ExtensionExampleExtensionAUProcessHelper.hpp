//
//  AUv3ExtensionExampleExtensionAUProcessHelper.hpp
//  AUv3ExtensionExampleExtension
//
//  Created by Corné Driesprong on 31/03/2023.
//

#pragma once

#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

#include <vector>
#include "AUv3ExtensionExampleExtensionDSPKernel.hpp"

//MARK:- AUProcessHelper Utility Class
class AUProcessHelper
{
public:
    AUProcessHelper(AUv3ExtensionExampleExtensionDSPKernel& kernel)
    : mKernel{kernel} {}
    
    /**
     This function handles the event list processing and rendering loop for you.
     Call it inside your internalRenderBlock.
     */
    void processWithEvents(AudioTimeStamp const *timestamp, AUAudioFrameCount frameCount, AURenderEvent const *events) {
        
        AUEventSampleTime now = AUEventSampleTime(timestamp->mSampleTime);
        AUAudioFrameCount framesRemaining = frameCount;
        AURenderEvent const *nextEvent = events; // events is a linked list, at the beginning, the nextEvent is the first event
        
        while (framesRemaining > 0) {
            // If there are no more events, we can process the entire remaining segment and exit.
            if (nextEvent == nullptr) {
                mKernel.process(now, framesRemaining);
                return;
            }
            
            // **** start late events late.
            auto timeZero = AUEventSampleTime(0);
            auto headEventTime = nextEvent->head.eventSampleTime;
            AUAudioFrameCount framesThisSegment = AUAudioFrameCount(std::max(timeZero, headEventTime - now));
            
            // Compute everything before the next event.
            if (framesThisSegment > 0) {
                mKernel.process(now, framesThisSegment);
                
                // Advance frames.
                framesRemaining -= framesThisSegment;
                
                // Advance time.
                now += AUEventSampleTime(framesThisSegment);
            }
            
            nextEvent = performAllSimultaneousEvents(now, nextEvent);
        }
    }
    
    AURenderEvent const * performAllSimultaneousEvents(AUEventSampleTime now, AURenderEvent const *event) {
        do {
            mKernel.handleOneEvent(now, event);
            
            // Go to next event.
            event = event->head.next;
            
            // While event is not null and is simultaneous (or late).
        } while (event && event->head.eventSampleTime <= now);
        return event;
    }
private:
    AUv3ExtensionExampleExtensionDSPKernel& mKernel;
};
