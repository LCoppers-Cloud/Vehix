import Foundation
import StoreKit
import SwiftUI

/// Model for subscription data
class Subscription: Identifiable, ObservableObject {
    var id = UUID().uuidString
    var productId: String
    
    // Subscription status
    @Published var isActive: Bool = false
    @Published var hasExpired: Bool = false
    
    // Trial status
    @Published var trialAccepted: Bool = false
    @Published var trialStartDate: Date?
    @Published var trialEndDate: Date?
    
    // StoreKit integration
    var transactionId: String?
    var originalTransactionId: String?
    var purchaseDate: Date?
    var expirationDate: Date?
    var isAutoRenewable: Bool = true
    
    // Computed properties for UI
    var isTrialActive: Bool {
        guard let endDate = trialEndDate else { return false }
        return trialAccepted && Date() < endDate
    }
    
    var daysRemainingInTrial: Int {
        guard let endDate = trialEndDate else { return 0 }
        let calendar = Calendar.current
        return max(0, calendar.dateComponents([.day], from: Date(), to: endDate).day ?? 0)
    }
    
    var trialBillingDate: Date? {
        return trialEndDate
    }
    
    var willBeBilled: Bool {
        return isActive && !hasExpired && isAutoRenewable
    }
    
    init(productId: String) {
        self.productId = productId
    }
}

@MainActor
class StoreKitManager: ObservableObject {
    @Published var products: [Product] = []
    @Published var purchasedProducts: [Product] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // Subscription tiers
    private let basicSubscriptionID = "com.lcoppers.Vehix.basic"
    private let proSubscriptionID = "com.lcoppers.Vehix.pro"
    private let enterpriseSubscriptionID = "com.lcoppers.Vehix.enterprise"
    
    @Published var purchasedProductIDs: Set<String> = []
    @Published var subscription: Subscription?
    @Published var purchaseInProgress: Bool = false
    
    // For UI: trial status and billing date
    @Published var trialActive: Bool = false
    @Published var trialDaysRemaining: Int = 0
    @Published var trialBillingDate: Date?
    @Published var willBeBilled: Bool = false
    
    // Your product identifier
    let subscriptionProductID = "com.lcoppers.Vehix.subscription"
    
    // MARK: - Vehix Subscription Limits and Pricing
    
    /// Determines if ServiceTitan or any third-party integration is enabled (placeholder, should be set by integration logic)
    @Published var isThirdPartyIntegrationEnabled: Bool = false // Set this from integration logic

    /// Current staff (user) count (should be set by querying the database)
    @Published var currentStaffCount: Int = 0
    /// Current vehicle count (should be set by querying the database)
    @Published var currentVehicleCount: Int = 0

    /// Staff/vehicle limits and pricing based on integration status
    var staffLimit: Int {
        // Unlimited staff for the app owner
        999999
    }
    var vehicleLimit: Int {
        // Unlimited vehicles for the app owner
        999999
    }
    var staffPricePerExtra: Double {
        // Free for the app owner
        0.0
    }
    var vehiclePricePerExtra: Double {
        // Free for the app owner
        0.0
    }
    var basePrice: Double {
        // Free for the app owner
        0.0
    }

    /// Remaining staff/vehicle slots
    var staffRemaining: Int {
        max(0, staffLimit - currentStaffCount)
    }
    var vehicleRemaining: Int {
        max(0, vehicleLimit - currentVehicleCount)
    }
    
    // Default initializer used by the SimulatorSupport extension
    init() {
        // Initialize with default values, used by SimulatorSupport.swift's convenience initializer
    }
    
    // MARK: - Product Management
    
    @MainActor
    func fetchProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let productIDs: Set<String> = [basicSubscriptionID, proSubscriptionID, enterpriseSubscriptionID]
            
            // Request products from App Store
            let storeProducts = try await Product.products(for: productIDs)
            products = storeProducts.sorted { $0.price < $1.price }
            
            // Check for purchases
            try? await checkForPurchases()
            
        } catch {
            // Handle StoreKit errors gracefully
            if let asdError = error as NSError?, 
               asdError.domain == "ASDErrorDomain",
               (asdError.code == 509 || asdError.code == 1061) {
                // This is an authentication or "no account" error, which is common in development
                // Just log it and continue with the app
                print("StoreKit authentication issue - continuing without StoreKit functionality: \(error.localizedDescription)")
                setupMockProducts() // Set up mock products as a fallback
            } else {
                // Other StoreKit errors
                errorMessage = "Failed to fetch products: \(error.localizedDescription)"
                print("StoreKit error: \(error)")
            }
        }
        
        isLoading = false
    }
    
    // Mock products for development or when StoreKit is unavailable
    private func setupMockProducts() {
        // Create mock products for display purposes
        print("Setting up mock subscription products")
        
        // We'll just set placeholders since we can't create actual Product instances
        self.errorMessage = nil
        self.isLoading = false
    }
    
    // MARK: - Purchase Management
    
    @MainActor
    func purchase(_ product: Product) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                // Handle successful purchase verification
                do {
                    let transaction = try checkVerified(verification)
                    await updatePurchasedProducts()
                    await transaction.finish()
                    // Log successful purchase
                    print("Successfully purchased: \(product.displayName)")
                } catch {
                    errorMessage = "Purchase verification failed: \(error.localizedDescription)"
                    print("Verification error: \(error)")
                }
            case .userCancelled:
                print("User cancelled the purchase")
            case .pending:
                print("Purchase pending approval")
            @unknown default:
                errorMessage = "Unknown purchase result"
            }
        } catch {
            if let asdError = error as NSError?, 
               asdError.domain == "ASDErrorDomain",
               (asdError.code == 509 || asdError.code == 1061) {
                // Authentication issue - inform the user they need to sign in
                errorMessage = "Please sign in to your App Store account to make purchases"
                print("StoreKit authentication issue during purchase: \(error.localizedDescription)")
            } else {
                // Other purchase errors
                errorMessage = "Failed to purchase: \(error.localizedDescription)"
                print("Purchase error: \(error)")
            }
        }
        
        isLoading = false
    }
    
    @MainActor
    func checkForPurchases() async throws {
        // Handle possible authentication errors gracefully
        do {
            // The Transaction.currentEntitlements iteration itself can throw
            // authentication errors that will be caught by the outer catch block
            try await Task.sleep(nanoseconds: 1) // Force the do block to be potentially throwing
            
            // Get all transactions 
            for await result in Transaction.currentEntitlements {
                do {
                    let transaction = try checkVerified(result)
                    
                    // Find the matching product
                    if let matchingProduct = products.first(where: { $0.id == transaction.productID }) {
                        // Add to purchased products if not already there
                        if !purchasedProducts.contains(where: { $0.id == matchingProduct.id }) {
                            purchasedProducts.append(matchingProduct)
                        }
                    }
                } catch {
                    // Handle verification errors for individual transactions
                    print("Transaction verification failed: \(error)")
                    // Continue with next transaction
                    continue
                }
            }
        } catch {
            // If we get authentication errors, just continue without subscriptions
            if let asdError = error as NSError?, 
               asdError.domain == "ASDErrorDomain",
               (asdError.code == 509 || asdError.code == 1061) {
                print("StoreKit authentication issue while checking purchases - continuing without subscription data")
                // Don't throw the error further
            } else {
                // Only throw non-authentication errors
                throw error
            }
        }
    }
    
    // Helper to verify a transaction
    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    // Update the list of purchased products
    @MainActor
    func updatePurchasedProducts() async {
        do {
            try await checkForPurchases()
        } catch {
            // Log but don't show the error to user for this background refresh
            print("Error updating purchased products: \(error)")
        }
    }
    
    // Start a 7-day free trial and subscribe
    func startTrialAndSubscribe() async {
        guard let product = products.first(where: { $0.id == subscriptionProductID }) else {
            errorMessage = "Subscription product not found."
            return
        }
        purchaseInProgress = true
        defer { purchaseInProgress = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    // Update your Subscription model
                    let trialStart = Date()
                    let trialEnd = Calendar.current.date(byAdding: .day, value: 7, to: trialStart)!
                    let newSub = Subscription(productId: product.id)
                    newSub.trialAccepted = true
                    newSub.trialStartDate = trialStart
                    newSub.trialEndDate = trialEnd
                    newSub.isActive = true
                    newSub.transactionId = transaction.id.description
                    newSub.purchaseDate = trialStart
                    newSub.expirationDate = transaction.expirationDate
                    self.subscription = newSub
                    self.trialActive = true
                    self.trialDaysRemaining = 7
                    self.trialBillingDate = trialEnd
                    self.willBeBilled = true
                    
                    // Validate the receipt with the server
                    validateReceipt()
                    
                    // Finish the transaction
                    await transaction.finish()
                }
            case .pending:
                errorMessage = "Purchase pending."
            case .userCancelled:
                errorMessage = "Purchase cancelled."
            default:
                errorMessage = "Unknown purchase result."
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
        }
    }
    
    // Update trial/billing status for UI
    func updateTrialStatus() {
        guard let sub = subscription else { return }
        trialActive = sub.isTrialActive
        trialDaysRemaining = sub.daysRemainingInTrial
        trialBillingDate = sub.trialBillingDate
        willBeBilled = sub.willBeBilled
    }
    
    // Restore purchases (for compliance)
    func restorePurchases() async {
        purchaseInProgress = true
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
            validateReceipt()
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
        }
        purchaseInProgress = false
    }
    
    // Validate app receipt with server
    func validateReceipt() {
        ReceiptValidator.shared.validateReceipt { [weak self] isValid, errorMessage in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if isValid {
                    // If receipt is valid, but we don't have a subscription, create one
                    if self.subscription == nil && self.purchasedProductIDs.contains(self.subscriptionProductID) {
                        self.subscription = Subscription(productId: self.subscriptionProductID)
                        self.subscription?.isActive = true
                        self.updateTrialStatus()
                    }
                } else if let errorMessage = errorMessage {
                    self.errorMessage = "Receipt validation failed: \(errorMessage)"
                    
                    // If server validation fails, we should invalidate the subscription state
                    // This prevents users from bypassing receipt validation
                    if !self.isRunningInSimulator() {
                        self.subscription?.isActive = false
                    }
                }
            }
        }
    }
    
    var isSubscribed: Bool {
        guard let sub = subscription else { return false }
        return sub.isActive && !(sub.hasExpired)
    }
    
    // Helper method to detect if running in simulator (for development)
    private func isRunningInSimulator() -> Bool {
        #if targetEnvironment(simulator)
            return true
        #else
            return false
        #endif
    }
}

// StoreKit errors
enum StoreError: Error {
    case failedVerification
    case failedToFetchProducts
    case notPurchased
} 