import Foundation

// MARK: - ServiceTitan Job Model (Unified)

struct ServiceTitanJob: Identifiable, Codable {
    let id: String
    let jobNumber: String
    let customerName: String
    let address: String
    let scheduledDate: Date
    let status: String
    let jobDescription: String
    let serviceTitanId: String
    let estimatedTotal: Double?
    
    // Convenience initializer for compatibility
    init(
        id: String,
        jobNumber: String,
        customerName: String,
        address: String,
        scheduledDate: Date = Date(),
        status: String,
        jobDescription: String = "",
        serviceTitanId: String = "",
        estimatedTotal: Double? = nil
    ) {
        self.id = id
        self.jobNumber = jobNumber
        self.customerName = customerName
        self.address = address
        self.scheduledDate = scheduledDate
        self.status = status
        self.jobDescription = jobDescription
        self.serviceTitanId = serviceTitanId
        self.estimatedTotal = estimatedTotal
    }
    
    // Format job number and description for display
    var displayName: String {
        return "\(jobNumber) - \(customerName)"
    }
    
    var displayDescription: String {
        return "\(jobDescription) at \(address)"
    }
    
    // Estimated total display
    var estimatedTotalDisplay: String {
        if let total = estimatedTotal {
            return String(format: "$%.2f", total)
        }
        return "N/A"
    }
}

// MARK: - ServiceTitan Technician Model

struct ServiceTitanTechnician: Identifiable, Codable {
    let id: String
    let name: String
    let email: String
    let phone: String?
    let isActive: Bool
    let employeeId: String?
    let serviceTitanId: String
    
    var displayName: String {
        return name
    }
}

// MARK: - ServiceTitan API Response Models

struct ServiceTitanResponse<T: Codable>: Codable {
    let data: [T]
    let hasMore: Bool
    let totalCount: Int
}

struct ServiceTitanAPITechnician: Identifiable, Codable {
    let id: String
    let name: String
    let email: String
    let phone: String?
    let isActive: Bool
    let employeeId: String?
    
    private enum CodingKeys: String, CodingKey {
        case id, name, email, phone, isActive, employeeId
    }
}

// MARK: - Purchase Order Models

struct PurchaseOrderItem: Codable {
    let description: String
    let quantity: Int
    let unitPrice: Double
    let totalPrice: Double
    let category: String?
    
    init(description: String, quantity: Int, unitPrice: Double, totalPrice: Double, category: String? = nil) {
        self.description = description
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.totalPrice = totalPrice
        self.category = category
    }
}

struct CreatePurchaseOrderRequest: Codable {
    let technicianId: Int
    let jobId: Int
    let vendor: String
    let total: Double
    let items: [PurchaseOrderItem]
    let notes: String?
    
    init(technicianId: Int, jobId: Int, vendor: String, total: Double, items: [PurchaseOrderItem], notes: String? = nil) {
        self.technicianId = technicianId
        self.jobId = jobId
        self.vendor = vendor
        self.total = total
        self.items = items
        self.notes = notes
    }
}

struct CreatePurchaseOrderResponse: Codable {
    let id: String
    let poNumber: String
    let status: String
    let createdAt: Date
}

// MARK: - Authentication Models

struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let tokenType: String
    
    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

// MARK: - Error Types

enum ServiceTitanAPIError: Error, LocalizedError {
    case notAuthenticated
    case authenticationFailed
    case invalidResponse
    case apiError(Int)
    case networkError(Error)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated with ServiceTitan API"
        case .authenticationFailed:
            return "ServiceTitan authentication failed"
        case .invalidResponse:
            return "Invalid response from ServiceTitan API"
        case .apiError(let code):
            return "ServiceTitan API error: \(code)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Data decoding error: \(error.localizedDescription)"
        }
    }
}

// MARK: - ServiceTitan Configuration

struct ServiceTitanConfig {
    static let integrationURL = "https://api-integration.servicetitan.io"
    static let productionURL = "https://api.servicetitan.io"
    
    static var clientId: String {
        return Bundle.main.object(forInfoDictionaryKey: "ServiceTitanClientId") as? String ?? ""
    }
    
    static var clientSecret: String {
        return Bundle.main.object(forInfoDictionaryKey: "ServiceTitanClientSecret") as? String ?? ""
    }
    
    static var isConfigured: Bool {
        return !clientId.isEmpty && !clientSecret.isEmpty
    }
}

// MARK: - ServiceTitan User Settings

struct ServiceTitanUserConfig {
    var clientId: String = ""
    var tenantId: Int64 = 0
    var syncInventory: Bool = false
    var syncTechnicians: Bool = false
    var syncVendors: Bool = false
    var syncPurchaseOrders: Bool = false
    var updatedAt: Date = Date()
    
    private static let userDefaults = UserDefaults.standard
    private static let clientIdKey = "ServiceTitan_ClientId"
    private static let tenantIdKey = "ServiceTitan_TenantId"
    private static let syncInventoryKey = "ServiceTitan_SyncInventory"
    private static let syncTechniciansKey = "ServiceTitan_SyncTechnicians"
    private static let syncVendorsKey = "ServiceTitan_SyncVendors"
    private static let syncPurchaseOrdersKey = "ServiceTitan_SyncPurchaseOrders"
    private static let updatedAtKey = "ServiceTitan_UpdatedAt"
    private static let clientSecretKey = "ServiceTitan_ClientSecret"
    
    static func load() -> ServiceTitanUserConfig {
        var config = ServiceTitanUserConfig()
        config.clientId = userDefaults.string(forKey: clientIdKey) ?? ""
        config.tenantId = userDefaults.object(forKey: tenantIdKey) as? Int64 ?? 0
        config.syncInventory = userDefaults.bool(forKey: syncInventoryKey)
        config.syncTechnicians = userDefaults.bool(forKey: syncTechniciansKey)
        config.syncVendors = userDefaults.bool(forKey: syncVendorsKey)
        config.syncPurchaseOrders = userDefaults.bool(forKey: syncPurchaseOrdersKey)
        if let updatedDate = userDefaults.object(forKey: updatedAtKey) as? Date {
            config.updatedAt = updatedDate
        }
        return config
    }
    
    func save() {
        Self.userDefaults.set(clientId, forKey: Self.clientIdKey)
        Self.userDefaults.set(tenantId, forKey: Self.tenantIdKey)
        Self.userDefaults.set(syncInventory, forKey: Self.syncInventoryKey)
        Self.userDefaults.set(syncTechnicians, forKey: Self.syncTechniciansKey)
        Self.userDefaults.set(syncVendors, forKey: Self.syncVendorsKey)
        Self.userDefaults.set(syncPurchaseOrders, forKey: Self.syncPurchaseOrdersKey)
        Self.userDefaults.set(updatedAt, forKey: Self.updatedAtKey)
        Self.userDefaults.synchronize()
    }
    
    func getClientSecret() -> String {
        // Use Keychain to securely retrieve client secret
        return KeychainServices.get(key: Self.clientSecretKey) ?? ""
    }
    
    mutating func setClientSecret(_ secret: String) {
        // Use Keychain to securely store client secret
        KeychainServices.save(key: Self.clientSecretKey, value: secret)
    }
}

// MARK: - Mock Data for Testing

extension ServiceTitanJob {
    static let mockJobs: [ServiceTitanJob] = [
        ServiceTitanJob(
            id: "job-001",
            jobNumber: "WO-2024-001",
            customerName: "ABC Plumbing",
            address: "123 Main Street, Anytown, USA",
            scheduledDate: Date(),
            status: "In Progress",
            jobDescription: "HVAC System Maintenance",
            serviceTitanId: "ST-JOB-10045678",
            estimatedTotal: 150.0
        ),
        ServiceTitanJob(
            id: "job-002",
            jobNumber: "WO-2024-002",
            customerName: "XYZ Electric",
            address: "456 Oak Avenue, Anytown, USA",
            scheduledDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date(),
            status: "Scheduled",
            jobDescription: "Commercial Refrigeration Repair",
            serviceTitanId: "ST-JOB-10045679",
            estimatedTotal: 200.0
        ),
        ServiceTitanJob(
            id: "job-003",
            jobNumber: "WO-2024-003",
            customerName: "Global HVAC Solutions",
            address: "789 Pine Street, Anytown, USA",
            scheduledDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date(),
            status: "Scheduled",
            jobDescription: "Plumbing Installation",
            serviceTitanId: "ST-JOB-10045680",
            estimatedTotal: 100.0
        )
    ]
}

// MARK: - Attachment Models

struct JobAttachment: Codable {
    let name: String
    let type: String
    let data: String
}

// MARK: - Matching and Analysis Models

struct TechnicianMatch {
    let appUser: AuthUser
    let serviceTitanTechId: String?
    let serviceTitanTech: ServiceTitanAPITechnician?
    let serviceTitanTechName: String?
    let confidence: Double
    let matchMethod: MatchMethod
    let reasons: [String]
    let needsManualReview: Bool
    
    enum MatchMethod {
        case email
        case name
        case none
    }
}

