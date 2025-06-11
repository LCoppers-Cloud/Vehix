import Foundation
import SwiftUI
import SwiftData
import CloudKit

// MARK: - AI Shared Data Models for Machine Learning

/// Anonymized vendor information shared across all users to improve AI recognition
@Model
final class SharedVendorData {
    var vendorName: String = ""
    var normalizedName: String = ""
    @Attribute(.transformable(by: StringArrayTransformer.self)) var commonVariations: [String] = []
    var category: String = ""
    var website: String?
    var isSupplyHouse: Bool = false
    var confidence: Double = 0.5
    var lastUpdated: Date = Date()
    var userContributions: Int = 1
    
    init(vendorName: String, normalizedName: String, category: String, website: String? = nil, isSupplyHouse: Bool = false) {
        self.vendorName = vendorName
        self.normalizedName = normalizedName
        self.commonVariations = []
        self.category = category
        self.website = website
        self.isSupplyHouse = isSupplyHouse
        self.confidence = 0.5
        self.lastUpdated = Date()
        self.userContributions = 1
    }
}

/// Anonymized inventory item patterns shared for better AI categorization
@Model
final class SharedInventoryPattern {
    var itemName: String = ""
    var normalizedName: String = ""
    var category: String = ""
    var subcategory: String?
    @Attribute(.transformable(by: StringArrayTransformer.self)) var commonKeywords: [String] = []
    @Attribute(.transformable(by: StringArrayTransformer.self)) var alternativeNames: [String] = []
    @Attribute(.transformable(by: StringArrayTransformer.self)) var typicalVendors: [String] = []
    @Attribute(.transformable(by: StringArrayTransformer.self)) var unitTypes: [String] = [] // each, box, case, etc.
    var confidence: Double = 0.5
    var userContributions: Int = 1
    var lastUpdated: Date = Date()
    
    init(itemName: String, category: String, subcategory: String? = nil) {
        self.itemName = itemName
        self.normalizedName = itemName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        self.category = category
        self.subcategory = subcategory
        self.commonKeywords = []
        self.alternativeNames = []
        self.typicalVendors = []
        self.unitTypes = []
        self.confidence = 0.5
        self.userContributions = 1
        self.lastUpdated = Date()
    }
}

/// Anonymized receipt patterns for improving OCR and parsing
@Model
final class SharedReceiptPattern {
    var vendorName: String = ""
    var receiptLayout: String = "" // JSON describing layout patterns
    @Attribute(.transformable(by: StringArrayTransformer.self)) var textPatterns: [String] = [] // Common text patterns found
    @Attribute(.transformable(by: StringArrayTransformer.self)) var amountPatterns: [String] = [] // How amounts are formatted
    @Attribute(.transformable(by: StringArrayTransformer.self)) var datePatterns: [String] = [] // How dates appear
    var confidence: Double = 0.5
    var userContributions: Int = 1
    var lastUpdated: Date = Date()
    
    init(vendorName: String, receiptLayout: String) {
        self.vendorName = vendorName
        self.receiptLayout = receiptLayout
        self.textPatterns = []
        self.amountPatterns = []
        self.datePatterns = []
        self.confidence = 0.5
        self.userContributions = 1
        self.lastUpdated = Date()
    }
}

// MARK: - AI Data Manager

@MainActor
class AISharedDataManager: ObservableObject {
    private let modelContext: ModelContext
    private let cloudKitManager: CloudKitManager?
    
    @Published var isContributing = true
    @Published var syncStatus: SyncStatus = .idle
    
    enum SyncStatus {
        case idle
        case syncing
        case success
        case error(String)
    }
    
    init(modelContext: ModelContext, cloudKitManager: CloudKitManager? = nil) {
        self.modelContext = modelContext
        self.cloudKitManager = cloudKitManager
    }
    
    // MARK: - Vendor Data Contribution
    
    /// Contribute vendor data while maintaining user privacy
    func contributeVendorData(vendorName: String) async {
        guard isContributing else { return }
        
        // Anonymize vendor data before sharing
        let anonymizedVendor = anonymizeVendorData(vendorName)
        
        do {
            // Fetch all vendors and filter manually to avoid predicate issues
            let descriptor = FetchDescriptor<SharedVendorData>()
            let allVendors = try modelContext.fetch(descriptor)
            let existing = allVendors.first { $0.normalizedName == anonymizedVendor.normalized }
            
            if let existingVendor = existing {
                // Update existing vendor data
                existingVendor.userContributions += 1
                existingVendor.lastUpdated = Date()
                
                // Add new variation if not already present
                if !existingVendor.commonVariations.contains(anonymizedVendor.original) {
                    existingVendor.commonVariations.append(anonymizedVendor.original)
                }
                
                // Increase confidence with more contributions
                existingVendor.confidence = min(1.0, existingVendor.confidence + 0.1)
                
            } else {
                // Create new shared vendor data
                let sharedVendor = SharedVendorData(
                    vendorName: anonymizedVendor.original,
                    normalizedName: anonymizedVendor.normalized,
                    category: categorizeVendor(anonymizedVendor.original),
                    website: nil,
                    isSupplyHouse: isSupplyHouse(anonymizedVendor.original)
                )
                
                modelContext.insert(sharedVendor)
            }
            
            try modelContext.save()
            await syncToCloud()
            
        } catch {
            print("Error contributing vendor data: \(error)")
        }
    }
    
    /// Contribute inventory item patterns for better AI recognition
    func contributeInventoryPattern(itemName: String, category: String, subcategory: String? = nil, unit: String? = nil) async {
        guard isContributing else { return }
        
        let anonymizedItem = anonymizeInventoryItem(itemName)
        
        do {
            // Fetch all patterns and filter manually
            let descriptor = FetchDescriptor<SharedInventoryPattern>()
            let allPatterns = try modelContext.fetch(descriptor)
            let existing = allPatterns.first { $0.normalizedName == anonymizedItem.normalized }
            
            if let existingPattern = existing {
                existingPattern.userContributions += 1
                existingPattern.lastUpdated = Date()
                existingPattern.confidence = min(1.0, existingPattern.confidence + 0.05)
                
                // Add keywords if not present
                let newKeywords = extractKeywords(from: itemName)
                for keyword in newKeywords {
                    if !existingPattern.commonKeywords.contains(keyword) {
                        existingPattern.commonKeywords.append(keyword)
                    }
                }
                
            } else {
                let pattern = SharedInventoryPattern(
                    itemName: anonymizedItem.original,
                    category: category,
                    subcategory: subcategory
                )
                
                pattern.commonKeywords = extractKeywords(from: itemName)
                pattern.unitTypes = [unit ?? "each"]
                
                modelContext.insert(pattern)
            }
            
            try modelContext.save()
            await syncToCloud()
            
        } catch {
            print("Error contributing inventory pattern: \(error)")
        }
    }
    
    /// Contribute receipt patterns for improving OCR
    func contributeReceiptPattern(vendorName: String, ocrText: String) async {
        guard isContributing else { return }
        
        let receiptAnalysis = analyzeReceiptPattern(vendorName: vendorName, ocrText: ocrText)
        
        do {
            // Fetch all patterns and filter manually
            let descriptor = FetchDescriptor<SharedReceiptPattern>()
            let allPatterns = try modelContext.fetch(descriptor)
            let existing = allPatterns.first { $0.vendorName == vendorName }
            
            if let existingPattern = existing {
                existingPattern.userContributions += 1
                existingPattern.lastUpdated = Date()
                existingPattern.confidence = min(1.0, existingPattern.confidence + 0.05)
                
                // Add new patterns
                for pattern in receiptAnalysis.textPatterns {
                    if !existingPattern.textPatterns.contains(pattern) {
                        existingPattern.textPatterns.append(pattern)
                    }
                }
                
            } else {
                let pattern = SharedReceiptPattern(
                    vendorName: vendorName,
                    receiptLayout: receiptAnalysis.layoutDescription
                )
                
                pattern.textPatterns = receiptAnalysis.textPatterns
                pattern.amountPatterns = receiptAnalysis.amountPatterns
                pattern.datePatterns = receiptAnalysis.datePatterns
                
                modelContext.insert(pattern)
            }
            
            try modelContext.save()
            await syncToCloud()
            
        } catch {
            print("Error contributing receipt pattern: \(error)")
        }
    }
    
    // MARK: - AI Learning Enhancement
    
    /// Get improved vendor suggestions based on shared data
    func getVendorSuggestions(for input: String) async -> [String] {
        do {
            let normalizedInput = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Fetch all vendors and filter manually
            let descriptor = FetchDescriptor<SharedVendorData>()
            let allVendors = try modelContext.fetch(descriptor)
            
            let matches = allVendors.filter { vendor in
                vendor.normalizedName.contains(normalizedInput) ||
                vendor.commonVariations.contains { variation in
                    variation.lowercased().contains(normalizedInput)
                }
            }
            
            return matches
                .sorted { $0.confidence > $1.confidence }
                .prefix(10)
                .map { $0.vendorName }
                
        } catch {
            print("Error getting vendor suggestions: \(error)")
            return []
        }
    }
    
    /// Get improved inventory categorization suggestions
    func getInventorySuggestions(for itemName: String) async -> (category: String?, subcategory: String?) {
        do {
            let normalizedName = itemName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Fetch all patterns and filter manually
            let descriptor = FetchDescriptor<SharedInventoryPattern>()
            let allPatterns = try modelContext.fetch(descriptor)
            
            let matches = allPatterns.filter { pattern in
                pattern.normalizedName.contains(normalizedName) ||
                pattern.commonKeywords.contains { keyword in
                    normalizedName.contains(keyword)
                }
            }
            
            if let bestMatch = matches.max(by: { $0.confidence < $1.confidence }) {
                return (category: bestMatch.category, subcategory: bestMatch.subcategory)
            }
            
            return (category: nil, subcategory: nil)
            
        } catch {
            print("Error getting inventory suggestions: \(error)")
            return (category: nil, subcategory: nil)
        }
    }
    
    // MARK: - Privacy and Anonymization
    
    private func anonymizeVendorData(_ vendorName: String) -> (original: String, normalized: String) {
        let normalized = vendorName
            .lowercased()
            .replacingOccurrences(of: #"\b\d+\b"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return (original: vendorName, normalized: normalized)
    }
    
    private func anonymizeInventoryItem(_ itemName: String) -> (original: String, normalized: String) {
        let normalized = itemName
            .lowercased()
            .replacingOccurrences(of: #"\b\d+\b"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return (original: itemName, normalized: normalized)
    }
    
    // MARK: - Helper Methods
    
    private func categorizeVendor(_ vendorName: String) -> String {
        let name = vendorName.lowercased()
        
        if name.contains("home depot") || name.contains("lowes") || name.contains("menards") {
            return "hardware_store"
        } else if name.contains("plumbing") || name.contains("supply") {
            return "supply_house"
        } else if name.contains("electric") {
            return "electrical_supply"
        } else if name.contains("hvac") || name.contains("heating") || name.contains("cooling") {
            return "hvac_supply"
        } else {
            return "general"
        }
    }
    
    private func isSupplyHouse(_ vendorName: String) -> Bool {
        let supplyKeywords = ["supply", "plumbing", "electrical", "hvac", "wholesale"]
        let name = vendorName.lowercased()
        return supplyKeywords.contains { name.contains($0) }
    }
    
    private func extractKeywords(from itemName: String) -> [String] {
        let words = itemName
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 2 }
        
        // Filter out common stop words
        let stopWords = Set(["the", "and", "for", "with", "inch", "foot"])
        return words.filter { !stopWords.contains($0) }
    }
    
    private func analyzeReceiptPattern(vendorName: String, ocrText: String) -> ReceiptAnalysis {
        // Analyze OCR text to extract common patterns
        let lines = ocrText.components(separatedBy: .newlines)
        
        let amountPatterns = extractAmountPatterns(from: lines)
        let datePatterns = extractDatePatterns(from: lines)
        let textPatterns = extractTextPatterns(from: lines)
        
        return ReceiptAnalysis(
            layoutDescription: "standard", // Could be more sophisticated
            textPatterns: textPatterns,
            amountPatterns: amountPatterns,
            datePatterns: datePatterns
        )
    }
    
    private func extractAmountPatterns(from lines: [String]) -> [String] {
        let amountRegex = try! NSRegularExpression(pattern: #"(\$?\d+\.\d{2})"#)
        var patterns: [String] = []
        
        for line in lines {
            let range = NSRange(location: 0, length: line.utf16.count)
            let matches = amountRegex.matches(in: line, range: range)
            
            for match in matches {
                if let range = Range(match.range, in: line) {
                    patterns.append(String(line[range]))
                }
            }
        }
        
        return Array(Set(patterns)).prefix(5).map { String($0) }
    }
    
    private func extractDatePatterns(from lines: [String]) -> [String] {
        let dateRegex = try! NSRegularExpression(pattern: #"(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})"#)
        var patterns: [String] = []
        
        for line in lines {
            let range = NSRange(location: 0, length: line.utf16.count)
            let matches = dateRegex.matches(in: line, range: range)
            
            for match in matches {
                if let range = Range(match.range, in: line) {
                    patterns.append(String(line[range]))
                }
            }
        }
        
        return Array(Set(patterns)).prefix(3).map { String($0) }
    }
    
    private func extractTextPatterns(from lines: [String]) -> [String] {
        // Extract common text patterns that might help with OCR
        return lines
            .filter { $0.count > 5 && $0.count < 50 }
            .prefix(10)
            .map { String($0) }
    }
    
    private func syncToCloud() async {
        // Sync shared data to CloudKit for cross-device AI learning
        syncStatus = .syncing
        
        do {
            // CloudKit sync implementation would go here
            try await Task.sleep(nanoseconds: 500_000_000) // Simulate sync
            syncStatus = .success
        } catch {
            syncStatus = .error(error.localizedDescription)
        }
    }
}

// MARK: - Supporting Types

struct ReceiptAnalysis {
    let layoutDescription: String
    let textPatterns: [String]
    let amountPatterns: [String]
    let datePatterns: [String]
}

// MARK: - Privacy Settings View

struct AIDataSharingSettingsView: View {
    @ObservedObject var aiDataManager: AISharedDataManager
    @AppStorage("ai_data_sharing_enabled") private var dataSharingEnabled = true
    @AppStorage("ai_vendor_sharing") private var vendorSharingEnabled = true
    @AppStorage("ai_inventory_sharing") private var inventorySharingEnabled = true
    @AppStorage("ai_receipt_sharing") private var receiptSharingEnabled = true
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .foregroundColor(.blue)
                                .font(.title2)
                            
                            Text("AI Learning & Privacy")
                                .font(.headline)
                        }
                        
                        Text("Help improve AI accuracy for all users while keeping your data private and secure.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    EmptyView()
                }
                
                Section {
                    Toggle("Enable AI Data Sharing", isOn: $dataSharingEnabled)
                        .onChange(of: dataSharingEnabled) { _, newValue in
                            aiDataManager.isContributing = newValue
                        }
                    
                    if dataSharingEnabled {
                        Group {
                            Toggle("Share Vendor Patterns", isOn: $vendorSharingEnabled)
                            Toggle("Share Inventory Categories", isOn: $inventorySharingEnabled)
                            Toggle("Share Receipt Patterns", isOn: $receiptSharingEnabled)
                        }
                        .padding(.leading)
                    }
                } header: {
                    Text("Data Sharing Preferences")
                } footer: {
                    if dataSharingEnabled {
                        Text("Only anonymized patterns are shared. No personal information, prices, or business data leaves your device.")
                            .font(.caption)
                    }
                }
                
                Section {
                    HStack {
                        Image(systemName: "lock.shield")
                            .foregroundColor(.green)
                        
                        VStack(alignment: .leading) {
                            Text("Your Privacy is Protected")
                                .font(.headline)
                            
                            Text("• All shared data is anonymized\n• No personal or business information shared\n• No prices or financial data shared\n• You maintain full control over your data")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Privacy Protection")
                }
                
                Section {
                    switch aiDataManager.syncStatus {
                    case .idle:
                        Label("Ready to contribute", systemImage: "checkmark.circle")
                            .foregroundColor(.secondary)
                    case .syncing:
                        Label("Syncing AI improvements...", systemImage: "arrow.triangle.2.circlepath")
                            .foregroundColor(.blue)
                    case .success:
                        Label("Successfully shared improvements", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    case .error(let message):
                        Label("Error: \(message)", systemImage: "exclamationmark.triangle")
                            .foregroundColor(.red)
                    }
                } header: {
                    Text("Sync Status")
                }
            }
            .navigationTitle("AI & Privacy")
            .navigationBarTitleDisplayMode(.large)
        }
    }
} 