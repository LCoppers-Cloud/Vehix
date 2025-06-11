import Foundation
import SwiftData
import StoreKit
import CloudKit

// MARK: - Environment Support

/**
 This file provides extensions to service classes to add environment-specific support.
 In production builds, all services use real implementations.
 
 PRODUCTION MODE: All mock implementations removed.
 Services now initialize with real implementations only.
 */

// MARK: - AppAuthService Extension
extension AppAuthService {
    /// Initialize - PRODUCTION MODE: No mock data, ever
    convenience init(useMockData: Bool) {
        self.init()
        
        // PRODUCTION MODE: Never use mock data
        // All users must authenticate normally through the app
        // No auto-login, no pre-created accounts, no sample data
    }
}

// MARK: - ServiceTitanService Extension
extension ServiceTitanService {
    /// Initialize with model context - PRODUCTION MODE: Real integration only
    convenience init(modelContext: ModelContext, isSimulatorEnvironment: Bool) {
        self.init()
        self.modelContext = modelContext
        
        // PRODUCTION MODE: Always use real ServiceTitan integration
        // No mock connections, users must configure real API credentials
    }
}

// MARK: - SamsaraService Extension
extension SamsaraService {
    /// Initialize with model context - PRODUCTION MODE: Real integration only
    convenience init(modelContext: ModelContext, isSimulatorEnvironment: Bool) {
        self.init()
        self.modelContext = modelContext
        
        // PRODUCTION MODE: Always use real Samsara integration
        // No mock connections, users must configure real API credentials
    }
}

// MARK: - CloudKitManager Extension
extension CloudKitManager {
    /// Initialize with model context - PRODUCTION MODE: Real CloudKit only
    convenience init(modelContext: ModelContext, isSimulatorEnvironment: Bool) {
        self.init()
        self.modelContext = modelContext
        
        // PRODUCTION MODE: Always use real CloudKit
        // No mock cloud storage, uses actual iCloud integration
    }
}

// MARK: - StoreKitManager Extension
extension StoreKitManager {
    /// Initialize - PRODUCTION MODE: Real StoreKit only
    convenience init(isSimulatorEnvironment: Bool) {
        self.init()
        
        // PRODUCTION MODE: Always try to fetch real products
        // No mock purchases, uses actual App Store transactions
        Task {
            await fetchProducts()
        }
    }
} 