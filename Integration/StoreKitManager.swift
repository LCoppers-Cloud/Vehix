import Foundation
import StoreKit
import SwiftUI
import UserNotifications

// Notification names for subscription events
extension Notification.Name {
    static let subscriptionCancelled = Notification.Name("subscriptionCancelled")
    static let subscriptionReactivated = Notification.Name("subscriptionReactivated")
}

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
    /// Current technician count (should be set by querying the database)
    @Published var currentTechnicianCount: Int = 0

    /// Staff/vehicle/technician limits and pricing based on subscription plan
    var staffLimit: Int {
        switch currentPlan {
        case .basic: return 2
        case .pro: return 5 // 4 staff + 1 owner
        case .enterprise: return 999999
        case .trial: return 2 // Same as basic during trial
        }
    }
    
    var vehicleLimit: Int {
        switch currentPlan {
        case .basic: return 5
        case .pro: return 15
        case .enterprise: return 999999
        case .trial: return 5 // Same as basic during trial
        }
    }
    
    var technicianLimit: Int {
        switch currentPlan {
        case .basic: return 5
        case .pro: return 15
        case .enterprise: return 999999
        case .trial: return 5 // Same as basic during trial
        }
    }
    
    var staffPricePerExtra: Double {
        switch currentPlan {
        case .basic: return 25.0 // Additional staff pricing
        case .pro: return 20.0
        case .enterprise: return 0.0
        case .trial: return 0.0
        }
    }
    
    var vehiclePricePerExtra: Double {
        switch currentPlan {
        case .basic: return 30.0 // Additional vehicle pricing
        case .pro: return 25.0
        case .enterprise: return 50.0 // Per vehicle pricing
        case .trial: return 0.0
        }
    }
    
    var technicianPricePerExtra: Double {
        switch currentPlan {
        case .basic: return 20.0 // Additional technician pricing
        case .pro: return 15.0
        case .enterprise: return 0.0
        case .trial: return 0.0
        }
    }
    
    var basePrice: Double {
        switch currentPlan {
        case .basic: return 125.0
        case .pro: return 385.0
        case .enterprise: return 0.0 // Enterprise is per-vehicle pricing
        case .trial: return 0.0
        }
    }
    
    var yearlyBasePrice: Double {
        return basePrice * 12 * 0.9 // 10% discount for yearly
    }
    
    /// Current subscription plan
    @Published var currentPlan: SubscriptionPlan = .trial
    
    /// Subscription plan names for display
    var currentPlanName: String {
        switch currentPlan {
        case .trial: return "7-Day Free Trial"
        case .basic: return "Basic Plan"
        case .pro: return "Pro Plan"
        case .enterprise: return "Enterprise Plan"
        }
    }
    
    /// Check if user is in trial period
    var isInTrial: Bool {
        return currentPlan == .trial && trialActive
    }
    
    /// Check if user has an active subscription (not trial)
    var hasActiveSubscription: Bool {
        return currentPlan != .trial && subscription?.isActive == true
    }
    
    /// Get enterprise pricing for current vehicle count
    var enterpriseMonthlyTotal: Double {
        guard currentPlan == .enterprise else { return 0.0 }
        return Double(currentVehicleCount) * 50.0
    }
    
    /// Get yearly enterprise pricing
    var enterpriseYearlyTotal: Double {
        return enterpriseMonthlyTotal * 12 * 0.9 // 10% discount
    }
    
    /// Remaining staff/vehicle/technician slots
    var staffRemaining: Int {
        max(0, staffLimit - currentStaffCount)
    }
    var vehicleRemaining: Int {
        max(0, vehicleLimit - currentVehicleCount)
    }
    var technicianRemaining: Int {
        max(0, technicianLimit - currentTechnicianCount)
    }
    
    /// Update counts from database
    func updateCounts(staff: Int, vehicles: Int, technicians: Int) {
        currentStaffCount = staff
        currentVehicleCount = vehicles
        currentTechnicianCount = technicians
    }
    
    /// Update subscription plan based on purchased products
    func updateCurrentPlan() {
        if purchasedProducts.contains(where: { $0.id == enterpriseSubscriptionID }) {
            currentPlan = .enterprise
        } else if purchasedProducts.contains(where: { $0.id == proSubscriptionID }) {
            currentPlan = .pro
        } else if purchasedProducts.contains(where: { $0.id == basicSubscriptionID }) {
            currentPlan = .basic
        } else {
            // If no subscription, check if trial is active
            if trialActive {
                currentPlan = .trial
            } else {
                // Trial expired, default to basic (user needs to subscribe)
                currentPlan = .basic
            }
        }
    }
    
    /// Update subscription plan based on user role (for beta testing and premium users)
    func updateCurrentPlanFromUserRole(_ userRole: UserRole) {
        switch userRole {
        case .admin, .dealer, .owner:
            currentPlan = .enterprise // Give admin/dealer/owner unlimited access
        case .premium, .manager:
            currentPlan = .pro // Give premium users and managers pro-level access
        case .technician:
            currentPlan = .basic // Technicians get basic access
        case .standard:
            // Keep existing plan logic for standard users
            updateCurrentPlan()
        }
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
    
    // MARK: - Subscription Status (Consolidated)
    
    var isSubscribed: Bool {
        guard let sub = subscription else { return false }
        return sub.isActive && !(sub.hasExpired)
    }
    
    /// Get subscription status for UI display
    var subscriptionStatusText: String {
        if isInTrial {
            let days = subscription?.daysRemainingInTrial ?? 0
            return "Free Trial - \(days) days remaining"
        } else if isSubscribed {
            return "Active Subscription"
        } else {
            return "No Active Subscription"
        }
    }

    // Helper method to detect if running in simulator (for development)
    private func isRunningInSimulator() -> Bool {
        #if targetEnvironment(simulator)
            return true
        #else
            return false
        #endif
    }
    
    // MARK: - Subscription Cancellation Handling
    
    func handleSubscriptionCancellation() {
        // Update subscription status
        subscription?.isActive = false
        currentPlan = .trial
        
        // Notify CloudKit manager about cancellation
        NotificationCenter.default.post(name: .subscriptionCancelled, object: nil)
        
        // Show cancellation confirmation with data retention info
        showSubscriptionCancelledAlert()
    }
    
    private func showSubscriptionCancelledAlert() {
        // This would be handled by the UI layer
        let notification = UNMutableNotificationContent()
        notification.title = "Subscription Cancelled"
        notification.body = "Your Vehix subscription has been cancelled. Your data will be retained for 90 days, giving you time to reactivate if you change your mind."
        notification.sound = .default
        
        let request = UNNotificationRequest(identifier: "subscription.cancelled.confirmation", content: notification, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    func reactivateSubscription() {
        // This would be called when user resubscribes
        subscription?.isActive = true
        
        // Notify CloudKit manager about reactivation
        NotificationCenter.default.post(name: .subscriptionReactivated, object: nil)
    }
    
    // MARK: - Apple Store Compliant Subscription Management
    
    /// Start free trial (Apple Store compliant)
    func startFreeTrial() async {
        guard let basicProduct = products.first(where: { $0.id == basicSubscriptionID }) else {
            errorMessage = "Trial product not available"
            return
        }
        
        do {
            isLoading = true
            let result = try await basicProduct.purchase()
            
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    // Handle successful trial start
                    await handleSuccessfulPurchase(transaction)
                    
                    // Mark trial as started
                    UserDefaults.standard.set(true, forKey: "trial_started")
                    UserDefaults.standard.set(Date(), forKey: "trial_start_date")
                    
                case .unverified:
                    errorMessage = "Purchase verification failed"
                }
            case .pending:
                // Handle pending purchase (family sharing approval, etc.)
                errorMessage = "Purchase is pending approval"
            case .userCancelled:
                // User cancelled, no error needed
                break
            @unknown default:
                errorMessage = "Unknown purchase result"
            }
        } catch {
            errorMessage = "Failed to start trial: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Purchase subscription (Apple Store compliant)
    func purchaseSubscription(productID: String) async {
        guard let product = products.first(where: { $0.id == productID }) else {
            errorMessage = "Product not available"
            return
        }
        
        do {
            isLoading = true
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await handleSuccessfulPurchase(transaction)
                case .unverified:
                    errorMessage = "Purchase verification failed"
                }
            case .pending:
                errorMessage = "Purchase is pending approval"
            case .userCancelled:
                break
            @unknown default:
                errorMessage = "Unknown purchase result"
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Handle successful purchase/trial
    private func handleSuccessfulPurchase(_ transaction: StoreKit.Transaction) async {
        // Update subscription status
        if subscription == nil {
            subscription = Subscription(productId: transaction.productID)
        }
        
        subscription?.isActive = true
        subscription?.hasExpired = false
        subscription?.transactionId = String(transaction.id)
        subscription?.originalTransactionId = String(transaction.originalID)
        subscription?.purchaseDate = transaction.purchaseDate
        subscription?.expirationDate = transaction.expirationDate
        
        // Update purchased products
        await updatePurchasedProducts()
        
        // Finish the transaction
        await transaction.finish()
    }
    
    /// Restore purchases (Apple Store requirement) - Consolidated
    func restorePurchases() async {
        do {
            isLoading = true
            
            // Sync with App Store
            try await AppStore.sync()
            
            // Update purchased products
            await updatePurchasedProducts()
            
            if purchasedProducts.isEmpty {
                errorMessage = "No purchases found to restore"
            }
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Check subscription status with App Store
    func checkSubscriptionStatus() async {
        // Get current entitlements
        for await result in StoreKit.Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                // Update subscription based on current entitlements
                if subscription == nil {
                    subscription = Subscription(productId: transaction.productID)
                }
                
                subscription?.isActive = transaction.revocationDate == nil
                subscription?.hasExpired = transaction.expirationDate?.timeIntervalSinceNow ?? 0 < 0
                subscription?.expirationDate = transaction.expirationDate
                
            case .unverified:
                // Handle unverified transactions
                subscription?.isActive = false
            }
        }
        
        await updatePurchasedProducts()
    }
    
    /// Get subscription pricing information
    func getSubscriptionPricing() -> [SubscriptionPlan: String] {
        var pricing: [SubscriptionPlan: String] = [:]
        
        for product in products {
            switch product.id {
            case basicSubscriptionID:
                pricing[.basic] = product.displayPrice
            case proSubscriptionID:
                pricing[.pro] = product.displayPrice
            case enterpriseSubscriptionID:
                pricing[.enterprise] = product.displayPrice
            default:
                break
            }
        }
        
        return pricing
    }
    
    /// Check if user can start trial (Apple Store compliant)
    var canStartTrial: Bool {
        // User can start trial if they haven't used it before
        return !UserDefaults.standard.bool(forKey: "trial_used") && !isSubscribed
    }
    
    /// Mark trial as used (prevents multiple trials)
    private func markTrialAsUsed() {
        UserDefaults.standard.set(true, forKey: "trial_used")
    }
}

// StoreKit errors
enum StoreError: Error {
    case failedVerification
    case failedToFetchProducts
    case notPurchased
}

// MARK: - Subscription Plans

enum SubscriptionPlan: String, CaseIterable {
    case trial = "trial"
    case basic = "basic"
    case pro = "pro"
    case enterprise = "enterprise"
    
    var displayName: String {
        switch self {
        case .trial: return "7-Day Free Trial"
        case .basic: return "Basic"
        case .pro: return "Pro"
        case .enterprise: return "Enterprise"
        }
    }
    
    var monthlyPrice: Double {
        switch self {
        case .trial: return 0.0
        case .basic: return 125.0
        case .pro: return 385.0
        case .enterprise: return 50.0 // Per vehicle pricing
        }
    }
    
    var yearlyPrice: Double {
        return monthlyPrice * 12 * 0.9 // 10% discount for yearly
    }
    
    var features: [String] {
        switch self {
        case .trial:
            return [
                "7-day free trial",
                "Access to all Basic plan features",
                "No commitment required",
                "Automatic upgrade to Basic after trial"
            ]
        case .basic:
            return [
                "2 staff members",
                "5 vehicles",
                "5 technicians",
                "Basic inventory management",
                "Email support",
                "$125/month or $1,350/year"
            ]
        case .pro:
            return [
                "4 staff + 1 owner account",
                "15 vehicles",
                "15 technicians",
                "Advanced analytics",
                "Priority support",
                "$385/month or $4,158/year"
            ]
        case .enterprise:
            return [
                "Unlimited staff",
                "Unlimited vehicles",
                "Unlimited technicians",
                "$50 per vehicle/month",
                "Direct developer contact",
                "Issues resolved within weeks",
                "Custom options available",
                "Dedicated support team"
            ]
        }
    }
} 