import SwiftUI
import PhotosUI
import Vision

extension UIImage {
    var safeCGImage: CGImage? {
        if let cg = self.cgImage { return cg }
        if let ci = self.ciImage {
            let context = CIContext()
            return context.createCGImage(ci, from: ci.extent)
        }
        UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
        defer { UIGraphicsEndImageContext() }
        self.draw(in: CGRect(origin: .zero, size: self.size))
        return UIGraphicsGetImageFromCurrentImageContext()?.cgImage
    }
}

struct ContentView: View {
    @StateObject private var classifier = ObjectClassifier()
    @StateObject private var gunplaClassifier = GunplaClassifier()
    @StateObject private var recognizer = TextRecognizer()
    @StateObject private var aiService = GeminiService()
    
    @State private var selectedMode: AppMode = .objectScan
    @State private var textScanType: TextScanType = .offline
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var displayedImage: UIImage? = nil
    @State private var isChatSheetPresented: Bool = false

    enum AppMode {
        case objectScan
        case textScan
        case onlineAI
    }
    
    enum TextScanType {
        case offline
        case online
    }

    var body: some View {
        ZStack {
            if let displayedImage = displayedImage {
                Image(uiImage: displayedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        if selectedMode == .onlineAI {
                            isChatSheetPresented = true
                        }
                    }
                    .sheet(isPresented: $isChatSheetPresented) {
                        if let viewModel = ChatbotViewModel(image: displayedImage) {
                            ChatbotView(viewModel: viewModel)
                                .environmentObject(aiService)
                        }
                    }
            } else {
                CameraView { capturedImage in
                    if selectedMode == .objectScan {
                        if let cgImage = capturedImage.safeCGImage {
                            classifier.classify(image: cgImage)
                            gunplaClassifier.classify(image: cgImage)
                        }
                    } else if selectedMode == .textScan && textScanType == .offline {
                        recognizer.recognizeText(from: capturedImage)
                    }
                }
                .edgesIgnoringSafeArea(.all)

                RoundedRectangle(cornerRadius: 20)
                    .stroke(selectedMode == .onlineAI ? Color.purple : Color.green, lineWidth: 3)
                    .frame(width: 240, height: 240)
                    .background(Color.black.opacity(0.1))
            }

            VStack {
                VStack(spacing: 8) {
                    Picker("Mode", selection: $selectedMode) {
                        Text("Objek").tag(AppMode.objectScan)
                        Text("Teks").tag(AppMode.textScan)
                        Text("Online").tag(AppMode.onlineAI)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .scaleEffect(0.9)
                    
                    if selectedMode == .onlineAI {
                        HStack {
                            if aiService.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                                Text("Sedang menganalisis...")
                                    .font(.caption2)
                                    .foregroundColor(.yellow)
                            } else {
                                Image(systemName: "wand.and.stars")
                                    .foregroundColor(.purple)
                                Text("Gemini Expert")
                                    .font(.caption.bold())
                                    .foregroundColor(.purple)
                            }
                            Spacer()
                        }
                        
                        ScrollView {
                            Text(aiService.aiResponse)
                                .font(.caption)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 100)
                        
                    } else if selectedMode == .textScan {
                        Picker("Metode Teks", selection: $textScanType) {
                            Text("Offline (Vision)").tag(TextScanType.offline)
                            Text("Online (AI)").tag(TextScanType.online)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .scaleEffect(0.85)
                        
                        Text(recognizer.recognizedText)
                            .font(.caption)
                            .foregroundColor(.cyan)
                            .lineLimit(3)
                    } else {
                        let isCustomHigher = gunplaClassifier.gunplaConfidence >= classifier.confidenceLevel
                        let bestLabel = isCustomHigher ? gunplaClassifier.gunplaLabel : classifier.classificationLabel
                        let bestConfidence = isCustomHigher ? gunplaClassifier.gunplaConfidence : classifier.confidenceLevel

                        HStack {
                            Text(isCustomHigher ? "Model Kustom Gunpla" : "Standard Model")
                                .font(.caption2).foregroundColor(.gray)
                            Spacer()
                            Text(String(format: "%.1f%%", bestConfidence * 100))
                                .font(.caption.bold()).foregroundColor(.green)
                        }
                        Text(bestLabel.capitalized)
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                    }
                }
                .padding(10)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.top, 40)

                Spacer()

                if displayedImage != nil {
                    Button(action: {
                        self.displayedImage = nil
                        self.selectedItem = nil
                    }) {
                        HStack {
                            Image(systemName: "camera.fill")
                            Text("Kembali ke Kamera Live")
                        }
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.8))
                        .cornerRadius(10)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                } else {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        HStack {
                            Image(systemName: "photo.on.rectangle.angled")
                            Text("Pilih Foto dari Galeri")
                        }
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                    .onChange(of: selectedItem) { newItem in
                        Task {
                            guard let newItem = newItem,
                                  let data = try? await newItem.loadTransferable(type: Data.self),
                                  let uiImage = UIImage(data: data) else { return }
                            
                            await MainActor.run { self.displayedImage = uiImage }
                            
                            DispatchQueue.global(qos: .userInitiated).async {
                                if selectedMode == .onlineAI {
                                    aiService.analyzeWithGemini(image: uiImage)
                                } else if selectedMode == .textScan {
                                    if textScanType == .online {
                                        aiService.analyzeWithGemini(image: uiImage)
                                    } else {
                                        DispatchQueue.main.async {
                                            recognizer.recognizeText(from: uiImage)
                                        }
                                    }
                                } else if selectedMode == .objectScan {
                                    if let cgImage = uiImage.safeCGImage {
                                       classifier.classify(image: cgImage)
                                       gunplaClassifier.classify(image: cgImage)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct RoundedCornerShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

#Preview {
    ContentView()
}
