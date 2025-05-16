import Foundation
import CoreML
import Vision
import CloudKit
import SwiftData
import SwiftUI

@MainActor
class VendorRecognitionManager: ObservableObject {
    @Published var isLoading = false
    @Published var vendorList: [AppVendor] = []
    @Published var suggestedVendor: AppVendor?
    @Published var errorMessage: String?
    
    private let publicDB = CKContainer(identifier: "iCloud.com.lcoppers.Vehix").publicCloudDatabase
    private var modelContext: ModelContext?
    
    // Confidence threshold for ML model predictions
    private let confidenceThreshold: VNConfidence = 0.8
    
    // Lazy-loaded ML model
    lazy var vendorModel: MLModel? = {
        do {
            // Load the model from the app bundle
            let config = MLModelConfiguration()
            guard let modelURL = Bundle.main.url(forResource: "VendorClassifier", withExtension: "mlmodel") else {
                print("VendorClassifier.mlmodel not found in bundle")
                return nil
            }
            return try MLModel(contentsOf: modelURL, configuration: config)
        } catch {
            print("Failed to load VendorClassifier model: \(error)")
            return nil
        }
    }()
    
    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
        
        // Setup subscription for new vendor notifications
        setupVendorSubscription()
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    // MARK: - Vendor Recognition
    
    /// Classify a raw vendor name using the ML model
    func classifyVendor(rawText: String) async -> (vendorId: String?, confidence: VNConfidence) {
        guard let model = vendorModel else {
            return (nil, 0)
        }
        
        // For direct model prediction (faster than Vision pipeline for text)
        do {
            let input = try MLDictionaryFeatureProvider(dictionary: ["text": rawText as NSString])
            let prediction = try await model.prediction(from: input)
            
            if let label = prediction.featureValue(for: "label")?.stringValue,
               let confidenceDict = prediction.featureValue(for: "labelProbability")?.dictionaryValue,
               let confidence = confidenceDict[label] as? Double {
                
                return (label, VNConfidence(confidence))
            }
        } catch {
            print("ML prediction error: \(error)")
        }
        
        return (nil, 0)
    }
    
    /// Process a vendor name from a receipt
    func processVendorFromReceipt(rawVendorName: String) async -> AppVendor? {
        guard !rawVendorName.isEmpty else { return nil }
        
        await loadVendors()
        
        // Clean up the vendor name for matching
        let cleanedName = rawVendorName.trimmingCharacters(in: .whitespacesAndNewlines)
                                      .lowercased()
        
        // Look for exact match first
        for vendor in vendorList {
            if vendor.name.lowercased() == cleanedName {
                return vendor
            }
        }
        
        // Look for partial matches
        for vendor in vendorList {
            if vendor.name.lowercased().contains(cleanedName) || cleanedName.contains(vendor.name.lowercased()) {
                return vendor
            }
        }
        
        return nil
    }
    
    // MARK: - Vendor Data Management
    
    /// Fetch all vendors from the local database
    @MainActor
    func loadVendors() async {
        guard let modelContext = modelContext else {
            errorMessage = "Model context not available"
            return
        }
        
        isLoading = true
        
        do {
            let descriptor = FetchDescriptor<AppVendor>(sortBy: [SortDescriptor(\.name)])
            vendorList = try modelContext.fetch(descriptor)
            isLoading = false
        } catch {
            errorMessage = "Failed to load vendors: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    /// Fetch all vendors from CloudKit public database
    @MainActor
    func fetchVendorsFromCloudKit() async {
        guard let modelContext = modelContext else {
            errorMessage = "Model context not available"
            return
        }
        
        isLoading = true
        
        // In a real app, this would connect to CloudKit
        // For this example, we'll simulate by creating some vendors
        do {
            // Check if we already have vendors
            let descriptor = FetchDescriptor<AppVendor>()
            let existingVendors = try modelContext.fetch(descriptor)
            
            // Only add sample vendors if we don't have any
            if existingVendors.isEmpty {
                let sampleVendors = [
                    AppVendor(name: "Johnson Supply Co.", email: "sales@johnsonsupply.com", phone: "555-123-4567"),
                    AppVendor(name: "Midwest Parts Distributors", email: "orders@midwestparts.com", phone: "555-987-6543"),
                    AppVendor(name: "Quality HVAC Supplies", email: "info@qualityhvac.com", phone: "555-456-7890"),
                    AppVendor(name: "Elite Plumbing Products", email: "support@eliteplumbing.com", phone: "555-789-0123"),
                    AppVendor(name: "Tech Tools & Equipment", email: "sales@techtools.com", phone: "555-234-5678")
                ]
                
                for vendor in sampleVendors {
                    modelContext.insert(vendor)
                }
                
                try modelContext.save()
            }
            
            // Load the vendors (including any new ones)
            await loadVendors()
        } catch {
            errorMessage = "Failed to sync vendors: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Add and approve a new vendor
    @MainActor
    func approveVendor(name: String) async -> AppVendor? {
        guard let modelContext = modelContext else {
            errorMessage = "Model context not available"
            return nil
        }
        
        // Normalize vendor name
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if vendor already exists
        do {
            // Instead of using #Predicate with lowercased(), we'll do a case-insensitive
            // comparison manually since lowercased() isn't supported in predicates in iOS 18+
            let descriptor = FetchDescriptor<AppVendor>()
            let existingVendors = try modelContext.fetch(descriptor)
            
            // Find any vendor with the same name (case-insensitive)
            for vendor in existingVendors {
                if vendor.name.lowercased() == normalizedName.lowercased() {
                    return vendor
                }
            }
            
            // Create a new vendor
            let newVendor = AppVendor(
                name: normalizedName,
                email: "",  // Empty email for now
                isActive: true
            )
            
            modelContext.insert(newVendor)
            try modelContext.save()
            
            // Refresh vendor list and return the new vendor
            await loadVendors()
            return newVendor
        } catch {
            errorMessage = "Failed to create vendor: \(error.localizedDescription)"
            return nil
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupVendorSubscription() {
        // Create a subscription for new vendor notifications
        let subscription = CKQuerySubscription(
            recordType: "Vendor",
            predicate: NSPredicate(value: true),
            subscriptionID: "new-vendor-subscription",
            options: [.firesOnRecordCreation]
        )
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.alertBody = "A new vendor was added to the database"
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        
        // Save the subscription
        publicDB.save(subscription) { _, error in
            if let error = error {
                print("Failed to create vendor subscription: \(error)")
            } else {
                print("Vendor subscription created successfully")
            }
        }
    }
    
    private func getVendorById(id: String) async -> AppVendor? {
        guard let modelContext = modelContext else {
            return nil
        }
        
        do {
            // For iOS 18+ compatibility, use a descriptor without predicate and filter locally
            let descriptor = FetchDescriptor<AppVendor>()
            let vendors = try modelContext.fetch(descriptor)
            return vendors.first { $0.id == id }
        } catch {
            print("Failed to get vendor by ID: \(error)")
            return nil
        }
    }
    
    private func findSimilarVendor(name: String) async -> AppVendor? {
        // Simple string similarity check
        // In a real app, you might use a more sophisticated algorithm
        let lowercaseName = name.lowercased()
        
        for vendor in vendorList {
            if vendor.name.lowercased().contains(lowercaseName) ||
               lowercaseName.contains(vendor.name.lowercased()) {
                return vendor
            }
        }
        
        return nil
    }
    
    private func saveVendorsToLocalDB(vendors: [AppVendor]) async {
        guard let modelContext = modelContext else {
            return
        }
        
        for vendor in vendors {
            // For iOS 18+ compatibility, fetch all and filter locally
            let descriptor = FetchDescriptor<AppVendor>()
            
            do {
                let existingVendors = try modelContext.fetch(descriptor)
                let matchingVendor = existingVendors.first(where: { $0.id == vendor.id })
                
                if let existingVendor = matchingVendor {
                    // Update existing vendor
                    existingVendor.name = vendor.name
                    // Add other properties to update as needed
                } else {
                    // Insert new vendor
                    modelContext.insert(vendor)
                }
            } catch {
                print("Error saving vendor: \(error)")
            }
        }
        
        // Save changes
        do {
            try modelContext.save()
        } catch {
            print("Error saving context: \(error)")
        }
    }
} 