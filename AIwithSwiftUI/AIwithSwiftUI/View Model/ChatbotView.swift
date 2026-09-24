import SwiftUI
import Combine

class ChatbotViewModel: ObservableObject {
    @Published var messages: [String] = []
    @Published var inputMessage: String = ""
    let attachedImage: UIImage
    
    init?(image: UIImage?) {
        guard let image = image else { return nil }
        self.attachedImage = image
        self.messages.append("Halo! Saya asisten builder Gunpla Anda. Ada yang ingin didiskusikan mengenai rakitan atau part pada foto ini?")
    }
    
    func sendMessage(aiService: GeminiService) {
        let trimmedMessage = inputMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return }
        
        messages.append("User: \(trimmedMessage)")
        inputMessage = ""
        
        aiService.aiResponse = "Sedang merakit jawaban..."
        aiService.analyzeWithGemini(image: attachedImage)
    }
}

struct ChatbotView: View {
    @EnvironmentObject var aiService: GeminiService
    @ObservedObject var viewModel: ChatbotViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                Image(uiImage: viewModel.attachedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 120)
                    .cornerRadius(8)
                    .padding(.top, 8)
                
                List(viewModel.messages, id: \.self) { message in
                    Text(message)
                        .font(.caption)
                        .padding(.vertical, 4)
                }
                .listStyle(PlainListStyle())
                
                HStack(spacing: 8) {
                    TextField("Tanya soal rakitan, panel lining, dll...", text: $viewModel.inputMessage)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.caption)
                    
                    Button(action: {
                        viewModel.sendMessage(aiService: aiService)
                    }) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.purple)
                            .clipShape(Circle())
                    }
                }
                .padding()
            }
            .navigationTitle("Chat Gemini Expert")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Tutup") {
                dismiss()
            })
        }
    }
}
