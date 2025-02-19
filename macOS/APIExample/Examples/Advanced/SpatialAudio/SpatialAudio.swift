//
//  SpatialAudio.swift
//  APIExample
//
//  Created by Arlin on 2022/3/23.
//  Copyright © 2022 Agora Corp. All rights reserved.
//

import Foundation
import AgoraRtcKit

class SpatialAudioMain: BaseViewController {
    @IBOutlet weak var infoLabel: NSTextField!
    @IBOutlet weak var startButton: NSButton!
    @IBOutlet weak var peopleView: NSImageView!
    @IBOutlet weak var soundSourceView: NSImageView!
    
    var agoraKit: AgoraRtcEngineKit!
    var remoteUid: UInt = 0
    var currentAngle = 0.0
    var currentDistance = 0.0
    var downCount = 0
    var downTimer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupUI()
        
        agoraKit = AgoraRtcEngineKit.sharedEngine(withAppId: KeyCenter.AppId, delegate: self)
        agoraKit.setChannelProfile(.liveBroadcasting)
        agoraKit.setClientRole(.broadcaster)
        agoraKit.setAudioProfile(.default, scenario: .gameStreaming)
    }
    
    override func viewWillBeRemovedFromSplitView() {
        downTimer?.invalidate()
        downTimer = nil
        AgoraRtcEngineKit.destroy()
    }

    func setupUI() {
        infoLabel.stringValue = "Please insert headphones to experience the spatial audio effect".localized
        startButton.title = "Start".localized
        
        let panGesture = NSPanGestureRecognizer(target: self, action: #selector(panGestureChanged))
        self.soundSourceView.addGestureRecognizer(panGesture)
    }
    
    
    @IBAction func startBtnClicked(_ sender: Any) {
        guard let filePath = Bundle.main.path(forResource: "audiomixing", ofType: "mp3") else {return}
        let timeout = 10
        agoraKit.startEchoTest(withInterval: timeout)
        agoraKit.startAudioMixing(filePath, loopback: false, replace: true, cycle: 1, startPos: 0)
        
        startButton.isHidden = true
        downCount  = timeout * 2
        downTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            self.downCount -= 1
            if self.downCount >= timeout {
                if self.downCount == timeout {
                    self.agoraKit.enableSpatialAudio(true)
                    self.agoraKit.stopAudioMixing()
                    self.peopleView.isHidden = false
                    self.soundSourceView.isHidden = false
                } else {
                    let text = "You will hear a piece of music, and after 10 seconds this piece of music will be played through spatial audio effects".localized
                    self.infoLabel.stringValue = "\(text)(\(self.downCount - timeout))"
                }
            } else {
                let text = "Now you can move the speaker icon to experience the spatial audio effect".localized
                self.infoLabel.stringValue = "\(text)(\(self.downCount))"
                if self.downCount == 0 {
                    self.agoraKit.stopEchoTest()
                    self.agoraKit.enableSpatialAudio(false)
                    self.downTimer?.invalidate()
                    self.downTimer = nil
                    self.peopleView.isHidden = true
                    self.soundSourceView.isHidden = true
                    self.startButton.isHidden = false
                    self.infoLabel.stringValue = "Please insert headphones to experience the spatial audio effect".localized
                }
            }
        }
    }
    
    @objc func panGestureChanged(gesture: NSPanGestureRecognizer) {
        let move = gesture.translation(in: self.view)
        var objectCenter = CGPoint(x: NSMidX(gesture.view!.frame), y: NSMidY(gesture.view!.frame))
        objectCenter = CGPoint(x: objectCenter.x + move.x, y: objectCenter.y + move.y)
        
        let width = soundSourceView.frame.size.width
        soundSourceView.frame = CGRect(origin: CGPoint(x: objectCenter.x - width / 2.0, y: objectCenter.y - width / 2.0), size: CGSize(width: width, height: width))
        gesture.setTranslation(.zero, in: self.view)
  
        if gesture.state == .ended {
            updatePosition(objectCenter: objectCenter)
        }
    }
    
    func updatePosition(objectCenter: CGPoint) {
        let circleCenter = CGPoint(x: NSMidX(peopleView.frame), y: NSMidY(peopleView.frame))
        let deltaX = objectCenter.x - circleCenter.x
        let deltaY = objectCenter.y - circleCenter.y
        let R = sqrt(deltaX * deltaX + deltaY * deltaY)
        
        // In spatial audio, angle is range [0, 360],  it is angle 0 when at Y direction with anti-clockwise
        let TwoPI = Double.pi * 2.0
        let cosAngle = acos(deltaX / R)
        let mathAngle = deltaY > 0 ? cosAngle : (TwoPI - cosAngle)
        var spatialAngle = mathAngle - TwoPI / 4.0
        if spatialAngle < 0 {
            spatialAngle = TwoPI + spatialAngle
        }

        currentAngle = spatialAngle
        currentDistance = R
        self.updateRemoteUserSpatialAudioPositon()
    }

    func updateRemoteUserSpatialAudioPositon() {
        let maxR = self.view.frame.height / 2.0
        
        let maxSpatailDistance = 30.0
        let spatialDistance = currentDistance * maxSpatailDistance / maxR
        let spatialAngle = currentAngle * 180.0 / Double.pi
        
        let spatialParams = AgoraSpatialAudioParams()
        spatialParams.speaker_azimuth = .of(spatialAngle)
        spatialParams.speaker_distance = .of(spatialDistance)
        spatialParams.speaker_elevation = .of(0)
        spatialParams.enable_blur = .of(false)
        spatialParams.enable_air_absorb = .of(true)
        agoraKit.setRemoteUserSpatialAudioParams(remoteUid, param: spatialParams)
    }
}

extension SpatialAudioMain: AgoraRtcEngineDelegate {
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        print("didJoinedOfUid:\(uid)")
        remoteUid = uid
        self.updateRemoteUserSpatialAudioPositon()
    }
}

