//
//  ViewController.swift
//  SequenceGrabber
//
//  Created by 村上幸雄 on 2015/03/01.
//  Copyright (c) 2015年 MURAKAMI Yukio. All rights reserved.
//

import UIKit
import AVFoundation
import AssetsLibrary

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    @IBOutlet weak var previewView: UIView!
    let captureSession = AVCaptureSession();
    let videoAudioDataOutputQueue = dispatch_queue_create("com.example.SequenceGrabber.VideoAudioDataOutputQueue", DISPATCH_QUEUE_SERIAL)
    let writeQueue = dispatch_queue_create("com.example.SequenceGrabber.writeQueue", DISPATCH_QUEUE_SERIAL)
    var frontFacingCameraDeviceInput : AVCaptureDeviceInput? = nil
    var backFacingCameraDeviceInput : AVCaptureDeviceInput? = nil
    var audioDeviceInput : AVCaptureDeviceInput? = nil
    var videoDataOutput = AVCaptureVideoDataOutput()
    var audioDataOutput = AVCaptureAudioDataOutput()
    var assetWriter: AVAssetWriter? = nil
    var videoAssetWriterInput: AVAssetWriterInput? = nil
    var audioAssetWriterInput: AVAssetWriterInput? = nil
    let movieWriteQueue = dispatch_queue_create("MovieWriteQueue", DISPATCH_QUEUE_SERIAL)
    var height: Int = 0
    var width: Int = 0
    var outputFilePath: String? = nil
    
    override func viewDidLoad() {
        println(__FUNCTION__)
        super.viewDidLoad()
        
        /* Session/Deviceの準備 */
        var frontVideoDevice: AVCaptureDevice? = nil
        var backVideoDevice: AVCaptureDevice? = nil
        var audioDevice: AVCaptureDevice? = nil
        captureSession.sessionPreset = AVCaptureSessionPresetLow
        let devices = AVCaptureDevice.devices()
        for device in devices {
            if device.hasMediaType(AVMediaTypeVideo) {
                if device.position == AVCaptureDevicePosition.Back {
                    NSLog("Device position : back")
                    backVideoDevice = device as? AVCaptureDevice
                }
                else {
                    NSLog("Device position : front")
                    frontVideoDevice = device as? AVCaptureDevice
                }
            }
            else if device.hasMediaType(AVMediaTypeAudio) {
                NSLog("Device : audio")
                audioDevice = device as? AVCaptureDevice
            }
        }
        /*
        // デフォルトの例
        let videoDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
        let audioDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeAudio)
        */
        
        var error: NSError? = nil;
        if let device = frontVideoDevice {
            frontFacingCameraDeviceInput = AVCaptureDeviceInput.deviceInputWithDevice(device, error: &error) as? AVCaptureDeviceInput
        }
        if let device = backVideoDevice {
            backFacingCameraDeviceInput = AVCaptureDeviceInput.deviceInputWithDevice(device, error: &error) as? AVCaptureDeviceInput
        }
        if let device = audioDevice {
            audioDeviceInput = AVCaptureDeviceInput.deviceInputWithDevice(device, error: &error) as? AVCaptureDeviceInput
        }

        if let deviceInput = backFacingCameraDeviceInput {
            if captureSession.canAddInput(deviceInput) {
                captureSession.addInput(deviceInput)
            }
        }
        else if let deviceInput = frontFacingCameraDeviceInput {
            if captureSession.canAddInput(deviceInput) {
                captureSession.addInput(deviceInput)
            }
        }
        if let deviceInput = audioDeviceInput {
            if captureSession.canAddInput(deviceInput) {
                captureSession.addInput(deviceInput)
            }
        }
        /*
        // フレームレートを設定する例
        if ([cameraDeviceInput lockForConfiguration:&error]) {
            cameraDeviceInput.activeVideoMaxFrameDuration = CMTimeMake(1, 30)
            cameraDeviceInput.activeVideoMinFrameDuration = CMTimeMake(1, 30)
            [frontVideoDevice unlockForConfiguration];
        }
        */

        /* 録画開始準備（画像も音声も同じデリゲートを設定） */
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey:kCVPixelFormatType_32BGRA]
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.setSampleBufferDelegate(self, queue: videoAudioDataOutputQueue)
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
        }

        audioDataOutput.setSampleBufferDelegate(self, queue: videoAudioDataOutputQueue)
        if captureSession.canAddOutput(audioDataOutput) {
            captureSession.addOutput(audioDataOutput)
        }
        
        width = videoDataOutput.videoSettings["Width"] as! Int
        height = videoDataOutput.videoSettings["Height"] as! Int
        print("\(__FUNCTION__) width:\(width) height:\(height)")
        
        let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
        let documentsDirectory = paths[0] as! String
        outputFilePath = "\(documentsDirectory)/junk.mp4"
        
        /*
        let outputURL = NSURL(fileURLWithPath: "/tmp/demo.mov")
        var outError: NSError? = nil
        assetWriter = AVAssetWriter(URL: outputURL, fileType: AVFileTypeQuickTimeMovie, error: &outError)
        
        let videoOutputSettings: Dictionary<String, AnyObject> = [
            AVVideoCodecKey : AVVideoCodecH264,
            AVVideoWidthKey : width,
            AVVideoHeightKey : height
        ];
        
        let audioOutputSettings: Dictionary<String, AnyObject> = [
            AVFormatIDKey : kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey : channels,
            AVSampleRateKey : samples,
            AVEncoderBitRateKey : 128000
        ]
        
        videoAssetWriterInput = AVAssetWriterInput.assetWriterInputWithMediaType(AVMediaTypeVideo, outputSettings:videoSettings)
        audioAssetWriterInput = AVAssetWriterInput.assetWriterInputWithMediaType(AVMediaTypeAudio, outputSettings:audioSettings)
        
        assetWriter?.addInput(videoAssetWriterInput)
        assetWriter?.addInput(audioAssetWriterInput)
        */
    }
    
    override func viewDidAppear(animated: Bool) {
        println(__FUNCTION__)
        super.viewDidAppear(animated)
        
        /* 動画のプレビューの準備 */
        let captureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspect
        captureVideoPreviewLayer.frame = previewView.bounds
        previewView.layer.addSublayer(captureVideoPreviewLayer)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    @IBAction func touch(sender: AnyObject) {
        println(__FUNCTION__)
        if captureSession.running {
            println("captureSession.stopRunning()")
            captureSession.stopRunning()
            self.assetWriter?.finishWritingWithCompletionHandler({() -> Void in
                self.assetWriter = nil
                let assetsLib = ALAssetsLibrary()
                assetsLib.writeVideoAtPathToSavedPhotosAlbum(NSURL(fileURLWithPath: self.outputFilePath!), completionBlock: {(assetURL: NSURL!, error: NSError!) -> Void in
                })
            })
        }
        else {
            println("captureSession.startRunning()")
            captureSession.startRunning()
        }
    }
    
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        dispatch_sync(writeQueue) {
            if self.assetWriter == nil {
                let fileManager = NSFileManager()
                if fileManager.fileExistsAtPath(self.outputFilePath!) {
                    fileManager.removeItemAtPath(self.outputFilePath!, error: nil)
                }
                
                if captureOutput == self.videoDataOutput {
                }
                else if captureOutput == self.audioDataOutput {
                    let fmt = CMSampleBufferGetFormatDescription(sampleBuffer)
                    let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(fmt)
                    
                    var outError: NSError? = nil
                    let url = NSURL(fileURLWithPath: self.outputFilePath!)
                    self.assetWriter = AVAssetWriter(URL: url, fileType: AVFileTypeQuickTimeMovie, error: &outError)
                    
                    let videoOutputSettings: Dictionary<String, AnyObject> = [
                        AVVideoCodecKey : AVVideoCodecH264,
                        AVVideoWidthKey : self.width,
                        AVVideoHeightKey : self.height
                    ]
                    self.videoAssetWriterInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: videoOutputSettings)
                    self.videoAssetWriterInput!.expectsMediaDataInRealTime = true
                    self.assetWriter!.addInput(self.videoAssetWriterInput)
                    
                    let audioOutputSettings: Dictionary<String, AnyObject> = [
                        AVFormatIDKey : kAudioFormatMPEG4AAC,
                        AVNumberOfChannelsKey : Int(asbd.memory.mChannelsPerFrame),
                        AVSampleRateKey : asbd.memory.mSampleRate,
                        AVEncoderBitRateKey : 128000
                    ]
                    self.audioAssetWriterInput = AVAssetWriterInput(mediaType: AVMediaTypeAudio, outputSettings: audioOutputSettings)
                    self.audioAssetWriterInput!.expectsMediaDataInRealTime = true
                    self.assetWriter!.addInput(self.audioAssetWriterInput)
                }
            }
        }
        
        if CMSampleBufferDataIsReady(sampleBuffer) != 0 {
            if assetWriter != nil {
                if self.assetWriter!.status == AVAssetWriterStatus.Unknown {
                    let startTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                    self.assetWriter!.startWriting()
                    self.assetWriter!.startSessionAtSourceTime(startTime)
                }
                
                if captureOutput == self.videoDataOutput {
                    self.videoAssetWriterInput!.appendSampleBuffer(sampleBuffer)
                }
                else if captureOutput == self.audioDataOutput {
                    self.audioAssetWriterInput!.appendSampleBuffer(sampleBuffer)
                }
            }
        }
        
            
        /*
        let cmTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let value = cmTime.value
        let timescale = cmTime.timescale
        //let seconds = value / timescale
        let epoch = cmTime.epoch
        if captureOutput == videoDataOutput {
            println("\(__FUNCTION__) videoDataOutput value:\(value) timescale:\(timescale) epoch:\(epoch)")
            let fmt = CMSampleBufferGetFormatDescription(sampleBuffer)
            let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(fmt)
            //println("\(__FUNCTION__) channels:\(asbd.memory.mChannelsPerFrame) samples:\(asbd.memory.mSampleRate)")
            //println("\(__FUNCTION__) channels:\(asbd.memory.mChannelsPerFrame)")
            //println("\(__FUNCTION__) samples:\(asbd.memory.mSampleRate)")
            var pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            println("\(__FUNCTION__) pts:\(pts)")
            //dispatch_async(movieWriteQueue, {
            //    if assetWriter?.status == AVAssetWriterStatusWriting {
            //        if videoAssetWriterInput?.readyForMoreMediaData {
            //            videoAssetWriterInput?.appendSampleBuffer(sampleBuffer)
            //        }
            //    }
            //})
        }
        else if captureOutput == audioDataOutput {
            println("\(__FUNCTION__) audioDataOutput value:\(value) timescale:\(timescale) epoch:\(epoch)")
            let fmt = CMSampleBufferGetFormatDescription(sampleBuffer)
            let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(fmt)
            println("\(__FUNCTION__) channels:\(asbd.memory.mChannelsPerFrame) samples:\(asbd.memory.mSampleRate)")
            var pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            println("\(__FUNCTION__) pts:\(pts)")
            //ispatch_async(movieWriteQueue, {
            //    if assetWriter?.status == AVAssetWriterStatusWriting {
            //        if audioAssetWriterInput?.readyForMoreMediaData {
            //            audioAssetWriterInput?.appendSampleBuffer(sampleBuffer)
            //        }
            //    }
            //})
        }
        */
        /*
        assetWriter.startSessionAtSourceTime(<#startTime: CMTime#>)
        */
    }
    
    func captureOutput(captureOutput: AVCaptureOutput!,
        didDropSampleBuffer sampleBuffer: CMSampleBuffer!,
        fromConnection connection: AVCaptureConnection!) {
        let cmTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let value = cmTime.value
        let timescale = cmTime.timescale
        //let seconds = value / timescale
        let epoch = cmTime.epoch
        if captureOutput == videoDataOutput {
            println("\(__FUNCTION__) videoDataOutput value:\(value) timescale:\(timescale) epoch:\(epoch)")
        }
        else if captureOutput == audioDataOutput {
            println("\(__FUNCTION__) audioDataOutput value:\(value) timescale:\(timescale) epoch:\(epoch)")
        }
    }
    
    /*
    func captureOutput(captureOutput: AVCaptureOutput!,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer!,
        fromConnection connection: AVCaptureConnection!) {
    }
    */

}

