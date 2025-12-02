//
//  CameraPreviewView.swift
//  camera2url

import AVFoundation
import SwiftUI

struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession?

    func makeNSView(context: Context) -> PreviewView {
        let view = PreviewView()
        return view
    }

    func updateNSView(_ nsView: PreviewView, context: Context) {
        nsView.setSession(session)
    }

    final class PreviewView: NSView {
        private let previewLayer = AVCaptureVideoPreviewLayer()
        private var sessionObservation: NSKeyValueObservation?
        
        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
            layer?.backgroundColor = CGColor(gray: 0, alpha: 1)
            
            previewLayer.videoGravity = .resizeAspect
            previewLayer.backgroundColor = CGColor(gray: 0, alpha: 1)
            layer?.addSublayer(previewLayer)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func setSession(_ session: AVCaptureSession?) {
            previewLayer.session = session
            
            // Observe session running state to update layout when video starts
            sessionObservation?.invalidate()
            if let session = session {
                sessionObservation = session.observe(\.isRunning) { [weak self] _, _ in
                    DispatchQueue.main.async {
                        self?.updatePreviewLayerFrame()
                    }
                }
            }
            updatePreviewLayerFrame()
        }
        
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            previewLayer
        }
        
        override func layout() {
            super.layout()
            updatePreviewLayerFrame()
        }
        
        private func updatePreviewLayerFrame() {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            
            let viewBounds = bounds
            
            // Get video dimensions from the session's input
            if let session = previewLayer.session,
               let input = session.inputs.first as? AVCaptureDeviceInput {
                let device = input.device
                let dimensions = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
                let videoWidth = CGFloat(dimensions.width)
                let videoHeight = CGFloat(dimensions.height)
                
                if videoWidth > 0 && videoHeight > 0 {
                    let videoAspectRatio = videoWidth / videoHeight
                    
                    // Calculate size that fits within view bounds while maintaining aspect ratio
                    let widthBasedHeight = viewBounds.width / videoAspectRatio
                    let heightBasedWidth = viewBounds.height * videoAspectRatio
                    
                    let layerSize: CGSize
                    if widthBasedHeight <= viewBounds.height {
                        // Video fits by width - may have space below
                        layerSize = CGSize(width: viewBounds.width, height: widthBasedHeight)
                    } else {
                        // Video fits by height - may have space on sides
                        layerSize = CGSize(width: heightBasedWidth, height: viewBounds.height)
                    }
                    
                    // Position at top, centered horizontally
                    let x = (viewBounds.width - layerSize.width) / 2
                    let y = viewBounds.height - layerSize.height  // macOS coordinates: origin at bottom-left
                    
                    previewLayer.frame = CGRect(x: x, y: y, width: layerSize.width, height: layerSize.height)
                    CATransaction.commit()
                    return
                }
            }
            
            // Fallback: fill the view if we can't determine video dimensions
            previewLayer.frame = viewBounds
            CATransaction.commit()
        }
    }
}
