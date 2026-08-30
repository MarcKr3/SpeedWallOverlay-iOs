import AVFoundation
import UIKit
import SwiftUI
import Combine
import CoreImage

/// Manages the camera session and preview
class CameraManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    // MARK: - Published Properties

    @Published var isSessionRunning = false
    @Published var error: CameraError?

    // MARK: - Properties

    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private var videoDeviceInput: AVCaptureDeviceInput?

    // MARK: - Video Frame Capture

    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let videoDataQueue = DispatchQueue(label: "camera.videodata.queue")
    private let ciContext = CIContext()
    private let frameLock = NSLock()
    private var _latestPixelBuffer: CVPixelBuffer?

    /// The most recent camera frame as a CGImage (thread-safe).
    /// Conversion happens here, on demand — not per captured frame.
    var latestFrame: CGImage? {
        frameLock.lock()
        let pixelBuffer = _latestPixelBuffer
        frameLock.unlock()
        guard let pixelBuffer = pixelBuffer else { return nil }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        return ciContext.createCGImage(ciImage, from: ciImage.extent)
    }
    
    // MARK: - Error Types
    
    enum CameraError: Error, LocalizedError {
        case cameraUnavailable
        case cannotAddInput
        case cannotAddOutput
        case permissionDenied
        case unknown
        
        var errorDescription: String? {
            switch self {
            case .cameraUnavailable:
                return NSLocalizedString("Camera is not available on this device", comment: "Camera error: unavailable")
            case .cannotAddInput:
                return NSLocalizedString("Cannot access camera input", comment: "Camera error: input")
            case .cannotAddOutput:
                return NSLocalizedString("Cannot configure camera output", comment: "Camera error: output")
            case .permissionDenied:
                return NSLocalizedString("Camera permission was denied. Please enable in Settings.", comment: "Camera error: permission denied")
            case .unknown:
                return NSLocalizedString("An unknown error occurred", comment: "Camera error: unknown")
            }
        }
    }
    
    // MARK: - Setup
    
    func checkPermissions() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if !granted {
                await MainActor.run {
                    self.error = .permissionDenied
                }
            }
            return granted
        case .denied, .restricted:
            await MainActor.run {
                self.error = .permissionDenied
            }
            return false
        @unknown default:
            return false
        }
    }
    
    func configure() {
        sessionQueue.async { [weak self] in
            self?.configureSession()
        }
    }
    
    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high
        
        // Add video input
        do {
            // Try to get the wide angle camera first (most compatible)
            var defaultVideoDevice: AVCaptureDevice?
            
            if let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                defaultVideoDevice = backCamera
            } else if let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
                defaultVideoDevice = frontCamera
            }
            
            guard let videoDevice = defaultVideoDevice else {
                DispatchQueue.main.async {
                    self.error = .cameraUnavailable
                }
                session.commitConfiguration()
                return
            }
            
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
            } else {
                DispatchQueue.main.async {
                    self.error = .cannotAddInput
                }
                session.commitConfiguration()
                return
            }
        } catch {
            DispatchQueue.main.async {
                self.error = .cannotAddInput
            }
            session.commitConfiguration()
            return
        }

        // Add video data output for frame capture
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataQueue)
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
            // Rotate frames to match device orientation
            if let connection = videoDataOutput.connection(with: .video) {
                connection.videoOrientation = .portrait
            }
        }

        session.commitConfiguration()
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        frameLock.lock()
        _latestPixelBuffer = pixelBuffer
        frameLock.unlock()
    }

    // MARK: - Session Control
    
    func start() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.session.isRunning {
                self.session.startRunning()
                DispatchQueue.main.async {
                    self.isSessionRunning = self.session.isRunning
                }
            }
        }
    }
    
    func stop() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
                DispatchQueue.main.async {
                    self.isSessionRunning = false
                }
            }
        }
    }

    /// Keep captured frames aligned with the interface orientation so
    /// screenshots composite correctly in landscape.
    func setVideoOrientation(_ orientation: AVCaptureVideoOrientation) {
        sessionQueue.async { [weak self] in
            guard let self = self,
                  let connection = self.videoDataOutput.connection(with: .video),
                  connection.videoOrientation != orientation else { return }
            connection.videoOrientation = orientation
        }
    }

}

// MARK: - SwiftUI Camera Preview

struct CameraPreview: UIViewRepresentable {
    let cameraManager: CameraManager

    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.backgroundColor = .black
        view.videoPreviewLayer.session = cameraManager.session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: VideoPreviewView, context: Context) {
        // Update connection orientation if needed
        if let connection = uiView.videoPreviewLayer.connection {
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
            let interfaceOrientation = windowScene?.interfaceOrientation ?? .portrait

            if let videoOrientation = interfaceOrientation.videoOrientation {
                if connection.videoOrientation != videoOrientation {
                    connection.videoOrientation = videoOrientation
                }
                cameraManager.setVideoOrientation(videoOrientation)
            }
        }
    }
}

/// UIView subclass for camera preview
class VideoPreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
    
    /// Safe force cast — `layerClass` is overridden above to return `AVCaptureVideoPreviewLayer`.
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

// MARK: - Orientation Extension

extension UIInterfaceOrientation {
    var videoOrientation: AVCaptureVideoOrientation? {
        switch self {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeLeft
        case .landscapeRight:
            return .landscapeRight
        default:
            return nil
        }
    }
}
