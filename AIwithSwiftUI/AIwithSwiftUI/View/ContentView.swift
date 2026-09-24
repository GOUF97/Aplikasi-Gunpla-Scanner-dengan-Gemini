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
    
    func cropToCenterBox(boxSize: CGSize, in screenSize: CGSize) -> UIImage {
        let ciImage = CIImage(image: self) ?? CIImage(cgImage: self.safeCGImage!)
        let inputSize = ciImage.extent.size
        
        let scale = min(inputSize.width / screenSize.width, inputSize.height / screenSize.height)
        
        let screenBoxX = (screenSize.width - boxSize.width) / 2
        let screenBoxY = (screenSize.height - boxSize.height) / 2
        
        let imageX = screenBoxX * scale + (inputSize.width - screenSize.width * scale) / 2
        let imageY = screenBoxY * scale + (inputSize.height - screenSize.height * scale) / 2
        let cropWidth = boxSize.width * scale
        let cropHeight = boxSize.height * scale
        
        let ciY = inputSize.height - (imageY + cropHeight)
        let cropRect = CGRect(x: imageX, y: ciY, width: cropWidth, height: cropHeight)
        
        let croppedCI = ciImage.cropped(to: cropRect)
        
        let context = CIContext(options: nil)
        guard let outputCGImage = context.createCGImage(croppedCI, from: croppedCI.extent) else {
            return self
        }
        
        return UIImage(cgImage: outputCGImage, scale: self.scale, orientation: self.imageOrientation)
    }
}

struct ContentView: View {
    @StateObject private var classifier = ObjectClassifier()
    @StateObject private var gunplaClassifier = GunplaClassifier()
    @StateObject private var recognizer = TextRecognizer()
    @StateObject private var aiService = GeminiService()
    
    @State private var selectedMode: AppMode = .onlineAI
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
        GeometryReader { geometry in
            ZStack {
                // Jika ada gambar yang dikunci / dipilih, tampilkan secara statis
                if let displayedImage = displayedImage {
                    Color.black
                        .edgesIgnoringSafeArea(.all)
                    
                    Image(uiImage: displayedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    // Tampilan Live Kamera dengan tombol shutter
                    CameraView { capturedImage in
                        // Ambil ukuran kotak panduan (240x240) dan ukuran layar device
                        let boxSize = CGSize(width: 240, height: 240)
                        let screenSize = geometry.size
                        
                        // Crop gambar HANYA yang berada di dalam kotak tanpa merusak rasio
                        let croppedImage = capturedImage.cropToCenterBox(boxSize: boxSize, in: screenSize)
                        
                        self.displayedImage = croppedImage
                        runAnalysis(for: croppedImage, mode: selectedMode)
                    }
                    .edgesIgnoringSafeArea(.all)

                    // Kotak pemandu bidikan di tengah
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(selectedMode == .onlineAI ? Color.purple : Color.green, lineWidth: 3)
                        .frame(width: 240, height: 240)
                        .background(Color.black.opacity(0.1))
                    
                    // Teks panduan interaktif di atas tombol shutter
                    VStack {
                        Spacer()
                        Text(selectedMode == .onlineAI ? "Posisikan Gunpla dalam kotak, lalu tekan Shutter" : "Posisikan objek dalam kotak, lalu tekan Shutter")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                            .padding(.bottom, 180)
                    }
                }

                // Layer Kontrol Atas & Bawah
                VStack {
                    VStack(spacing: 8) {
                        Picker("Mode", selection: $selectedMode) {
                            Text("Online AI").tag(AppMode.onlineAI)
                            Text("AI Offline").tag(AppMode.objectScan)
                            Text("Teks").tag(AppMode.textScan)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .scaleEffect(0.9)
                        .onChange(of: selectedMode) { newMode in
                            if let currentImage = displayedImage {
                                runAnalysis(for: currentImage, mode: newMode)
                            }
                        }
                        
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
                                    Text(displayedImage != nil ? "Ketuk gambar untuk mulai Chat" : "Gemini AI Ready")
                                        .font(.caption.bold())
                                        .foregroundColor(.purple)
                                }
                                Spacer()
                            }
                            
                            if displayedImage != nil {
                                ScrollView {
                                    Text(aiService.aiResponse)
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .frame(maxHeight: 100)
                            }
                            
                        } else if selectedMode == .textScan {
                            Picker("Metode Teks", selection: $textScanType) {
                                Text("Offline (Vision)").tag(TextScanType.offline)
                                Text("Online (AI)").tag(TextScanType.online)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .scaleEffect(0.85)
                            .onChange(of: textScanType) { newType in
                                if let currentImage = displayedImage {
                                    runAnalysis(for: currentImage, mode: .textScan)
                                }
                            }
                            
                            if displayedImage != nil {
                                Text(recognizer.recognizedText)
                                    .font(.caption)
                                    .foregroundColor(.cyan)
                                    .lineLimit(3)
                            }
                        } else if selectedMode == .objectScan {
                            HStack {
                                let isCustomHigher = gunplaClassifier.gunplaConfidence >= classifier.confidenceLevel
                                let bestLabel = isCustomHigher ? gunplaClassifier.gunplaLabel : classifier.classificationLabel
                                let bestConfidence = isCustomHigher ? gunplaClassifier.gunplaConfidence : classifier.confidenceLevel

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(isCustomHigher ? "Model Kustom Core ML" : "Model Standard Core ML")
                                            .font(.caption2).foregroundColor(.green)
                                        Spacer()
                                        Text(String(format: "%.1f%%", bestConfidence * 100))
                                            .font(.caption.bold()).foregroundColor(.white)
                                    }
                                    Text(bestLabel.isEmpty ? "Memindai objek..." : bestLabel.capitalized)
                                        .font(.subheadline.bold())
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.top, 40)

                    Spacer()

                    // Tombol Navigasi Bawah
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
                                
                                // Jika pilih dari galeri, potong juga sesuai proporsi kotak tengah agar konsisten
                                let boxSize = CGSize(width: 240, height: 240)
                                let croppedGalleryImage = uiImage.cropToCenterBox(boxSize: boxSize, in: geometry.size)
                                
                                await MainActor.run { self.displayedImage = croppedGalleryImage }
                                runAnalysis(for: croppedGalleryImage, mode: selectedMode)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func runAnalysis(for image: UIImage, mode: AppMode) {
        DispatchQueue.global(qos: .userInitiated).async {
            if mode == .onlineAI {
                aiService.analyzeWithGemini(image: image)
            } else if mode == .textScan {
                if textScanType == .online {
                    aiService.analyzeWithGemini(image: image)
                } else {
                    DispatchQueue.main.async {
                        recognizer.recognizeText(from: image)
                    }
                }
            } else if mode == .objectScan {
                if let cgImage = image.safeCGImage {
                    classifier.classify(image: cgImage)
                    gunplaClassifier.classify(image: cgImage)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
