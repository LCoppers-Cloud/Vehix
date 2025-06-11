import Foundation
import Security

/// A utility class for securely storing and retrieving sensitive data using the iOS Keychain
class KeychainServices {
    
    /// Save a string value securely in the Keychain
    /// - Parameters:
    ///   - key: The key to associate with the stored value
    ///   - value: The string value to store securely
    /// - Returns: Whether the operation was successful
    @discardableResult
    static func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            return false
        }
        
        // Prepare the query to check if the item exists
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "com.vehix.app"
        ]
        
        // First, try to delete any existing item with this key
        SecItemDelete(query as CFDictionary)
        
        // Add the new item
        let newItem: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "com.vehix.app",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(newItem as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Retrieve a string value from the Keychain
    /// - Parameter key: The key associated with the stored value
    /// - Returns: The securely stored string, or nil if not found or an error occurred
    static func get(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "com.vehix.app",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }
        
        return nil
    }
    
    /// Remove a value from the Keychain
    /// - Parameter key: The key to remove
    /// - Returns: Whether the operation was successful
    @discardableResult
    static func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "com.vehix.app"
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess
    }
    
    /// Update an existing value in the Keychain
    /// - Parameters:
    ///   - key: The key associated with the value to update
    ///   - value: The new value to store
    /// - Returns: Whether the operation was successful
    @discardableResult
    static func update(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            return false
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "com.vehix.app"
        ]
        
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        // If the item doesn't exist, create it
        if status == errSecItemNotFound {
            return save(key: key, value: value)
        }
        
        return status == errSecSuccess
    }
    
    /// Delete all items in the Keychain for this application
    /// - Returns: Whether the operation was successful
    @discardableResult
    static func deleteAll() -> Bool {
        // Query to find all items for this app
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "com.vehix.app"
        ]
        
        // Delete all matching items
        let status = SecItemDelete(query as CFDictionary)
        
        // errSecSuccess means items were deleted
        // errSecItemNotFound means no items were found (which is also a success for our purpose)
        return status == errSecSuccess || status == errSecItemNotFound
    }
} 