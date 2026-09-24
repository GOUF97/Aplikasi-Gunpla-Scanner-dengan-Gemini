//
//  Untitled.swift
//  AIwithSwiftUI
//
//  Created by muhammad sutrisno on 23/09/26.
//

import Foundation
import CoreML
import Vision
import Combine

class GunplaClassifier: ObservableObject {
    @Published var gunplaLabel: String = "Mendeteksi Gunpla..."
    @Published var gunplaConfidence: Double = 0.0
    
    private var visionModel: VNCoreMLModel?
    private let classificationQueue = DispatchQueue(label: "com.app.gunplaQueue", qos: .userInitiated)

    init() {
        setupModel()
    }

    private func setupModel() {
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all
            
            // Perhatikan nama kelas model Anda di bawah ini.
            // Jika error, sesuaikan dengan nama kelas yang digenerate oleh Xcode untuk "MyGundamImageClassifier 1"
            let model = try MyGundamImageClassifier_1(configuration: config).model
            self.visionModel = try VNCoreMLModel(for: model)
        } catch {
            DispatchQueue.main.async {
                self.gunplaLabel = "Gagal memuat model Gunpla"
            }
            print("Gagal memuat model kustom Gunpla: \(error.localizedDescription)")
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
                        self.gunplaLabel = topResult.identifier
                        self.gunplaConfidence = Double(topResult.confidence)
                    }
                }
            }
            
            request.imageCropAndScaleOption = .centerCrop
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            
            try? handler.perform([request])
        }
    }
}
