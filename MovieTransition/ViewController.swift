//
//  ViewController.swift
//  MovieTransition
//
//  Created by yyjim on 2019/10/20.
//  Copyright © 2019 Cardinalblue. All rights reserved.
//

import UIKit
import AVFoundation
import AVKit

class ViewController: UIViewController {

    @IBOutlet var activityIndicator: UIActivityIndicatorView!

    // Set the transition duration time to 3 seconds.
    private let TRANSITION_DURATION = CMTimeMake(value: 3, timescale: 1)
    private var exporter: AVAssetExportSession?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func btnDoItTapped(sender: UIButton) {
        // Make sure that all the videos have the same frame rate and its better if they have the same resolution too
        let video1 = AVAsset(url: URL.init(fileURLWithPath: Bundle.main.path(forResource: "sample_video_1", ofType: "mp4")!))
        let video2 = AVAsset(url: URL.init(fileURLWithPath: Bundle.main.path(forResource: "sample_video_2", ofType: "mp4")!))
//        let video3 = AVAsset.init(url: URL.init(fileURLWithPath: Bundle.main.path(forResource: "sample_video_3", ofType: "mp4")!))
//        let video4 = AVAsset.init(url: URL.init(fileURLWithPath: Bundle.main.path(forResource: "sample_video_4", ofType: "mp4")!))
        let movieAssets: [AVAsset] = [video1, video2] //, video3, video4]

        // Create the mutable composition that we are going to build up.
        let composition = AVMutableComposition()

        buildCompositionTracks(composition: composition, videos: movieAssets)

        // Create the instructions for which movie to show and create the video composition.
        let videoComposition = buildVideoCompositionAndInstructions(composition: composition, assets: movieAssets)

        self.exporter = AVAssetExportSession(asset: composition,
                                             presetName: AVAssetExportPresetHighestQuality)

        let outputURL = makeOutputURL(ext: "mp4")
        exporter?.outputURL = outputURL
        exporter?.videoComposition = videoComposition
        exporter?.outputFileType = AVFileType.mp4
        exporter?.shouldOptimizeForNetworkUse = true

        self.activityIndicator.startAnimating()
        exporter?.exportAsynchronously {
            DispatchQueue.main.async {
                self.activityIndicator.stopAnimating()
                self.didFinishMerging(url: outputURL)
            }
        }
    }

    private func didFinishMerging(url: URL?) {
        if let video = url {
            let player = AVPlayer(url: video)
            let vcPlayer = AVPlayerViewController()
            vcPlayer.player = player
            self.present(vcPlayer, animated: true, completion: nil)
        }
    }

    private func makeOutputURL(ext: String) -> URL? {
        guard let documentDirectory = FileManager.default.urls(for: .documentDirectory,
                                                               in: .userDomainMask).first else {
                                                                return nil
        }
        return documentDirectory.appendingPathComponent("mergeVideo-\(Date.timeIntervalSinceReferenceDate).\(ext)")
    }

    // Function to build the composition tracks.
    private func buildCompositionTracks(composition: AVMutableComposition,
        videos: [AVAsset]) -> Void {
        let videoTrackA = composition.addMutableTrack(
            withMediaType: AVMediaType.video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )
        let videoTrackB = composition.addMutableTrack(
            withMediaType: AVMediaType.video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )
        let videoTracks = [videoTrackA, videoTrackB]

        var audioTrackA: AVMutableCompositionTrack?
        var audioTrackB: AVMutableCompositionTrack?

        var cursorTime = CMTime.zero

        var index = 0
        videos.forEach { (asset) in
            do {
                let trackIndex = index % 2
                let currentVideoTrack = videoTracks[trackIndex]

                if TRANSITION_DURATION <= asset.duration {
                    let timeRange = CMTimeRangeMake(start: CMTime.zero, duration: asset.duration)
                    try currentVideoTrack?.insertTimeRange(
                        timeRange,
                        of: asset.tracks(withMediaType: AVMediaType.video)[0],
                        at: cursorTime
                    )
                    if let audioAssetTrack = asset.tracks(withMediaType: AVMediaType.audio).first {
                        var currentAudioTrack: AVMutableCompositionTrack?
                        switch trackIndex {
                        case 0:
                            if audioTrackA == nil {
                                audioTrackA = composition.addMutableTrack(
                                    withMediaType: AVMediaType.audio,
                                    preferredTrackID: kCMPersistentTrackID_Invalid
                                )
                            }
                            currentAudioTrack = audioTrackA
                        case 1:
                            if audioTrackB == nil {
                                audioTrackB = composition.addMutableTrack(
                                    withMediaType: AVMediaType.audio,
                                    preferredTrackID: kCMPersistentTrackID_Invalid
                                )
                            }
                            currentAudioTrack = audioTrackB
                        default:
                            print("MovieTransitionsVC " + #function + ": Only two audio tracks were expected")
                        }
                        try currentAudioTrack?.insertTimeRange(
                            CMTimeRangeMake(start: CMTime.zero, duration: asset.duration),
                            of: audioAssetTrack,
                            at: cursorTime
                        )
                    }
                    // Overlap clips by tranition duration
                    cursorTime = CMTimeAdd(cursorTime, asset.duration)
                    cursorTime = CMTimeSubtract(cursorTime, TRANSITION_DURATION)
                }
            } catch {
                // Could not add track
                print("MovieTransitionsVC " + #function + ": " + error.localizedDescription)
            }
            index += 1
        }
    }

    // Function to calculate both the pass through time and the transition time ranges
    private func calculateTimeRanges(assets: [AVAsset])
        -> (passThroughTimeRanges: [NSValue], transitionTimeRanges: [NSValue]) {

            var passThroughTimeRanges:[NSValue] = [NSValue]()
            var transitionTimeRanges:[NSValue] = [NSValue]()
            var cursorTime = CMTime.zero

            for i in 0...(assets.count - 1) {
                let asset = assets[i]
                if TRANSITION_DURATION <= asset.duration {
                    var timeRange = CMTimeRangeMake(start: cursorTime, duration: asset.duration)

                    if i > 0 {
                        timeRange.start = CMTimeAdd(timeRange.start, TRANSITION_DURATION)
                        timeRange.duration = CMTimeSubtract(timeRange.duration, TRANSITION_DURATION)
                    }

                    if i + 1 < assets.count {
                        timeRange.duration = CMTimeSubtract(timeRange.duration, TRANSITION_DURATION)
                    }

                    passThroughTimeRanges.append(NSValue.init(timeRange: timeRange))

                    cursorTime = CMTimeAdd(cursorTime, asset.duration)
                    cursorTime = CMTimeSubtract(cursorTime, TRANSITION_DURATION)

                    if i + 1 < assets.count {
                        timeRange = CMTimeRangeMake(start: cursorTime, duration: TRANSITION_DURATION)
                        transitionTimeRanges.append(NSValue.init(timeRange: timeRange))
                    }
                }
            }
            return (passThroughTimeRanges, transitionTimeRanges)
    }

    // Build the video composition and instructions.
    private func buildVideoCompositionAndInstructions(
        composition: AVMutableComposition, assets: [AVAsset]) -> AVMutableVideoComposition {

        // Create the passthrough and transition time ranges.
        let timeRanges = calculateTimeRanges(assets: assets)

        // Create a mutable composition instructions object
        var compositionInstructions = [AVMutableVideoCompositionInstruction]()

        // Get the list of asset tracks and tell compiler they are a list of asset tracks.
        let tracks = composition.tracks(withMediaType: AVMediaType.video) as [AVAssetTrack]

        // Create a video composition object
        let videoComposition = AVMutableVideoComposition(propertiesOf: composition)

        for i in 0...(timeRanges.passThroughTimeRanges.count - 1) {
            let trackIndex = i % 2
            let currentTrack = tracks[trackIndex]

            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = timeRanges.passThroughTimeRanges[i].timeRangeValue

            let layerInstruction = AVMutableVideoCompositionLayerInstruction(
                assetTrack: currentTrack)
            instruction.layerInstructions = [layerInstruction]

            compositionInstructions.append(instruction)

            if i < timeRanges.transitionTimeRanges.count {

                let instruction = AVMutableVideoCompositionInstruction()
                instruction.timeRange = timeRanges.transitionTimeRanges[i].timeRangeValue

                // Determine the foreground and background tracks.
                let fgTrack = tracks[trackIndex]
                let bgTrack = tracks[1 - trackIndex]

                // Create the "from layer" instruction.
                let fLInstruction = AVMutableVideoCompositionLayerInstruction(
                    assetTrack: fgTrack)

                // Make the opacity ramp and apply it to the from layer instruction.
                fLInstruction.setOpacityRamp(fromStartOpacity: 1.0, toEndOpacity:0.0,
                                             timeRange: instruction.timeRange)

                let tLInstruction = AVMutableVideoCompositionLayerInstruction(
                    assetTrack: bgTrack)

                instruction.layerInstructions = [fLInstruction, tLInstruction]
                compositionInstructions.append(instruction)
            }
        }
        videoComposition.instructions = compositionInstructions
        return videoComposition
    }
}
