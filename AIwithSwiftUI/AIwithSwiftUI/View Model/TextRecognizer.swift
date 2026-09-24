import Foundation
import Vision
import Combine
import UIKit

class TextRecognizer: ObservableObject {
    @Published var recognizedText: String = "Menunggu teks..."
    
    private let textQueue = DispatchQueue(label: "com.app.textQueue", qos: .userInitiated)
    
    func recognizeText(from image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        
        textQueue.async {
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let request = VNRecognizeTextRequest { [weak self] request, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Gagal mengenali teks: \(error.localizedDescription)")
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    return
                }
                
                // Ambil string teks dengan tingkat kepercayaan (confidence) tertinggi
                let extractedStrings = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                
                let combinedText = extractedStrings.joined(separator: " ")
                
                DispatchQueue.main.async {
                    if !combinedText.isEmpty {
                        self.recognizedText = combinedText
                    }
                }
            }
            
            // Atur agar pengenalan teks lebih akurat
            request.recognitionLevel = .accurate
            
            do {
                try requestHandler.perform([request])
            } catch {
                print("Gagal melakukan request teks: \(error.localizedDescription)")
            }
        }
    }
}
