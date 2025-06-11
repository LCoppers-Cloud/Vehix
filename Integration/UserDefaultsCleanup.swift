import Foundation
import UIKit

/// Utility class to clean up UserDefaults data that was causing storage violations
class UserDefaultsCleanup {
    
    /// Clean up all large data from UserDefaults
    static func performCleanup() {
        cleanupReceiptImages()
        cleanupVendorExtendedData()
        cleanupOldSessionData()
        
        print("✅ UserDefaults cleanup completed")
    }
    
    /// Remove receipt images from UserDefaults (now stored in files)
    private static func cleanupReceiptImages() {
        let defaults = UserDefaults.standard
        let allKeys = defaults.dictionaryRepresentation().keys
        
        var cleanedCount = 0
        for key in allKeys {
            if key.hasPrefix("po_draft_receipt_") {
                defaults.removeObject(forKey: key)
                cleanedCount += 1
            }
        }
        
        if cleanedCount > 0 {
            print("🧹 Cleaned up \(cleanedCount) receipt image entries from UserDefaults")
        }
    }
    
    /// Remove vendor extended data from UserDefaults (now stored in files)
    private static func cleanupVendorExtendedData() {
        let defaults = UserDefaults.standard
        let allKeys = defaults.dictionaryRepresentation().keys
        
        var cleanedCount = 0
        for key in allKeys {
            if key.hasPrefix("vendor_extended_") {
                defaults.removeObject(forKey: key)
                cleanedCount += 1
            }
        }
        
        if cleanedCount > 0 {
            print("🧹 Cleaned up \(cleanedCount) vendor extended data entries from UserDefaults")
        }
    }
    
    /// Remove any other large data that might be accumulating
    private static func cleanupOldSessionData() {
        let defaults = UserDefaults.standard
        let allKeys = defaults.dictionaryRepresentation().keys
        
        var cleanedCount = 0
        for key in allKeys {
            // Clean up any keys that might contain large data
            if key.contains("_cached_") || 
               key.contains("_temp_") || 
               key.hasPrefix("large_data_") ||
               key.contains("_session_data") {
                defaults.removeObject(forKey: key)
                cleanedCount += 1
            }
        }
        
        if cleanedCount > 0 {
            print("🧹 Cleaned up \(cleanedCount) temporary data entries from UserDefaults")
        }
    }
    
    /// Check UserDefaults size and warn if approaching limits
    static func checkUserDefaultsSize() {
        let defaults = UserDefaults.standard
        let allData = defaults.dictionaryRepresentation()
        
        var totalSize = 0
        var largeKeys: [(String, Int)] = []
        
        for (key, value) in allData {
            var size = 0
            
            // Calculate size based on data type instead of JSON serialization
            if let stringValue = value as? String {
                size = stringValue.data(using: .utf8)?.count ?? 0
            } else if let dataValue = value as? Data {
                size = dataValue.count
            } else if let arrayValue = value as? [Any] {
                // Estimate array size
                size = arrayValue.count * 100 // rough estimate
            } else if let dictValue = value as? [String: Any] {
                // Estimate dictionary size
                size = dictValue.count * 200 // rough estimate
            } else if let numberValue = value as? NSNumber {
                size = MemoryLayout.size(ofValue: numberValue)
            } else {
                // For other types, estimate based on description
                size = String(describing: value).count * 2
            }
            
            totalSize += size
            
            if size > 1024 { // More than 1KB
                largeKeys.append((key, size))
            }
        }
        
        largeKeys.sort { $0.1 > $1.1 }
        
        print("📊 UserDefaults total size: \(totalSize) bytes (\(String(format: "%.2f", Double(totalSize) / 1024.0 / 1024.0)) MB)")
        
        if totalSize > 3 * 1024 * 1024 { // 3MB warning threshold
            print("⚠️ UserDefaults approaching 4MB limit!")
        }
        
        if !largeKeys.isEmpty {
            print("🔍 Largest UserDefaults entries:")
            for (key, size) in largeKeys.prefix(5) {
                print("  - \(key): \(size) bytes")
            }
        }
    }
} 