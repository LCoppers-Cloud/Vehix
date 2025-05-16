import Foundation
import CloudKit
import SwiftData

/// Manages privacy settings and consent for CloudKit sharing
class CloudKitPrivacyManager {
    // Shared instance
    static let shared = CloudKitPrivacyManager()
    
    // User defaults keys
    private enum Keys {
        static let privacyConsentGiven = "cloudkit.privacy.consent.given"
        static let lastPrivacyPromptDate = "cloudkit.privacy.last.prompt.date"
        static let shareInventory = "cloudkit.privacy.share.inventory"
        static let sharePrices = "cloudkit.privacy.share.prices"
        static let shareUsageData = "cloudkit.privacy.share.usage"
        static let shareLocations = "cloudkit.privacy.share.locations"
        static let privacyVersion = "cloudkit.privacy.version"
    }
    
    // Current privacy policy version
    private let currentPrivacyVersion = 1
    
    // The time interval between privacy consent prompts (90 days)
    private let privacyPromptInterval: TimeInterval = 90 * 24 * 60 * 60
    
    private init() {}
    
    /// Check if the user has given consent to share data
    var hasUserGivenConsent: Bool {
        return UserDefaults.standard.bool(forKey: Keys.privacyConsentGiven)
    }
    
    /// The current privacy policy version the user has consented to
    var consented​PolicyVersion: Int {
        return UserDefaults.standard.integer(forKey: Keys.privacyVersion)
    }
    
    /// Check if user should be prompted for consent again
    var shouldPromptForConsent: Bool {
        // If consent has never been given, we should prompt
        if !hasUserGivenConsent {
            return true
        }
        
        // If the privacy policy version has changed, we should prompt
        if consented​PolicyVersion < currentPrivacyVersion {
            return true
        }
        
        // Check if the prompt interval has passed
        if let lastPromptDate = UserDefaults.standard.object(forKey: Keys.lastPrivacyPromptDate) as? Date {
            let now = Date()
            return now.timeIntervalSince(lastPromptDate) > privacyPromptInterval
        }
        
        return false
    }
    
    /// Set user consent for data sharing
    /// - Parameters:
    ///   - consent: Whether the user has consented
    ///   - shareInventory: Whether to share inventory data
    ///   - sharePrices: Whether to share pricing information
    ///   - shareUsageData: Whether to share usage data
    func setUserConsent(consent: Bool, 
                       shareInventory: Bool = false,
                       sharePrices: Bool = false, 
                       shareUsageData: Bool = false,
                       shareLocations: Bool = false) {
        UserDefaults.standard.set(consent, forKey: Keys.privacyConsentGiven)
        UserDefaults.standard.set(Date(), forKey: Keys.lastPrivacyPromptDate)
        UserDefaults.standard.set(currentPrivacyVersion, forKey: Keys.privacyVersion)
        
        // Only save sharing preferences if user has consented
        if consent {
            UserDefaults.standard.set(shareInventory, forKey: Keys.shareInventory)
            UserDefaults.standard.set(sharePrices, forKey: Keys.sharePrices)
            UserDefaults.standard.set(shareUsageData, forKey: Keys.shareUsageData)
            UserDefaults.standard.set(shareLocations, forKey: Keys.shareLocations)
        } else {
            // If consent is revoked, disable all sharing
            UserDefaults.standard.set(false, forKey: Keys.shareInventory)
            UserDefaults.standard.set(false, forKey: Keys.sharePrices)
            UserDefaults.standard.set(false, forKey: Keys.shareUsageData)
            UserDefaults.standard.set(false, forKey: Keys.shareLocations)
        }
    }
    
    /// Check if inventory sharing is enabled
    var shouldShareInventory: Bool {
        return hasUserGivenConsent && UserDefaults.standard.bool(forKey: Keys.shareInventory)
    }
    
    /// Check if price sharing is enabled
    var shouldSharePrices: Bool {
        return hasUserGivenConsent && UserDefaults.standard.bool(forKey: Keys.sharePrices)
    }
    
    /// Check if usage data sharing is enabled
    var shouldShareUsageData: Bool {
        return hasUserGivenConsent && UserDefaults.standard.bool(forKey: Keys.shareUsageData)
    }
    
    /// Check if location sharing is enabled
    var shouldShareLocations: Bool {
        return hasUserGivenConsent && UserDefaults.standard.bool(forKey: Keys.shareLocations)
    }
    
    /// Sanitize a CloudKit record to remove personal identifiable information
    /// - Parameter record: The CloudKit record to sanitize
    /// - Returns: A sanitized copy of the record
    func sanitizeRecord(_ record: CKRecord) -> CKRecord {
        // Create a copy of the record
        let sanitizedRecord = CKRecord(recordType: record.recordType, recordID: record.recordID)
        
        // Copy over all fields except those that might contain PII
        for key in record.allKeys() {
            // Skip fields that might contain PII
            if isPersonalIdentifiableField(key) {
                continue
            }
            
            // Skip pricing information if user hasn't consented to share it
            if isPricingField(key) && !shouldSharePrices {
                continue
            }
            
            // Skip usage data if user hasn't consented to share it
            if isUsageDataField(key) && !shouldShareUsageData {
                continue
            }
            
            // Skip location data if user hasn't consented to share it
            if isLocationField(key) && !shouldShareLocations {
                continue
            }
            
            // Copy the value
            sanitizedRecord[key] = record[key]
        }
        
        return sanitizedRecord
    }
    
    /// Check if a field might contain personally identifiable information
    /// - Parameter fieldName: The name of the field to check
    /// - Returns: Whether the field might contain PII
    private func isPersonalIdentifiableField(_ fieldName: String) -> Bool {
        let piiFields = [
            "email", "phone", "address", "name", "firstName", "lastName",
            "fullName", "ssn", "taxId", "driverId", "license", "userId",
            "password", "secret", "apiKey", "token", "identifier", "personal"
        ]
        
        return piiFields.contains { fieldName.lowercased().contains($0.lowercased()) }
    }
    
    /// Check if a field contains pricing information
    /// - Parameter fieldName: The name of the field to check
    /// - Returns: Whether the field contains pricing information
    private func isPricingField(_ fieldName: String) -> Bool {
        let pricingFields = [
            "price", "cost", "value", "fee", "charge", "pricePerUnit", "totalValue"
        ]
        
        return pricingFields.contains { fieldName.lowercased().contains($0.lowercased()) }
    }
    
    /// Check if a field contains usage data
    /// - Parameter fieldName: The name of the field to check
    /// - Returns: Whether the field contains usage data
    private func isUsageDataField(_ fieldName: String) -> Bool {
        let usageFields = [
            "quantity", "usage", "used", "count", "frequency", "lastUse",
            "lastUsed", "useCount", "usageStats", "stats"
        ]
        
        return usageFields.contains { fieldName.lowercased().contains($0.lowercased()) }
    }
    
    /// Check if a field contains location information
    /// - Parameter fieldName: The name of the field to check
    /// - Returns: Whether the field contains location information
    private func isLocationField(_ fieldName: String) -> Bool {
        let locationFields = [
            "location", "latitude", "longitude", "coordinate", "gps",
            "position", "address", "city", "state", "zip", "country",
            "lastKnownLocation", "locationLastUpdated"
        ]
        
        return locationFields.contains { fieldName.lowercased().contains($0.lowercased()) }
    }
    
    /// The privacy policy text for CloudKit data sharing
    var privacyPolicyText: String {
        return """
        Privacy Policy for Data Sharing

        Vehix collects and shares certain data to improve the app experience. Here's how we handle your data:

        - Inventory Data: Part numbers, descriptions, and categories may be shared with other Vehix users to build a comprehensive parts catalog.
        
        - Pricing Information: If enabled, cost information for parts may be shared anonymously to help other users estimate costs.
        
        - Usage Data: If enabled, anonymized usage statistics may be shared to improve inventory recommendations.
        
        - Location Data: If enabled, service location information may be shared anonymously.

        All data is anonymized before sharing. No personal identifiable information is ever shared.

        You can change your sharing preferences at any time through the Settings screen.
        
        By enabling data sharing, you are helping build a better community resource for all Vehix users.
        """
    }
} 