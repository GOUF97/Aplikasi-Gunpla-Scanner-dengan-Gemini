import Foundation
import CoreML
import Vision
import Combine

class ObjectClassifier: ObservableObject {
    @Published var classificationLabel: String = "Mendeteksi..."
    @Published var confidenceLevel: Double = 0.0
    
    private var visionModel: VNCoreMLModel?
    private let classificationQueue = DispatchQueue(label: "com.app.objectClassifierQueue", qos: .userInitiated)

    init() {
        setupModel()
    }

    private func setupModel() {
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all
            
            // Ganti MobileNetV2() dengan FastViTT8F16()
            let model = try FastViTT8F16(configuration: config).model
            self.visionModel = try VNCoreMLModel(for: model)
        } catch {
            DispatchQueue.main.async {
                self.classificationLabel = "Gagal memuat model"
            }
            print("Gagal memuat model FastViT: \(error.localizedDescription)")
        }
    }

    func classify(image: CGImage) {
        guard let visionModel = visionModel else { return }

        classificationQueue.async {
            let request = VNCoreMLRequest(model: visionModel) { [weak self] request, error in
                guard let self = self else { return }
                
                if let results = request.results as? [VNClassificationObservation],
                   let topResult = results.first {
                    
                    DispatchQueue.main.async {
                        self.classificationLabel = topResult.identifier
                        self.confidenceLevel = Double(topResult.confidence)
                    }
                }
            }
            
            // Mengatur agar model fokus memotong area tengah (cocok dengan kotak hijau Anda)
            request.imageCropAndScaleOption = .centerCrop
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            
            try? handler.perform([request])
        }
    }
}
