import Foundation
import SwiftUI
import Vision
import VisionKit
import SwiftData

@MainActor
class ReceiptScannerManager: ObservableObject {
    @Published var isProcessing = false
    @Published var scannedImage: UIImage?
    @Published var recognizedText = ""
    @Published var recognizedVendor: AppVendor?
    @Published var recognizedDate: Date?
    @Published var recognizedTotal: Double?
    @Published var recognizedItems: [ReceiptItem] = []
    @Published var showNewVendorAlert = false
    @Published var rawVendorName: String?
    @Published var errorMessage: String?
    
    // AI Processing
    @Published var aiAnalysisResult: AIReceiptAnalysis?
    @Published var isUsingAI = true
    @Published var processingMethod: String = ""
    
    private var modelContext: ModelContext?
    private var vendorManager: VendorRecognitionManager
    private let aiProcessor = EnhancedReceiptProcessor()
    
    // Receipt text extraction patterns (fallback for non-AI processing)
    private let vendorPattern = "(?i)(?:vendor|store|merchant|business): ?(.+?)(?:\\n|$)"
    private let datePattern = "(?i)(?:date): ?(\\d{1,2}[/-]\\d{1,2}[/-](?:\\d{2}|\\d{4}))"
    private let totalPattern = "(?i)(?:total|amount|sum): ?\\$?(\\d+\\.\\d{2})"
    
    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
        self.vendorManager = VendorRecognitionManager(modelContext: modelContext)
        
        // Load vendors when initialized
        Task {
            await vendorManager.loadVendors()
            
            // If no vendors are loaded from local database, fetch from CloudKit
            if vendorManager.vendorList.isEmpty {
                await vendorManager.fetchVendorsFromCloudKit()
            }
        }
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        self.vendorManager.setModelContext(context)
    }
    
    // MARK: - Enhanced AI Image Processing
    
    func processReceiptImage(_ image: UIImage) async {
        guard image.cgImage != nil else {
            errorMessage = "Invalid image format"
            return
        }
        
        // Reset state
        resetScanState()
        
        // Store the image
        scannedImage = image
        isProcessing = true
        
        // Try AI processing first, fallback to traditional OCR if needed
        await processWithAI(image)
        
        isProcessing = false
    }
    
    private func processWithAI(_ image: UIImage) async {
        processingMethod = "🤖 AI Processing with ChatGPT Vision"
        
        // Use the enhanced AI processor with hybrid approach
        if let result = await aiProcessor.processReceipt(image, preferredMethod: .hybrid) {
            aiAnalysisResult = convertToAIAnalysis(result)
            await processAIResult(result)
            processingMethod = "✅ \(result.method == .ai ? "ChatGPT Vision" : "Apple Vision") - \(Int(result.confidence * 100))% confidence"
        } else {
            // Complete fallback to traditional OCR
            processingMethod = "⚠️ Fallback to Basic OCR"
            await performTraditionalOCR(on: image.cgImage!)
        }
    }
    
    private func processAIResult(_ result: EnhancedReceiptProcessor.ProcessedReceipt) async {
        // Update recognized data from AI analysis
        rawVendorName = result.vendor.name
        recognizedDate = result.date
        recognizedTotal = result.total
        recognizedText = result.rawText
        
        // Convert line items
        recognizedItems = result.lineItems.map { item in
            return ReceiptItem(
                name: item.description,
                quantity: Double(item.quantity),
                unitPrice: item.unitPrice,
                totalPrice: item.total
            )
        }
        
        // Process vendor recognition
        if let vendor = await vendorManager.processVendorFromReceipt(rawVendorName: result.vendor.name) {
            self.recognizedVendor = vendor
        } else {
            // Vendor not found, prompt user to add it
            self.showNewVendorAlert = true
        }
    }
    
    private func convertToAIAnalysis(_ result: EnhancedReceiptProcessor.ProcessedReceipt) -> AIReceiptAnalysis {
        let vendorInfo = AIReceiptAnalysis.VendorInfo(
            name: result.vendor.name,
            address: result.vendor.address,
            phone: result.vendor.phone,
            confidence: result.vendor.confidence
        )
        
        let lineItems = result.lineItems.map { item in
            AIReceiptAnalysis.LineItemInfo(
                description: item.description,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                total: item.total,
                category: item.category
            )
        }
        
        return AIReceiptAnalysis(
            vendor: vendorInfo,
            date: ISO8601DateFormatter().string(from: result.date),
            total: result.total,
            subtotal: result.subtotal,
            tax: result.tax,
            lineItems: lineItems,
            confidence: result.confidence,
            rawText: result.rawText
        )
    }
    
    private func performTraditionalOCR(on image: CGImage) async {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        let requestHandler = VNImageRequestHandler(cgImage: image, options: [:])
        
        do {
            try requestHandler.perform([request])
            
            if let results = request.results, !results.isEmpty {
                var fullText = ""
                
                for observation in results {
                    guard let candidate = observation.topCandidates(1).first else { continue }
                    fullText += candidate.string + "\n"
                }
                
                recognizedText = fullText
                await processRecognizedText()
            }
        } catch {
            errorMessage = "OCR failed: \(error.localizedDescription)"
        }
    }
    
    private func resetScanState() {
        recognizedText = ""
        recognizedVendor = nil
        recognizedDate = nil
        recognizedTotal = nil
        recognizedItems = []
        showNewVendorAlert = false
        rawVendorName = nil
        errorMessage = nil
    }
    
    private func processRecognizedText() async {
        // Extract vendor name
        if let vendorName = extractVendorName() {
            rawVendorName = vendorName
            
            // Try to find the vendor in our database
            if let vendor = await vendorManager.processVendorFromReceipt(rawVendorName: vendorName) {
                self.recognizedVendor = vendor
            } else {
                // Vendor not found, prompt user to add it
                self.showNewVendorAlert = true
            }
        }
        
        // Extract date
        if let date = extractDate() {
            self.recognizedDate = date
        }
        
        // Extract total
        if let total = extractTotal() {
            self.recognizedTotal = total
        }
        
        // Extract line items (simplified for this example)
        extractLineItems()
    }
    
    // MARK: - Extract Receipt Information
    
    private func extractVendorName() -> String? {
        // Try to match using regex pattern first
        if let vendorMatch = try? NSRegularExpression(pattern: vendorPattern)
            .firstMatch(in: recognizedText, range: NSRange(recognizedText.startIndex..., in: recognizedText)),
           let range = Range(vendorMatch.range(at: 1), in: recognizedText) {
            return String(recognizedText[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Fallback - try to get the first line of text if it's short enough to be a vendor name
        let lines = recognizedText.components(separatedBy: .newlines)
        if let firstLine = lines.first, firstLine.count < 30 && !firstLine.isEmpty {
            return firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return nil
    }
    
    private func extractDate() -> Date? {
        // Try to match date pattern
        if let dateMatch = try? NSRegularExpression(pattern: datePattern)
            .firstMatch(in: recognizedText, range: NSRange(recognizedText.startIndex..., in: recognizedText)),
           let range = Range(dateMatch.range(at: 1), in: recognizedText) {
            
            let dateString = String(recognizedText[range])
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MM/dd/yyyy"
            
            // Try different date formats
            for format in ["MM/dd/yyyy", "M/d/yyyy", "MM-dd-yyyy", "M-d-yyyy", "MM/dd/yy", "M/d/yy"] {
                dateFormatter.dateFormat = format
                if let date = dateFormatter.date(from: dateString) {
                    return date
                }
            }
        }
        
        return nil
    }
    
    private func extractTotal() -> Double? {
        // Try to match total pattern
        if let totalMatch = try? NSRegularExpression(pattern: totalPattern)
            .firstMatch(in: recognizedText, range: NSRange(recognizedText.startIndex..., in: recognizedText)),
           let range = Range(totalMatch.range(at: 1), in: recognizedText) {
            
            let totalString = String(recognizedText[range])
            return Double(totalString)
        }
        
        return nil
    }
    
    private func extractLineItems() {
        // This is a simplified implementation
        // In a real app, you would use more sophisticated techniques to identify line items
        
        let lines = recognizedText.components(separatedBy: .newlines)
        var items: [ReceiptItem] = []
        
        for line in lines {
            // Skip short lines and lines that are likely headers
            if line.count < 5 || line.lowercased().contains("total") || line.lowercased().contains("date") {
                continue
            }
            
            // Try to extract quantity and price
            // This is a very basic implementation that assumes format: "Item name $price" or "Item name quantity $price"
            if let priceMatch = try? NSRegularExpression(pattern: "\\$?(\\d+\\.\\d{2})")
                .firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
               let priceRange = Range(priceMatch.range(at: 1), in: line) {
                
                let price = Double(line[priceRange]) ?? 0.0
                
                // Extract the item name (everything before the price)
                let itemName = line[..<priceRange.lowerBound]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\\$?\\d+\\.\\d{2}", with: "", options: .regularExpression)
                
                if !itemName.isEmpty {
                    let item = ReceiptItem(
                        name: String(itemName),
                        quantity: 1.0,
                        unitPrice: price,
                        totalPrice: price
                    )
                    items.append(item)
                }
            }
        }
        
        recognizedItems = items
    }
    
    // MARK: - Vendor Management
    
    func approveNewVendor() async {
        guard let vendorName = rawVendorName, !vendorName.isEmpty else {
            return
        }
        
        // Create and save the new vendor
        if let newVendor = await vendorManager.approveVendor(name: vendorName) {
            self.recognizedVendor = newVendor
            self.showNewVendorAlert = false
        }
    }
    
    // MARK: - Receipt Saving
    
    func saveReceipt() async -> Receipt? {
        guard let modelContext = modelContext else {
            errorMessage = "Model context not available"
            return nil
        }
        
        // Create the receipt
        let receipt = Receipt(
            date: recognizedDate ?? Date(),
            total: recognizedTotal ?? 0.0,
            imageData: scannedImage?.jpegData(compressionQuality: 0.7),
            vendorId: recognizedVendor?.id,
            rawVendorName: rawVendorName,
            vendor: recognizedVendor as AppVendor? // Explicitly cast to AppVendor
        )
        
        // Add the items
        for item in recognizedItems {
            item.receipt = receipt
            receipt.addItem(item)
        }
        
        // Save to database
        modelContext.insert(receipt)
        
        try? modelContext.save()
        return receipt
    }
} 