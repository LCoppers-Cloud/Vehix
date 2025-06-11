import Foundation
import SwiftUI
import CloudKit

/// Marketing Data Manager for collecting and managing consented marketing emails
/// Apple-compliant system for sharing marketing data with app developer
class MarketingDataManager: ObservableObject {
    
    // MARK: - Marketing Data Model
    
    struct MarketingContact: Codable, Identifiable {
        var id = UUID()
        let email: String
        let fullName: String
        let phoneNumber: String?
        let companyName: String
        let position: String?
        let department: String?
        let consentDate: Date
        let invitedByEmail: String
        let appVersion: String
        let deviceInfo: String
        
        var anonymizedData: [String: String] {
            return [
                "domain": String(email.split(separator: "@").last ?? "unknown"),
                "industry": companyName.isEmpty ? "unknown" : "hvac", // Generalized
                "role": position ?? "technician",
                "consentMonth": DateFormatter.marketingMonthYear.string(from: consentDate),
                "appVersion": appVersion
            ]
        }
    }
    
    @Published var marketingContacts: [MarketingContact] = []
    @Published var totalConsentedUsers: Int = 0
    @Published var isDataSharingEnabled: Bool = true
    @Published var lastSyncDate: Date?
    
    // Developer contact for data sharing
    private let developerEmail = "lcoppers@example.com" // Your email for marketing data
    private let marketingDataKey = "vehix_marketing_contacts"
    
    init() {
        loadMarketingData()
        setupPeriodicSync()
    }
    
    // MARK: - Data Collection
    
    func addMarketingContact(
        email: String,
        fullName: String,
        phoneNumber: String? = nil,
        companyName: String,
        position: String? = nil,
        department: String? = nil,
        invitedByEmail: String
    ) {
        let contact = MarketingContact(
            email: email,
            fullName: fullName,
            phoneNumber: phoneNumber,
            companyName: companyName,
            position: position,
            department: department,
            consentDate: Date(),
            invitedByEmail: invitedByEmail,
            appVersion: getCurrentAppVersion(),
            deviceInfo: getDeviceInfo()
        )
        
        marketingContacts.append(contact)
        totalConsentedUsers = marketingContacts.count
        
        saveMarketingData()
        
        // Trigger sync to developer
        Task {
            await syncMarketingDataToDeveloper()
        }
    }
    
    func revokeMarketingConsent(email: String) {
        marketingContacts.removeAll { $0.email == email }
        totalConsentedUsers = marketingContacts.count
        saveMarketingData()
        
        // Notify developer of opt-out
        Task {
            await notifyDeveloperOfOptOut(email: email)
        }
    }
    
    // MARK: - Data Management
    
    private func loadMarketingData() {
        if let data = UserDefaults.standard.data(forKey: marketingDataKey),
           let contacts = try? JSONDecoder().decode([MarketingContact].self, from: data) {
            marketingContacts = contacts
            totalConsentedUsers = contacts.count
        }
    }
    
    private func saveMarketingData() {
        if let data = try? JSONEncoder().encode(marketingContacts) {
            UserDefaults.standard.set(data, forKey: marketingDataKey)
        }
    }
    
    // MARK: - Developer Data Sharing (Apple Compliant)
    
    private func syncMarketingDataToDeveloper() async {
        guard isDataSharingEnabled else { return }
        
        let exportData = generateMarketingExport()
        
        // In production, this would use a secure API endpoint
        // For demonstration, we'll show how the data would be structured
        print("=== MARKETING DATA SYNC TO DEVELOPER ===")
        print("To: \(developerEmail)")
        print("Subject: Vehix App - Marketing Contact Sync")
        print("Data: \(exportData)")
        print("=====================================")
        
        lastSyncDate = Date()
        
        // In production implementation:
        // - Use HTTPS API with authentication
        // - Encrypt sensitive data in transit
        // - Implement rate limiting
        // - Add data retention policies
    }
    
    private func generateMarketingExport() -> [String: Any] {
        let contacts = marketingContacts.map { contact in
            return [
                "email": contact.email,
                "fullName": contact.fullName,
                "phone": contact.phoneNumber ?? "",
                "company": contact.companyName,
                "position": contact.position ?? "",
                "department": contact.department ?? "",
                "consentDate": ISO8601DateFormatter().string(from: contact.consentDate),
                "invitedBy": contact.invitedByEmail,
                "appVersion": contact.appVersion,
                "deviceType": contact.deviceInfo
            ]
        }
        
        return [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "totalContacts": contacts.count,
            "appVersion": getCurrentAppVersion(),
            "contacts": contacts,
            "metadata": [
                "syncType": "fullSync",
                "platform": "iOS",
                "consentType": "explicit"
            ]
        ]
    }
    
    private func notifyDeveloperOfOptOut(email: String) async {
        let optOutData = [
            "email": email,
            "optOutDate": ISO8601DateFormatter().string(from: Date()),
            "reason": "userRequested"
        ]
        
        print("=== OPT-OUT NOTIFICATION ===")
        print("To: \(developerEmail)")
        print("Subject: Vehix App - Marketing Opt-Out")
        print("Data: \(optOutData)")
        print("===========================")
    }
    
    // MARK: - Analytics & Reporting
    
    func getMarketingAnalytics() -> MarketingAnalytics {
        let totalContacts = marketingContacts.count
        let companiesCount = Set(marketingContacts.map { $0.companyName }).count
        let averageConsentPerDay = calculateAverageConsentPerDay()
        let topPositions = getTopPositions()
        let topDepartments = getTopDepartments()
        
        return MarketingAnalytics(
            totalConsentedUsers: totalContacts,
            uniqueCompanies: companiesCount,
            averageConsentPerDay: averageConsentPerDay,
            topPositions: topPositions,
            topDepartments: topDepartments,
            lastSyncDate: lastSyncDate
        )
    }
    
    private func calculateAverageConsentPerDay() -> Double {
        guard !marketingContacts.isEmpty else { return 0 }
        
        let sortedDates = marketingContacts.map { $0.consentDate }.sorted()
        guard let firstDate = sortedDates.first,
              let lastDate = sortedDates.last else { return 0 }
        
        let daysDifference = Calendar.current.dateComponents([.day], from: firstDate, to: lastDate).day ?? 1
        return Double(marketingContacts.count) / max(Double(daysDifference), 1)
    }
    
    private func getTopPositions() -> [String: Int] {
        let positions = marketingContacts.compactMap { $0.position }
        return Dictionary(grouping: positions, by: { $0 })
            .mapValues { $0.count }
    }
    
    private func getTopDepartments() -> [String: Int] {
        let departments = marketingContacts.compactMap { $0.department }
        return Dictionary(grouping: departments, by: { $0 })
            .mapValues { $0.count }
    }
    
    // MARK: - Utilities
    
    private func getCurrentAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    private func getDeviceInfo() -> String {
        return UIDevice.current.model
    }
    
    private func setupPeriodicSync() {
        // Sync marketing data weekly
        Timer.scheduledTimer(withTimeInterval: 7 * 24 * 60 * 60, repeats: true) { _ in
            Task {
                await self.syncMarketingDataToDeveloper()
            }
        }
    }
    
    // MARK: - Legal Compliance
    
    func exportUserData(for email: String) -> String? {
        guard let contact = marketingContacts.first(where: { $0.email == email }) else {
            return nil
        }
        
        return """
        Vehix Marketing Data Export for \(email)
        
        Personal Information:
        - Full Name: \(contact.fullName)
        - Email: \(contact.email)
        - Phone: \(contact.phoneNumber ?? "Not provided")
        - Company: \(contact.companyName)
        - Position: \(contact.position ?? "Not specified")
        - Department: \(contact.department ?? "Not specified")
        
        Consent Information:
        - Consent Date: \(contact.consentDate)
        - Invited By: \(contact.invitedByEmail)
        - App Version: \(contact.appVersion)
        - Device: \(contact.deviceInfo)
        
        Data Usage:
        - Purpose: Marketing communications and app improvement
        - Sharing: Shared with app developer for business purposes
        - Retention: Until consent is revoked
        
        Your Rights:
        - You can revoke consent at any time through the app settings
        - You can request data deletion by contacting support
        - You can export your data at any time
        """
    }
}

// MARK: - Supporting Models

struct MarketingAnalytics {
    let totalConsentedUsers: Int
    let uniqueCompanies: Int
    let averageConsentPerDay: Double
    let topPositions: [String: Int]
    let topDepartments: [String: Int]
    let lastSyncDate: Date?
}

// MARK: - Extensions

extension DateFormatter {
    static let marketingMonthYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter
    }()
} 