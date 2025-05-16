import Foundation
import SwiftData

/// ServiceTitanConfig stores the configuration for ServiceTitan API integration
@Model
final class ServiceTitanConfig {
    var id: String = UUID().uuidString
    var clientId: String?
    var tenantId: Int64?
    var clientSecret: String? // Kept for backward compatibility, but won't store actual secrets
    var syncInventory: Bool = true
    var syncTechnicians: Bool = true
    var syncVendors: Bool = true
    var syncPurchaseOrders: Bool = true
    var lastSyncDate: Date?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    init(
        id: String = UUID().uuidString,
        clientId: String? = nil,
        tenantId: Int64? = nil,
        clientSecret: String? = nil,
        syncInventory: Bool = true,
        syncTechnicians: Bool = true,
        syncVendors: Bool = true,
        syncPurchaseOrders: Bool = true,
        lastSyncDate: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.clientId = clientId
        self.tenantId = tenantId
        // Don't store client secret in the property
        if let secret = clientSecret {
            setClientSecret(secret)
        }
        self.syncInventory = syncInventory
        self.syncTechnicians = syncTechnicians
        self.syncVendors = syncVendors
        self.syncPurchaseOrders = syncPurchaseOrders
        self.lastSyncDate = lastSyncDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    var isValid: Bool {
        !(clientId?.isEmpty ?? true) && (tenantId ?? 0) > 0 && !getClientSecret().isEmpty
    }
    
    // Helper method to securely store client secret
    func setClientSecret(_ secret: String) {
        // Use KeychainServices to securely store the secret
        let keychainKey = "serviceTitan.clientSecret.\(id)"
        KeychainServices.save(key: keychainKey, value: secret)
        
        // Set a placeholder value to indicate a secret has been stored
        self.clientSecret = "SECURE_STORAGE" // This is just a placeholder
    }
    
    // Helper method to retrieve client secret
    func getClientSecret() -> String {
        let keychainKey = "serviceTitan.clientSecret.\(id)"
        return KeychainServices.get(key: keychainKey) ?? ""
    }
    
    // Validate configuration
    func validate() throws {
        guard !(clientId?.isEmpty ?? true) else {
            throw ServiceTitanError.invalidClientId
        }
        
        guard (tenantId ?? 0) > 0 else {
            throw ServiceTitanError.invalidTenantId
        }
        
        guard !getClientSecret().isEmpty else {
            throw ServiceTitanError.invalidClientSecret
        }
    }
}

// Error types for ServiceTitan integration
enum ServiceTitanError: Error {
    case invalidClientId
    case invalidTenantId
    case invalidClientSecret
    case invalidConfiguration
    case authenticationFailed
    case networkError
    case syncFailed
    
    var errorDescription: String {
        switch self {
        case .invalidClientId:
            return "Invalid client ID"
        case .invalidTenantId:
            return "Invalid tenant ID"
        case .invalidClientSecret:
            return "Invalid client secret"
        case .invalidConfiguration:
            return "Invalid ServiceTitan configuration"
        case .authenticationFailed:
            return "Failed to authenticate with ServiceTitan"
        case .networkError:
            return "Network error occurred"
        case .syncFailed:
            return "Failed to sync with ServiceTitan"
        }
    }
} 