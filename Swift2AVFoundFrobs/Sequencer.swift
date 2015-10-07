//
//  Sequencer.swift
//  Swift2AVFoundFrobs
//
//  Created by Gene De Lisa on 6/10/15.
//  Copyright © 2015 Gene De Lisa. All rights reserved.
//

import Foundation
import AVFoundation

/**
# Using the new AVAudioSequencer class.

The new `AVAudioSequencer` seems to be broken.

Seems to be fixed in beta4.

See blog post by [following this link.](http://rockhoppertech.com/blog/)
*/

class Sequencer {
    
    // This is the MuseCore soundfont. Change it to the one you have.
    let soundFontMuseCoreName = "GeneralUser GS MuseScore v1.442"
    
    var engine = AVAudioEngine()
    var sampler = AVAudioUnitSampler()
    var sequencer:AVAudioSequencer!
    let melodicBank = UInt8(kAUSampler_DefaultMelodicBankMSB)
    let defaultBank = UInt8(kAUSampler_DefaultBankLSB)
    
    
    init() {
        setSessionPlayback()
        
        //(self.engine, self.sampler) = engineSetup()
        
        // set up the engine
        
        engine.attachNode(sampler)
        let outputHWFormat = engine.outputNode.outputFormatForBus(0)
        let mainMixer = engine.mainMixerNode
        engine.connect(sampler, to: mainMixer, format: outputHWFormat)
        print(engine)
        
        loadSF2PresetIntoSampler(0)
        
        addObservers()
        
        engineStart()
        
        // finished setting up engine
        
        self.sequencer = AVAudioSequencer(audioEngine: self.engine)
        
        guard let fileURL = NSBundle.mainBundle().URLForResource("sibeliusGMajor", withExtension: "mid") else {
            fatalError("\"sibeliusGMajor.mid\" file not found.")
        }
        
        do {
            try sequencer.loadFromURL(fileURL, options: .SMF_PreserveTracks)
            print("loaded \(fileURL)")
        } catch {
            print("\(error)")
            fatalError("something screwed up while loading midi file.")
        }
        // yeah? So what do we do with it? Can't add anything. Can't inspect anything.
        
        
        let tempo = sequencer.tempoTrack
        print("tempo lengthInBeats \(tempo.lengthInBeats)")
        print("tempo timeResolution \(tempo.timeResolution)")

        
        for track in sequencer.tracks {
            // the tempo track is not included in sequencer.tracks
            if track == sequencer.tempoTrack {
                print("tempo track")
            }
            
            // setting the destinations crashes if the sequence has already been started
            track.destinationAudioUnit = self.sampler
            print("track destinationAudioUnit \(track.destinationAudioUnit)")
            // or
            //print("track destinationMIDIEndpoint \(track.destinationMIDIEndpoint)")
            print("track loopRange \(track.loopRange)")
            print("track loopingEnabled \(track.loopingEnabled)")
            print("track numberOfLoops \(track.numberOfLoops)")
            print("track offsetTime \(track.offsetTime)")
            print("track muted \(track.muted)")
            
            print("track soloed \(track.soloed)")
            print("track lengthInBeats \(track.lengthInBeats)")
            print("track lengthInSeconds \(track.lengthInSeconds)")
            print("")
            
            // If loopRange has not been set, the full track will be looped.
            // track.loopRange = AVBeatRange(start: 0,length: 10)

            
            // this crashes. do it on the tempo track
            //print("track timeResolution \(track.timeResolution)")
        }
        
        sequencer.prepareToPlay()
        
        print(sequencer)
        
        //play()
       
    }
    
    func play() {
        if sequencer.playing {
            sequencer.stop()
        }
        
        sequencer.currentPositionInBeats = NSTimeInterval(0)
        sequencer.prepareToPlay()

        do {
            try sequencer.start()
        } catch {
            print("cannot start sequencer")
            print("\(error)")
        }

    }
    
    
    func engineSetup()-> (AVAudioEngine, AVAudioUnitSampler) {
        
        let engine = AVAudioEngine()

        let output = engine.outputNode
        let outputHWFormat = output.outputFormatForBus(0)

        let mainMixer = engine.mainMixerNode
        engine.connect(mainMixer, to: output, format: outputHWFormat)
        
        let sampler = AVAudioUnitSampler()
        engine.attachNode(sampler)
        
        engine.connect(sampler, to: mainMixer, format: outputHWFormat)
//        engine.connect(sampler, to: output, format: outputHWFormat)
//        engine.connect(sampler, to: output, format: nil)
//        engine.connect(sampler, to: mainMixer, format: nil)

        
        print(engine)
        
        return (engine, sampler)
    }
    
    
    func bounceEngine() {
        
        if self.engine.running {
            self.engine.stop()
        } else {
            engineStart()
        }
        
    }
    
    func engineStart() {
        do {
            try engine.start()
        } catch {
            print("error couldn't start engine")
            print("\(error)")
        }
    }
    
    //MARK: - Notifications
    
    func addObservers() {
        NSNotificationCenter.defaultCenter().addObserver(self,
            selector:"engineConfigurationChange:",
            name:AVAudioEngineConfigurationChangeNotification,
            object:engine)
        
        NSNotificationCenter.defaultCenter().addObserver(self,
            selector:"sessionInterrupted:",
            name:AVAudioSessionInterruptionNotification,
            object:engine)
        
        NSNotificationCenter.defaultCenter().addObserver(self,
            selector:"sessionRouteChange:",
            name:AVAudioSessionRouteChangeNotification,
            object:engine)
    }
    
    func removeObservers() {
        NSNotificationCenter.defaultCenter().removeObserver(self,
            name: AVAudioEngineConfigurationChangeNotification,
            object: nil)
        
        NSNotificationCenter.defaultCenter().removeObserver(self,
            name: AVAudioSessionInterruptionNotification,
            object: nil)
        
        NSNotificationCenter.defaultCenter().removeObserver(self,
            name: AVAudioSessionRouteChangeNotification,
            object: nil)
    }
    
    
    func playNoteOn(channel:UInt8, noteNum:UInt8, velocity:UInt8)    {
        let noteCommand = UInt8(0x90 | channel)
        self.sampler.sendMIDIEvent(noteCommand, data1: noteNum, data2: velocity)
    }
    
    func playNoteOff(channel:UInt8, noteNum:UInt8)    {
        let noteCommand = UInt8(0x80 | channel)
        self.sampler.sendMIDIEvent(noteCommand, data1: noteNum, data2: 0)
    }
   

    func loadSF2PresetIntoSampler(preset:UInt8)  {
        
        guard let bankURL = NSBundle.mainBundle().URLForResource(self.soundFontMuseCoreName, withExtension: "sf2") else {
            fatalError("\(self.soundFontMuseCoreName).sf2 file not found.")
        }
        
        do {
            try
                self.sampler.loadSoundBankInstrumentAtURL(bankURL,
                    program: preset,
                    bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                    bankLSB: UInt8(kAUSampler_DefaultBankLSB))
            
            print("loaded soundfont \(bankURL)")

            // this uses an aupreset file. sampler.loadInstrumentAtURL(<#T##instrumentURL: NSURL##NSURL#>)
            
        } catch {
            print("error loading sound bank instrument")
            print(error)
        }
    }
    
    
    
    //MARK: - Audio Session
    
    func setSessionPlayAndRecord() {
        let session:AVAudioSession = AVAudioSession.sharedInstance()
        
        do {
            try session.setCategory(AVAudioSessionCategoryPlayAndRecord)
        } catch {
            print("could not set session category")
            print(error)
        }
        do {
            try session.setActive(true)
        } catch {
            print("could not make session active")
            print(error)
        }
        
    }
    
    func setSessionPlayback() {
        let session:AVAudioSession = AVAudioSession.sharedInstance()
        
        do {
            try session.setCategory(AVAudioSessionCategoryPlayback)
        } catch {
            print("could not set session category")
            print(error)
        }
        do {
            try session.setActive(true)
        } catch {
            print("could not make session active")
            print(error)
        }
    }
    
    // MARK: - notification callbacks
    
    @objc func engineConfigurationChange(notification:NSNotification) {
        print("engine config change")
        engineStart()
        
        //userInfo is nil
        
        //        print("userInfo")
        //        print(notification.userInfo)
        
        if let userInfo = notification.userInfo as? Dictionary<String,AnyObject!> {
            print("userInfo")
            print(userInfo)
        }
    }
    
    
    
    func sessionInterrupted(notification:NSNotification) {
        print("audio session interrupted")
        if let engine = notification.object as? AVAudioEngine {
            engine.stop()
        }
        
        if let userInfo = notification.userInfo as? Dictionary<String,AnyObject!> {
            let reason = userInfo[AVAudioSessionInterruptionTypeKey] as! AVAudioSessionInterruptionType
            switch reason {
            case .Began:
                print("began")
            case .Ended:
                print("ended")
            }
        }
        
    }
    
    func sessionRouteChange(notification:NSNotification) {
        print("audio session route change \(notification)")
        
        if let userInfo = notification.userInfo as? Dictionary<String,AnyObject!> {
            
            if let reason = userInfo[AVAudioSessionRouteChangeReasonKey] as? AVAudioSessionRouteChangeReason {
                
                print("audio session route change reason \(reason)")
                
                switch reason {
                case .CategoryChange: print("CategoryChange")
                case .NewDeviceAvailable:print("NewDeviceAvailable")
                case .NoSuitableRouteForCategory:print("NoSuitableRouteForCategory")
                case .OldDeviceUnavailable:print("OldDeviceUnavailable")
                case .Override: print("Override")
                case .WakeFromSleep:print("WakeFromSleep")
                case .Unknown:print("Unknown")
                case .RouteConfigurationChange:print("RouteConfigurationChange")
                }
            }
            
            let previous = userInfo[AVAudioSessionRouteChangePreviousRouteKey]
            print("audio session route change previous \(previous)")
        }
        
        
        if let engine = notification.object as? AVAudioEngine {
            engine.stop()
        }
    }
    
}