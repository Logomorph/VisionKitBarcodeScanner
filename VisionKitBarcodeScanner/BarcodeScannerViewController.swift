//
//  BarcodeScannerViewController.swift
//  VisionKitBarcodeScanner
//
//  Created by Alin Baciu on 05/11/2018.
//  Copyright © 2018 Alin Baciu. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

protocol BarcodeScannerDelegate : class {
    func barcodeScanner(_ scanner:BarcodeScannerViewController, read code:String)
    func barcodeScannerCancelled(_ scanner:BarcodeScannerViewController)
    func barcodeScannerFailed(_ scanner:BarcodeScannerViewController)
}

class BarcodeScannerViewController: UIViewController {
    var videoSession: AVCaptureSession?
    var videoLayer: AVCaptureVideoPreviewLayer?
    weak var delegate: BarcodeScannerDelegate?
    
    var currentTime:Double = 0
    var lastTime:Double = 0
    var shouldInvert = false
    
    init(delegate:BarcodeScannerDelegate?) {
        self.delegate = delegate
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let videoDevice = AVCaptureDevice.default(for: AVMediaType.video),
            let input = try? AVCaptureDeviceInput(device: videoDevice),
            self.createSession(input: input) else {
                self.delegate?.barcodeScannerFailed(self)
                return
        }
        self.createLayer()
        self.setupNavigation()
        self.createInvertButton()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let session = self.videoSession, !session.isRunning {
            session.startRunning()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let session = self.videoSession, !session.isRunning {
            session.stopRunning()
        }
    }
    
    fileprivate func createSession(input:AVCaptureDeviceInput) -> Bool {
        let session = AVCaptureSession()
        
        if session.canAddInput(input) {
            session.addInput(input)
        } else {
            return false
        }
        
        let output = AVCaptureVideoDataOutput()
        if session.canAddOutput(output) {
            output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "awk.output"))
            output.videoSettings = [String(kCVPixelBufferPixelFormatTypeKey):kCVPixelFormatType_32BGRA]
            output.alwaysDiscardsLateVideoFrames = true
            session.addOutput(output)
        }
        self.videoSession = session
        return true
    }
    
    fileprivate func createLayer() {
        if let s = self.videoSession {
            let layer = AVCaptureVideoPreviewLayer(session: s)
            layer.frame = self.view.layer.bounds
            layer.videoGravity = AVLayerVideoGravity.resizeAspectFill
            self.view.layer.addSublayer(layer)
            self.videoLayer = layer
        }
    }
    
    fileprivate func createInvertButton() {
        let toggleSwitch = UISwitch(frame: CGRect.zero)
        toggleSwitch.addTarget(self, action: #selector(self.invertTapped(sender:)), for: UIControl.Event.touchUpInside)
        toggleSwitch.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(toggleSwitch)
        
        
        let views: [String: UIView] = ["toggleSwitch": toggleSwitch]
        
        self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:[toggleSwitch]-(10)-|", options: NSLayoutConstraint.FormatOptions(rawValue: 0), metrics: nil, views: views))
        self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:[toggleSwitch]-(50)-|", options: NSLayoutConstraint.FormatOptions(rawValue: 0), metrics: nil, views: views))
    }
    
    fileprivate func setupNavigation() {
        let cancelButton = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(self.cancelPressed))
        self.navigationItem.leftBarButtonItem = cancelButton
    }
    
    @objc fileprivate func invertTapped(sender:UISwitch) {
        self.shouldInvert = sender.isOn
    }
    
    @objc fileprivate func cancelPressed() {
        delegate?.barcodeScannerCancelled(self)
    }
}

extension BarcodeScannerViewController:AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let threshold:Double = 1.0 / 3
        let timeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        currentTime = Double(timeStamp.value) / Double(timeStamp.timescale)
        if (currentTime - lastTime > threshold) {
            if let image = imageFromSampleBuffer(sampleBuffer: sampleBuffer),
                let cgImage = image.cgImage {
                scanBarcode(cgImage: cgImage)
            }
        }
    }
    
    // https://stackoverflow.com/questions/15726761/make-an-uiimage-from-a-cmsamplebuffer/26960457
    fileprivate func imageFromSampleBuffer(sampleBuffer : CMSampleBuffer) -> UIImage? {
        guard let imgBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }
        // Lock the base address of the pixel buffer
        CVPixelBufferLockBaseAddress(imgBuffer, CVPixelBufferLockFlags.readOnly)
        
        
        // Get the number of bytes per row for the pixel buffer
        let baseAddress = CVPixelBufferGetBaseAddress(imgBuffer)
        
        // Get the number of bytes per row for the pixel buffer
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imgBuffer)
        // Get the pixel buffer width and height
        let width = CVPixelBufferGetWidth(imgBuffer)
        let height = CVPixelBufferGetHeight(imgBuffer)
        
        // Create a device-dependent RGB color space
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        // Create a bitmap graphics context with the sample buffer data
        var bitmapInfo: UInt32 = CGBitmapInfo.byteOrder32Little.rawValue
        bitmapInfo |= CGImageAlphaInfo.premultipliedFirst.rawValue & CGBitmapInfo.alphaInfoMask.rawValue
        //let bitmapInfo: UInt32 = CGBitmapInfo.alphaInfoMask.rawValue
        let context = CGContext.init(data: baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo)
        // Create a Quartz image from the pixel data in the bitmap graphics context
        let quartzImage = context?.makeImage()
        // Unlock the pixel buffer
        CVPixelBufferUnlockBaseAddress(imgBuffer, CVPixelBufferLockFlags.readOnly)
        
        CVPixelBufferLockBaseAddress(imgBuffer, .readOnly)
        
        if var image = quartzImage {
            if shouldInvert, let inverted = invertImage(image) {
                image = inverted
            }
            let output = UIImage(cgImage: image)
            return output
        }
        return nil
    }
    
    fileprivate func invertImage(_ image:CGImage) -> CGImage? {
        if let filter = CIFilter(name: "CIColorInvert") {
            let ctx = CIContext(options: nil)
            let beginImage = CIImage(cgImage: image)
            filter.setValue(beginImage, forKey: kCIInputImageKey)
            if let output = filter.outputImage {
                if let cgimg = ctx.createCGImage(output, from: output.extent) {
                    return cgimg
                }
            }
        }
        return nil
    }
    
    fileprivate func scanBarcode(cgImage: CGImage) {
        let barcodeRequest = VNDetectBarcodesRequest(completionHandler: { request, _ in
            self.parseResults(results: request.results)
        })
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [.properties : ""])
        guard let _ = try? handler.perform([barcodeRequest]) else {
            return print("Could not scan")
        }
    }
    
    fileprivate func parseResults(results: [Any]?) {
        guard let results = results else {
            return print("No results")
        }
        for result in results {
            if let barcode = result as? VNBarcodeObservation {
                DispatchQueue.main.async {
                    self.videoSession?.stopRunning()
                    if let code = barcode.payloadStringValue {
                        self.delegate?.barcodeScanner(self, read: code)
                    } else {
                        self.delegate?.barcodeScannerFailed(self)
                    }
                }
            }
        }
    }
}
