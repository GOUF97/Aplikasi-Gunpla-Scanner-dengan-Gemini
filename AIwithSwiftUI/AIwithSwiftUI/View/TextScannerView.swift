import SwiftUI

struct TextScannerView: View {
    @StateObject private var recognizer = TextRecognizer()

    var body: some View {
        ZStack {
            // Menggunakan kembali CameraView yang sudah dibuat di Modul 2
            CameraView { capturedImage in
                recognizer.recognizeText(from: capturedImage)
            }
            .edgesIgnoringSafeArea(.all)

            // Panel Hasil OCR ala Google Lens
            VStack {
                Spacer()

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "text.viewfinder")
                            .foregroundColor(.blue)
                        Text("Vision OCR (Text Recognition)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    Text(recognizer.recognizedText)
                        .font(.body)
                        .foregroundColor(.white)
                        .lineLimit(3)
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
        }
    }
}

#Preview {
    TextScannerView()
}