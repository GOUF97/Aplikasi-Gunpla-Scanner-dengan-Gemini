import SwiftUI
import AVFoundation

struct CameraView: View {
    var onCapture: (UIImage) -> Void
    
    @State private var cameraController = CameraController()

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black
                .edgesIgnoringSafeArea(.all)
            
            CameraPreview(controller: cameraController)
                .edgesIgnoringSafeArea(.all)
            
            Button(action: {
                cameraController.captureImage { image in
                    if let image = image {
                        onCapture(image)
                    }
                }
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 75, height: 75)
                    Circle()
                        .stroke(Color.black, lineWidth: 2)
                        .frame(width: 65, height: 65)
                }
            }
            .padding(.bottom, 90)
        }
        .onAppear {
            cameraController.startSession()
        }
        .onDisappear {
            cameraController.stopSession()
        }
    }
}

class CameraController: NSObject {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private var completion: ((UIImage?) -> Void)?

    func startSession() {
        DispatchQueue.global(qos: .userInitiated).async {
            if !self.session.isRunning {
                self.session.beginConfiguration()
                
                if self.session.canSetSessionPreset(.high) {
                    self.session.sessionPreset = .high
                }
                
                if self.session.inputs.isEmpty {
                    guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                          let input = try? AVCaptureDeviceInput(device: device),
                          self.session.canAddInput(input) else {
                        self.session.commitConfiguration()
                        return
                    }
                    self.session.addInput(input)
                }
                
                if self.session.outputs.isEmpty {
                    if self.session.canAddOutput(self.output) {
                        self.session.addOutput(self.output)
                    }
                }
                
                self.session.commitConfiguration()
                self.session.startRunning()
            }
        }
    }

    func stopSession() {
        DispatchQueue.global(qos: .userInitiated).async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    func captureImage(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
        let settings = AVCapturePhotoSettings()
        output.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("DEBUG: Gagal mengambil foto: \(error.localizedDescription)")
            completion?(nil)
            return
        }
        
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            print("DEBUG: Gagal mengonversi data foto ke UIImage")
            completion?(nil)
            return
        }
        
        completion?(image)
    }
}

struct CameraPreview: UIViewRepresentable {
    var controller: CameraController

    func makeUIView(context: Context) -> UIView {
        let view = VideoPreviewView()
        view.backgroundColor = .black
        view.previewLayer.session = controller.session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    class VideoPreviewView: UIView {
        override class var layerClass: AnyClass {
            return AVCaptureVideoPreviewLayer.self
        }
        
        var previewLayer: AVCaptureVideoPreviewLayer {
            return self.layer as! AVCaptureVideoPreviewLayer
        }
    }
}
