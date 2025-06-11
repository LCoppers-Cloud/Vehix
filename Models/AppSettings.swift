import Foundation
import SwiftData

@Model
final class AppSettings {
    var id: String = "app_settings"
    
    // Financial visibility controls
    var showFinancialDataToManagers: Bool = true
    var showVehicleInventoryValues: Bool = true
    var showPurchaseOrderSpending: Bool = true
    var showDetailedFinancialReports: Bool = false // Owner/admin only by default
    var showDataAnalyticsToManagers: Bool = true // Allow managers to see Data & Analytics tab
    
    // Dashboard customization
    var enableExecutiveFinancialSection: Bool = true
    var showMonthlySpendingAlerts: Bool = true
    var financialAlertThreshold: Double = 10000.0 // Alert if monthly spending exceeds this
    
    // Inventory settings
    var showInventoryValuesInVehicleList: Bool = true
    var enableInventoryValueTracking: Bool = true
    
    // Reporting settings
    var enableAutomaticFinancialReports: Bool = false
    var monthlyReportRecipientsData: Data = Data() // Store as JSON Data to avoid Array materialization issues
    
    // Created/updated tracking
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var updatedByUserId: String = ""
    
    // Computed property for monthlyReportRecipients
    var monthlyReportRecipients: [String] {
        get {
            guard !monthlyReportRecipientsData.isEmpty else { return [] }
            do {
                return try JSONDecoder().decode([String].self, from: monthlyReportRecipientsData)
            } catch {
                print("Error decoding monthlyReportRecipients: \(error)")
                return []
            }
        }
        set {
            do {
                monthlyReportRecipientsData = try JSONEncoder().encode(newValue)
            } catch {
                print("Error encoding monthlyReportRecipients: \(error)")
                monthlyReportRecipientsData = Data()
            }
        }
    }
    
    init(
        id: String = "app_settings",
        showFinancialDataToManagers: Bool = true,
        showVehicleInventoryValues: Bool = true,
        showPurchaseOrderSpending: Bool = true,
        showDetailedFinancialReports: Bool = false,
        showDataAnalyticsToManagers: Bool = true,
        enableExecutiveFinancialSection: Bool = true,
        showMonthlySpendingAlerts: Bool = true,
        financialAlertThreshold: Double = 10000.0,
        showInventoryValuesInVehicleList: Bool = true,
        enableInventoryValueTracking: Bool = true,
        enableAutomaticFinancialReports: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        updatedByUserId: String = ""
    ) {
        self.id = id
        self.showFinancialDataToManagers = showFinancialDataToManagers
        self.showVehicleInventoryValues = showVehicleInventoryValues
        self.showPurchaseOrderSpending = showPurchaseOrderSpending
        self.showDetailedFinancialReports = showDetailedFinancialReports
        self.showDataAnalyticsToManagers = showDataAnalyticsToManagers
        self.enableExecutiveFinancialSection = enableExecutiveFinancialSection
        self.showMonthlySpendingAlerts = showMonthlySpendingAlerts
        self.financialAlertThreshold = financialAlertThreshold
        self.showInventoryValuesInVehicleList = showInventoryValuesInVehicleList
        self.enableInventoryValueTracking = enableInventoryValueTracking
        self.enableAutomaticFinancialReports = enableAutomaticFinancialReports
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.updatedByUserId = updatedByUserId
    }
    
    // Helper methods
    func updateSettings(by userId: String) {
        self.updatedAt = Date()
        self.updatedByUserId = userId
    }
    
    // Check if user can see financial data
    func canUserSeeFinancialData(userRole: UserRole) -> Bool {
        switch userRole {
        case .admin, .dealer, .owner:
            return true // Owners/admins always see financial data
        case .premium, .manager:
            return showFinancialDataToManagers // Premium users and managers act as managers
        case .standard, .technician:
            return false // Standard users and technicians don't see financial data
        }
    }
    
    // Check if user can see detailed financial reports
    func canUserSeeDetailedReports(userRole: UserRole) -> Bool {
        switch userRole {
        case .admin, .dealer, .owner:
            return true // Owners/admins always see detailed reports
        case .premium, .manager:
            return showDetailedFinancialReports // Premium users and managers act as managers
        case .standard, .technician:
            return false
        }
    }
    
    // Check if user can see data analytics tab
    func canUserSeeDataAnalytics(userRole: UserRole) -> Bool {
        switch userRole {
        case .admin, .dealer, .owner:
            return true // Owners/admins always see data analytics
        case .premium, .manager:
            return showDataAnalyticsToManagers // Premium users and managers act as managers
        case .standard, .technician:
            return false
        }
    }
}

// MARK: - Settings Manager

class AppSettingsManager: ObservableObject {
    private var modelContext: ModelContext?
    
    @Published var settings: AppSettings?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        Task {
            await loadSettings()
        }
    }
    
    @MainActor
    func loadSettings() async {
        guard let modelContext = modelContext else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Try to fetch existing settings
            let descriptor = FetchDescriptor<AppSettings>()
            let existingSettings = try modelContext.fetch(descriptor)
            
            if let existing = existingSettings.first {
                settings = existing
            } else {
                // Create default settings
                let defaultSettings = AppSettings()
                modelContext.insert(defaultSettings)
                try modelContext.save()
                settings = defaultSettings
            }
            
            isLoading = false
        } catch {
            errorMessage = "Failed to load settings: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    @MainActor
    func updateSettings(_ newSettings: AppSettings, updatedBy userId: String) async -> Bool {
        guard let modelContext = modelContext else { return false }
        
        do {
            newSettings.updateSettings(by: userId)
            try modelContext.save()
            settings = newSettings
            return true
        } catch {
            errorMessage = "Failed to save settings: \(error.localizedDescription)"
            return false
        }
    }
    
    // Convenience methods
    func canUserSeeFinancialData(userRole: UserRole) -> Bool {
        return settings?.canUserSeeFinancialData(userRole: userRole) ?? false
    }
    
    func canUserSeeDetailedReports(userRole: UserRole) -> Bool {
        return settings?.canUserSeeDetailedReports(userRole: userRole) ?? false
    }
    
    func canUserSeeDataAnalytics(userRole: UserRole) -> Bool {
        return settings?.canUserSeeDataAnalytics(userRole: userRole) ?? false
    }
} 