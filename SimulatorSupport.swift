import Foundation
import SwiftData
import StoreKit
import CloudKit

// MARK: - Simulator Environment Helpers

/**
 This file provides extensions to service classes to add simulator environment support
 and mock implementations. This allows the app to run properly in the simulator
 without CloudKit, StoreKit, and other services that require active accounts.
 
 IMPORTANT: This file should only be included in DEBUG builds. In production,
 these mock implementations should be replaced with real service implementations.
 */

// MARK: - AppAuthService Extension
extension AppAuthService {
    /// Initialize with mock data for simulator environment
    convenience init(useMockData: Bool) {
        self.init()
        
        if useMockData {
            print("Using mock authentication service")
            // Set up mock user for immediate testing
            self.isLoggedIn = true
            self.isLoading = false
            
            // Create a test user in the database if modelContext is available
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let context = self.modelContext {
                    // Check if developer account already exists
                    do {
                        // Get all users and filter in memory instead of using predicate
                        let descriptor = FetchDescriptor<AuthUser>()
                        let allUsers = try context.fetch(descriptor)
                        let existingUsers = allUsers.filter { user in
                            user.email == "lornejohn21@yahoo.com"
                        }
                        
                        if existingUsers.isEmpty {
                            // Create developer account if it doesn't exist
                            let developerUser = AuthUser(
                                id: "developer-account-123",
                                email: "lornejohn21@yahoo.com",
                                fullName: "Loren Coppers",
                                role: .admin,
                                isVerified: true
                            )
                            context.insert(developerUser)
                            try context.save()
                            print("Created developer account in database")
                            self.currentUser = developerUser
                        } else {
                            // Use existing developer account
                            self.currentUser = existingUsers.first
                            print("Using existing developer account from database")
                        }
                    } catch {
                        print("Error setting up developer account: \(error)")
                        // Fall back to developer account if database fails
                        self.currentUser = AuthUser(
                            id: "developer-account-123",
                            email: "lornejohn21@yahoo.com",
                            fullName: "Loren Coppers",
                            role: .admin,
                            isVerified: true
                        )
                    }
                } else {
                    // Use in-memory user if no modelContext
                    self.currentUser = AuthUser(
                        id: "developer-account-123",
                        email: "lornejohn21@yahoo.com",
                        fullName: "Loren Coppers",
                        role: .admin,
                        isVerified: true
                    )
                    print("No modelContext available - using in-memory developer account")
                }
            }
        }
    }
}

// MARK: - ServiceTitanService Extension
extension ServiceTitanService {
    /// Initialize with model context and simulator environment flag
    convenience init(modelContext: ModelContext, isSimulatorEnvironment: Bool) {
        self.init()
        self.modelContext = modelContext
        
        if isSimulatorEnvironment {
            print("Using mock ServiceTitan integration")
            self.isConnected = true
            // Add any mock data needed for development
        }
    }
}

// MARK: - SamsaraService Extension
extension SamsaraService {
    /// Initialize with model context and simulator environment flag
    convenience init(modelContext: ModelContext, isSimulatorEnvironment: Bool) {
        self.init()
        self.modelContext = modelContext
        
        if isSimulatorEnvironment {
            print("Using mock Samsara integration")
            self.isConnected = true
            // Add any mock data needed for development
        }
    }
}

// MARK: - CloudKitManager Extension
extension CloudKitManager {
    /// Initialize with model context and simulator environment flag
    convenience init(modelContext: ModelContext, isSimulatorEnvironment: Bool) {
        self.init()
        self.modelContext = modelContext
        
        if isSimulatorEnvironment {
            print("Using mock CloudKit manager")
            // Modify behavior to use local storage only
        }
    }
}

// MARK: - StoreKitManager Extension
extension StoreKitManager {
    /// Initialize with simulator environment flag
    convenience init(isSimulatorEnvironment: Bool) {
        self.init()
        
        if isSimulatorEnvironment {
            print("Using mock StoreKit manager")
            // Set up mock products and purchases
            self.products = []
            self.errorMessage = nil
            self.isLoading = false
            self.purchasedProducts = []
            // Don't try to fetch products from StoreKit in simulator
        } else {
            // Try to fetch real products with graceful error handling
            Task {
                await fetchProducts()
            }
        }
    }
} 