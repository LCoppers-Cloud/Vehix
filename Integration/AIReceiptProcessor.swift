import Foundation
import SwiftUI
import Vision
import CoreML
import SwiftData

// MARK: - AI Receipt Analysis Models

struct AIReceiptAnalysis: Codable {
    let vendor: VendorInfo
    let date: String
    let total: Double
    let subtotal: Double?
    let tax: Double?
    let lineItems: [LineItemInfo]
    let confidence: Double
    let rawText: String
    
    struct VendorInfo: Codable {
        let name: String
        let address: String?
        let phone: String?
        let confidence: Double
    }
    
    struct LineItemInfo: Codable {
        let description: String
        let quantity: Int
        let unitPrice: Double
        let total: Double
        let category: String?
    }
}

// MARK: - ChatGPT Vision Integration

class AIReceiptProcessor: ObservableObject {
    private let openAIAPIKey: String
    private let endpoint = "https://api.openai.com/v1/chat/completions"
    
    @Published var isProcessing = false
    @Published var analysisResult: AIReceiptAnalysis?
    @Published var errorMessage: String?
    
    init() {
        // In production, store this securely in Keychain
        self.openAIAPIKey = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String ?? ""
    }
    
    func analyzeReceipt(_ image: UIImage) async -> AIReceiptAnalysis? {
        await MainActor.run {
            isProcessing = true
            errorMessage = nil
        }
        
        defer {
            Task { @MainActor in
                isProcessing = false
            }
        }
        
        guard !openAIAPIKey.isEmpty else {
            await MainActor.run {
                errorMessage = "OpenAI API key not configured"
            }
            return nil
        }
        
        // Convert image to base64
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            await MainActor.run {
                errorMessage = "Failed to process image"
            }
            return nil
        }
        
        let base64Image = imageData.base64EncodedString()
        
        // Create the request payload
        let payload = createChatGPTPayload(base64Image: base64Image)
        
        do {
            let analysis = try await performChatGPTRequest(payload: payload)
            await MainActor.run {
                self.analysisResult = analysis
            }
            return analysis
        } catch {
            await MainActor.run {
                self.errorMessage = "Analysis failed: \(error.localizedDescription)"
            }
            return nil
        }
    }
    
    private func createChatGPTPayload(base64Image: String) -> [String: Any] {
        let systemPrompt = """
        You are an expert receipt analysis system. Analyze the receipt image and extract ALL information with high accuracy.
        
        CRITICAL REQUIREMENTS:
        1. Extract vendor name, address, phone (if visible)
        2. Extract purchase date and time
        3. Extract all monetary amounts (subtotal, tax, total)
        4. Extract EVERY line item with quantities and prices
        5. Categorize items (food, parts, supplies, tools, etc.)
        6. Return confidence scores for accuracy
        
        For service technicians, focus on:
        - Hardware/parts purchases
        - Tools and equipment
        - Supplies and materials
        - Accurate total amounts for job costing
        
        Be extremely precise with numbers and amounts.
        """
        
        let userPrompt = """
        Analyze this receipt image and return a JSON response with the following exact structure:
        
        {
          "vendor": {
            "name": "Exact vendor name",
            "address": "Full address if visible",
            "phone": "Phone number if visible",
            "confidence": 0.95
          },
          "date": "YYYY-MM-DD format",
          "total": 0.00,
          "subtotal": 0.00,
          "tax": 0.00,
          "lineItems": [
            {
              "description": "Item description",
              "quantity": 1,
              "unitPrice": 0.00,
              "total": 0.00,
              "category": "parts/tools/supplies/food/other"
            }
          ],
          "confidence": 0.95,
          "rawText": "All text found on receipt"
        }
        
        Extract ALL items, even small ones. Be extremely accurate with amounts.
        """
        
        return [
            "model": "gpt-4o",
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt
                ],
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": userPrompt
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64Image)",
                                "detail": "high"
                            ]
                        ]
                    ]
                ]
            ],
            "max_tokens": 2000,
            "temperature": 0.1,
            "response_format": ["type": "json_object"]
        ]
    }
    
    private func performChatGPTRequest(payload: [String: Any]) async throws -> AIReceiptAnalysis {
        guard let url = URL(string: endpoint) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(openAIAPIKey)", forHTTPHeaderField: "Authorization")
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "ChatGPT", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
        
        // Parse ChatGPT response
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            
            // Parse the JSON content from ChatGPT
            if let contentData = content.data(using: .utf8) {
                return try JSONDecoder().decode(AIReceiptAnalysis.self, from: contentData)
            }
        }
        
        throw NSError(domain: "ChatGPT", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response"])
    }
}

// MARK: - Enhanced Receipt Processing with Apple VisionKit Fallback

class EnhancedReceiptProcessor: ObservableObject {
    private let aiProcessor = AIReceiptProcessor()
    private let visionProcessor = VisionReceiptProcessor()
    
    @Published var isProcessing = false
    @Published var currentMethod: ProcessingMethod = .ai
    @Published var result: ProcessedReceipt?
    @Published var errorMessage: String?
    
    enum ProcessingMethod {
        case ai
        case vision
        case hybrid
    }
    
    struct ProcessedReceipt {
        let vendor: VendorInfo
        let date: Date
        let total: Double
        let subtotal: Double?
        let tax: Double?
        let lineItems: [LineItem]
        let confidence: Double
        let method: ProcessingMethod
        let rawText: String
        
        struct VendorInfo {
            let name: String
            let address: String?
            let phone: String?
            let confidence: Double
        }
        
        struct LineItem {
            let description: String
            let quantity: Int
            let unitPrice: Double
            let total: Double
            let category: String?
        }
    }
    
    func processReceipt(_ image: UIImage, preferredMethod: ProcessingMethod = .hybrid) async -> ProcessedReceipt? {
        await MainActor.run {
            isProcessing = true
            currentMethod = preferredMethod
            errorMessage = nil
        }
        
        defer {
            Task { @MainActor in
                isProcessing = false
            }
        }
        
        switch preferredMethod {
        case .ai:
            return await processWithAI(image)
        case .vision:
            return await processWithVision(image)
        case .hybrid:
            return await processWithHybrid(image)
        }
    }
    
    private func processWithAI(_ image: UIImage) async -> ProcessedReceipt? {
        if let analysis = await aiProcessor.analyzeReceipt(image) {
            return convertAIAnalysis(analysis, method: ProcessingMethod.ai)
        }
        return nil
    }
    
    private func processWithVision(_ image: UIImage) async -> ProcessedReceipt? {
        if let analysis = await visionProcessor.processReceipt(image) {
            return convertVisionAnalysis(analysis, method: ProcessingMethod.vision)
        }
        return nil
    }
    
    private func processWithHybrid(_ image: UIImage) async -> ProcessedReceipt? {
        // Try AI first, fallback to Vision if AI fails
        if let aiResult = await processWithAI(image) {
            return aiResult
        }
        
        print("AI processing failed, falling back to Apple Vision")
        return await processWithVision(image)
    }
    
    private func convertAIAnalysis(_ analysis: AIReceiptAnalysis, method: ProcessingMethod) -> ProcessedReceipt {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let date = dateFormatter.date(from: analysis.date) ?? Date()
        
        let vendor = ProcessedReceipt.VendorInfo(
            name: analysis.vendor.name,
            address: analysis.vendor.address,
            phone: analysis.vendor.phone,
            confidence: analysis.vendor.confidence
        )
        
        let lineItems = analysis.lineItems.map { item in
            ProcessedReceipt.LineItem(
                description: item.description,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                total: item.total,
                category: item.category
            )
        }
        
        return ProcessedReceipt(
            vendor: vendor,
            date: date,
            total: analysis.total,
            subtotal: analysis.subtotal,
            tax: analysis.tax,
            lineItems: lineItems,
            confidence: analysis.confidence,
            method: method,
            rawText: analysis.rawText
        )
    }
    
    private func convertVisionAnalysis(_ analysis: VisionReceiptProcessor.VisionReceiptAnalysis, method: ProcessingMethod) -> ProcessedReceipt {
        let vendor = ProcessedReceipt.VendorInfo(
            name: analysis.vendorName ?? "Unknown Vendor",
            address: nil,
            phone: nil,
            confidence: 0.7
        )
        
        let lineItems = analysis.lineItems.map { item in
            ProcessedReceipt.LineItem(
                description: item.description,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                total: item.total,
                category: nil
            )
        }
        
        return ProcessedReceipt(
            vendor: vendor,
            date: analysis.date ?? Date(),
            total: analysis.total ?? 0,
            subtotal: nil,
            tax: nil,
            lineItems: lineItems,
            confidence: 0.7,
            method: method,
            rawText: analysis.rawText
        )
    }
}

// MARK: - Apple Vision Fallback Processor

class VisionReceiptProcessor {
    struct VisionReceiptAnalysis {
        let vendorName: String?
        let date: Date?
        let total: Double?
        let lineItems: [LineItem]
        let rawText: String
        
        struct LineItem {
            let description: String
            let quantity: Int
            let unitPrice: Double
            let total: Double
        }
    }
    
    func processReceipt(_ image: UIImage) async -> VisionReceiptAnalysis? {
        guard let cgImage = image.cgImage else { return nil }
        
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
            
            guard let results = request.results else { return nil }
            
            var fullText = ""
            for observation in results {
                guard let candidate = observation.topCandidates(1).first else { continue }
                fullText += candidate.string + "\n"
            }
            
            return parseReceiptText(fullText)
        } catch {
            print("Vision OCR failed: \(error)")
            return nil
        }
    }
    
    private func parseReceiptText(_ text: String) -> VisionReceiptAnalysis {
        let lines = text.components(separatedBy: .newlines)
        
        // Basic parsing logic (simplified)
        var vendorName: String?
        let date: Date? = nil  // For now, we'll implement date parsing later
        var total: Double?
        var lineItems: [VisionReceiptAnalysis.LineItem] = []
        
        // Extract vendor (usually first non-empty line)
        vendorName = lines.first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        // Extract total (look for patterns like "Total: $XX.XX")
        for line in lines {
            if line.lowercased().contains("total") {
                let numbers = line.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap { Double($0) }
                if let lastNumber = numbers.last {
                    total = lastNumber
                }
            }
        }
        
        // Basic line item extraction (this would be more sophisticated in production)
        for line in lines {
            if line.contains("$") && !line.lowercased().contains("total") {
                // Simple line item parsing
                let components = line.components(separatedBy: " ")
                if let priceString = components.last?.replacingOccurrences(of: "$", with: ""),
                   let price = Double(priceString) {
                    let description = components.dropLast().joined(separator: " ")
                    if !description.isEmpty {
                        let item = VisionReceiptAnalysis.LineItem(
                            description: description,
                            quantity: 1,
                            unitPrice: price,
                            total: price
                        )
                        lineItems.append(item)
                    }
                }
            }
        }
        
        return VisionReceiptAnalysis(
            vendorName: vendorName,
            date: date,
            total: total,
            lineItems: lineItems,
            rawText: text
        )
    }
} 