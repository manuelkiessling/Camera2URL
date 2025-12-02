//
//  CameraPreviewView.swift
//  camera2url_ios

import AVFoundation
import SwiftUI

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession?
    var topSafeAreaInset: CGFloat = 0

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.topSafeAreaInset = topSafeAreaInset
        uiView.setSession(session)
    }

    final class PreviewView: UIView {
        private let previewLayer = AVCaptureVideoPreviewLayer()
        private var sessionObservation: NSKeyValueObservation?
        var topSafeAreaInset: CGFloat = 0
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .black
            
            previewLayer.videoGravity = .resizeAspect
            previewLayer.backgroundColor = CGColor(gray: 0, alpha: 1)
            layer.addSublayer(previewLayer)
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
        
        override func layoutSubviews() {
            super.layoutSubviews()
            updatePreviewLayerFrame()
        }
        
        private func updatePreviewLayerFrame() {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            
            let viewBounds = bounds
            // Available height excludes the top safe area (notch/island)
            let availableHeight = viewBounds.height - topSafeAreaInset
            let availableWidth = viewBounds.width
            
            // Get video dimensions from the session's input
            if let session = previewLayer.session,
               let input = session.inputs.first as? AVCaptureDeviceInput {
                let device = input.device
                let dimensions = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
                let videoWidth = CGFloat(dimensions.width)
                let videoHeight = CGFloat(dimensions.height)
                
                if videoWidth > 0 && videoHeight > 0 {
                    let videoAspectRatio = videoWidth / videoHeight
                    
                    // Calculate size that fits within available bounds while maintaining aspect ratio
                    let widthBasedHeight = availableWidth / videoAspectRatio
                    let heightBasedWidth = availableHeight * videoAspectRatio
                    
                    let heightOffset: CGFloat = 200 // Needed to achieve the desired height of the preview layer
                    let layerSize: CGSize
                    if widthBasedHeight <= availableHeight {
                        // Video fits by width - may have space above
                        layerSize = CGSize(width: availableWidth, height: widthBasedHeight + heightOffset)
                    } else {
                        // Video fits by height - may have space on sides
                        layerSize = CGSize(width: heightBasedWidth, height: availableHeight + heightOffset)
                    }
                   
                    // Position at bottom of view, centered horizontally (anchored above UI controls)
                    let x = (viewBounds.width - layerSize.width) / 2
                    let y = viewBounds.height - layerSize.height  // Align to bottom
                    
                    previewLayer.frame = CGRect(x: x, y: y, width: layerSize.width, height: layerSize.height)
                    CATransaction.commit()
                    return
                }
            }
            
            // Fallback: fill the available area if we can't determine video dimensions
            previewLayer.frame = CGRect(x: 0, y: topSafeAreaInset, width: availableWidth, height: availableHeight)
            CATransaction.commit()
        }
    }
}
