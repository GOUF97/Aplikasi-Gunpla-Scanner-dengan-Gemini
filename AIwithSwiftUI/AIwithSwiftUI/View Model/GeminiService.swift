import Foundation
import UIKit
import Combine

class GeminiService: ObservableObject {
    @Published var aiResponse: String = "Arahkan kamera ke Gunpla atau pilih foto..."
    @Published var isLoading: Bool = false
    
    private let systemInstruction = "Anda adalah seorang builder profesional dan penghobi setia Gundam serta Gunpla (Gundam Plastic Model) yang sangat berpengalaman, ramah, dan antusias. Tugas Anda adalah memandu pengguna—khususnya pemula—dengan memberikan rekomendasi Gunpla yang sedang populer saat ini, menceritakan sejarah singkat di balik serinya, serta mengajarkan tips dan trik cara merakit (mulai dari cara potong part, membersihkan nub mark, hingga panel lining) dengan bahasa yang sangat sederhana, santai, dan mudah dipahami semua kalangan."
    
    private var geminiApiKey: String { loadKey(keyName: "GEMINI_API_KEY", defaultVal: "MASUKKAN_GEMINI_API_KEY_ANDA") }
    
    private func loadKey(keyName: String, defaultVal: String) -> String {
        if let envPath = Bundle.main.path(forResource: ".env", ofType: nil),
           let envContents = try? String(contentsOfFile: envPath, encoding: .utf8) {
            let lines = envContents.components(separatedBy: .newlines)
            for line in lines {
                let parts = line.components(separatedBy: "=")
                if parts.count >= 2, parts[0].trimmingCharacters(in: .whitespaces) == keyName {
                    let value = parts[1...].joined(separator: "=")
                    return value.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        return defaultVal
    }

    func analyzeWithGemini(image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        let base64Image = imageData.base64EncodedString()
        
        isLoading = true
        aiResponse = "Gemini sedang merakit informasi..."
        
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent?key=\(geminiApiKey)"
        guard let url = URL(string: urlString) else { return }
        
        let jsonBody: [String: Any] = [
            "system_instruction": [
                "parts": ["text": systemInstruction]
            ],
            "contents": [
                [
                    "parts": [
                        ["text": "Analisis bagian/model Gunpla ini dan berikan panduan builder secara santai!"],
                        ["inline_data": ["mime_type": "image/jpeg", "data": base64Image]]
                    ]
                ]
            ]
        ]
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: jsonBody) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = httpBody
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    self.aiResponse = "Gagal terhubung: \(error.localizedDescription)"
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.aiResponse = "Respons server tidak valid."
                    return
                }
                
                if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    self.aiResponse = "⚠️ Gemini API Key tidak valid atau kedaluwarsa (Cek file .env)."
                    return
                } else if httpResponse.statusCode == 429 {
                    self.aiResponse = "⚠️ Batas kuota API Gemini tercapai (Rate Limit)."
                    return
                }
                
                guard let data = data else {
                    self.aiResponse = "Data respons kosong."
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let errorObj = json["error"] as? [String: Any],
                           let message = errorObj["message"] as? String {
                            self.aiResponse = "Gemini API Error: \(message)"
                            return
                        }
                        
                        if let candidates = json["candidates"] as? [[String: Any]],
                           let firstCandidate = candidates.first,
                           let content = firstCandidate["content"] as? [String: Any],
                           let parts = content["parts"] as? [[String: Any]],
                           let text = parts.first?["text"] as? String {
                            self.aiResponse = text
                            return
                        }
                        
                        self.aiResponse = "Format respons Gemini tidak dikenali."
                    }
                } catch {
                    self.aiResponse = "Error parsing: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
}
