import AVFoundation
import UIKit
import SwiftUI
import Combine

/// Manages the camera session and preview
class CameraManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isSessionRunning = false
    @Published var error: CameraError?
    
    // MARK: - Properties
    
    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private var videoDeviceInput: AVCaptureDeviceInput?
    
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
            return await AVCaptureDevice.requestAccess(for: .video)
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
        
        session.commitConfiguration()
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
}

// MARK: - SwiftUI Camera Preview

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.backgroundColor = .black
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: VideoPreviewView, context: Context) {
        // Update connection orientation if needed
        if let connection = uiView.videoPreviewLayer.connection {
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
            let interfaceOrientation = windowScene?.interfaceOrientation ?? .portrait
            
            if let videoOrientation = interfaceOrientation.videoOrientation {
                connection.videoOrientation = videoOrientation
            }
        }
    }
}

/// UIView subclass for camera preview
class VideoPreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
    
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
