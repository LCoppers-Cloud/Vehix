import Foundation
import SwiftData

// MARK: - Account Types & Permissions

@Model
class BusinessAccount {
    var businessID: UUID = UUID() // Remove unique constraint for CloudKit
    var businessName: String = ""
    var businessType: String = ""
    var industryType: String = ""
    var fleetSize: String = ""
    var subscriptionPlan: String = ""
    var billingPeriod: String = ""
    var managementStructure: String = ""
    var maxVehicles: Int = 5
    var maxManagers: Int = 1
    var maxTechnicians: Int = 5
    @Attribute(.transformable(by: StringArrayTransformer.self)) var features: [String] = []
    var isActive: Bool = true
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    // Relationships - must be optional for CloudKit
    @Relationship var userAccounts: [UserAccount]?
    
    init(
        businessName: String,
        businessType: String,
        industryType: String,
        fleetSize: String,
        subscriptionPlan: String,
        billingPeriod: String,
        managementStructure: String,
        maxVehicles: Int,
        maxManagers: Int,
        maxTechnicians: Int,
        features: [String]
    ) {
        self.businessID = UUID()
        self.businessName = businessName
        self.businessType = businessType
        self.industryType = industryType
        self.fleetSize = fleetSize
        self.subscriptionPlan = subscriptionPlan
        self.billingPeriod = billingPeriod
        self.managementStructure = managementStructure
        self.maxVehicles = maxVehicles
        self.maxManagers = maxManagers
        self.maxTechnicians = maxTechnicians
        self.features = features
        self.isActive = true
        self.createdAt = Date()
        self.updatedAt = Date()
        self.userAccounts = [] // Initialize the optional relationship
    }
}

@Model
class UserAccount {
    var userID: UUID = UUID() // Remove unique constraint for CloudKit
    var fullName: String = ""
    var email: String = ""
    var passwordHash: String = ""
    var accountType: AccountType = AccountType.technician
    @Attribute(.transformable(by: StringArrayTransformer.self)) var permissions: [Permission] = []
    @Attribute(.transformable(by: StringArrayTransformer.self)) var departmentAccess: [String] = [] // For managers with limited access
    @Attribute(.transformable(by: StringArrayTransformer.self)) var locationAccess: [String] = [] // For multi-location businesses
    var isActive: Bool = true
    var lastLoginAt: Date? // Already optional
    var createdAt: Date = Date()
    var invitedBy: UUID? // Who invited this user - already optional
    
    // Relationships
    @Relationship var businessAccount: BusinessAccount?
    
    init(
        fullName: String,
        email: String,
        passwordHash: String,
        accountType: AccountType,
        permissions: [Permission] = [],
        departmentAccess: [String] = [],
        locationAccess: [String] = []
    ) {
        self.userID = UUID()
        self.fullName = fullName
        self.email = email
        self.passwordHash = passwordHash
        self.accountType = accountType
        self.permissions = permissions
        self.departmentAccess = departmentAccess
        self.locationAccess = locationAccess
        self.isActive = true
        self.createdAt = Date()
    }
    
    // MARK: - Permission Checking
    
    func hasPermission(_ permission: Permission) -> Bool {
        return permissions.contains(permission) || accountType.defaultPermissions.contains(permission)
    }
    
    func canAccessDepartment(_ department: String) -> Bool {
        if accountType == .owner { return true }
        return departmentAccess.isEmpty || departmentAccess.contains(department)
    }
    
    func canAccessLocation(_ location: String) -> Bool {
        if accountType == .owner { return true }
        return locationAccess.isEmpty || locationAccess.contains(location)
    }
    
    func canInviteUsers() -> Bool {
        return hasPermission(.manageUsers) && accountType != .technician
    }
    
    func canManageSubscription() -> Bool {
        return accountType == .owner || hasPermission(.manageSubscription)
    }
}

// MARK: - Account Types

enum AccountType: String, CaseIterable, Codable {
    case owner = "Owner"
    case manager = "Manager"
    case technician = "Technician"
    
    var description: String {
        switch self {
        case .owner:
            return "Full access to all business functions"
        case .manager:
            return "Manage assigned departments and technicians"
        case .technician:
            return "Access to assigned vehicles and tasks"
        }
    }
    
    var defaultPermissions: [Permission] {
        switch self {
        case .owner:
            return Permission.allCases
        case .manager:
            return [
                .viewVehicles, .editVehicles, .addVehicles,
                .viewTechnicians, .editTechnicians, .addTechnicians,
                .viewReports, .manageInventory,
                .viewSchedule, .editSchedule
            ]
        case .technician:
            return [
                .viewVehicles, .viewAssignedVehicles,
                .updateVehicleStatus, .viewInventory,
                .viewSchedule, .updateWorkOrders
            ]
        }
    }
    
    var maxUsers: Int {
        switch self {
        case .owner: return 1 // Only one owner per business
        case .manager: return 999 // Limited by subscription
        case .technician: return 999 // Limited by subscription
        }
    }
    
    var canInviteAccountTypes: [AccountType] {
        switch self {
        case .owner: return [.manager, .technician]
        case .manager: return [.technician]
        case .technician: return []
        }
    }
}

// MARK: - Permissions

enum Permission: String, CaseIterable, Codable {
    // Vehicle Management
    case viewVehicles = "view_vehicles"
    case editVehicles = "edit_vehicles"
    case addVehicles = "add_vehicles"
    case deleteVehicles = "delete_vehicles"
    case viewAssignedVehicles = "view_assigned_vehicles"
    case updateVehicleStatus = "update_vehicle_status"
    
    // User Management
    case viewTechnicians = "view_technicians"
    case editTechnicians = "edit_technicians"
    case addTechnicians = "add_technicians"
    case deleteTechnicians = "delete_technicians"
    case manageUsers = "manage_users"
    case viewUserActivity = "view_user_activity"
    
    // Inventory Management
    case viewInventory = "view_inventory"
    case editInventory = "edit_inventory"
    case manageInventory = "manage_inventory"
    case orderParts = "order_parts"
    
    // Scheduling & Work Orders
    case viewSchedule = "view_schedule"
    case editSchedule = "edit_schedule"
    case assignTechnicians = "assign_technicians"
    case updateWorkOrders = "update_work_orders"
    case approveWorkOrders = "approve_work_orders"
    
    // Reports & Analytics
    case viewReports = "view_reports"
    case exportReports = "export_reports"
    case viewAnalytics = "view_analytics"
    case viewFinancials = "view_financials"
    
    // Business Settings
    case manageSettings = "manage_settings"
    case manageSubscription = "manage_subscription"
    case manageIntegrations = "manage_integrations"
    case viewAuditLogs = "view_audit_logs"
    
    var displayName: String {
        switch self {
        case .viewVehicles: return "View Vehicles"
        case .editVehicles: return "Edit Vehicles"
        case .addVehicles: return "Add Vehicles"
        case .deleteVehicles: return "Delete Vehicles"
        case .viewAssignedVehicles: return "View Assigned Vehicles"
        case .updateVehicleStatus: return "Update Vehicle Status"
        case .viewTechnicians: return "View Technicians"
        case .editTechnicians: return "Edit Technicians"
        case .addTechnicians: return "Add Technicians"
        case .deleteTechnicians: return "Delete Technicians"
        case .manageUsers: return "Manage Users"
        case .viewUserActivity: return "View User Activity"
        case .viewInventory: return "View Inventory"
        case .editInventory: return "Edit Inventory"
        case .manageInventory: return "Manage Inventory"
        case .orderParts: return "Order Parts"
        case .viewSchedule: return "View Schedule"
        case .editSchedule: return "Edit Schedule"
        case .assignTechnicians: return "Assign Technicians"
        case .updateWorkOrders: return "Update Work Orders"
        case .approveWorkOrders: return "Approve Work Orders"
        case .viewReports: return "View Reports"
        case .exportReports: return "Export Reports"
        case .viewAnalytics: return "View Analytics"
        case .viewFinancials: return "View Financials"
        case .manageSettings: return "Manage Settings"
        case .manageSubscription: return "Manage Subscription"
        case .manageIntegrations: return "Manage Integrations"
        case .viewAuditLogs: return "View Audit Logs"
        }
    }
    
    var category: PermissionCategory {
        switch self {
        case .viewVehicles, .editVehicles, .addVehicles, .deleteVehicles, .viewAssignedVehicles, .updateVehicleStatus:
            return .vehicleManagement
        case .viewTechnicians, .editTechnicians, .addTechnicians, .deleteTechnicians, .manageUsers, .viewUserActivity:
            return .userManagement
        case .viewInventory, .editInventory, .manageInventory, .orderParts:
            return .inventoryManagement
        case .viewSchedule, .editSchedule, .assignTechnicians, .updateWorkOrders, .approveWorkOrders:
            return .scheduling
        case .viewReports, .exportReports, .viewAnalytics, .viewFinancials:
            return .reportsAnalytics
        case .manageSettings, .manageSubscription, .manageIntegrations, .viewAuditLogs:
            return .businessSettings
        }
    }
}

enum PermissionCategory: String, CaseIterable {
    case vehicleManagement = "Vehicle Management"
    case userManagement = "User Management"
    case inventoryManagement = "Inventory Management"
    case scheduling = "Scheduling"
    case reportsAnalytics = "Reports & Analytics"
    case businessSettings = "Business Settings"
}

// MARK: - Subscription Tier Limitations

struct SubscriptionLimitations {
    let maxVehicles: Int
    let maxManagers: Int
    let maxTechnicians: Int
    let maxLocations: Int
    let features: [String]
    let canCreateManagers: Bool
    let canAccessReports: Bool
    let canUseIntegrations: Bool
    
    static func limitations(for plan: SubscriptionPlan) -> SubscriptionLimitations {
        switch plan {
        case .trial:
            return SubscriptionLimitations(
                maxVehicles: 5,
                maxManagers: 1,
                maxTechnicians: 5,
                maxLocations: 1,
                features: ["Trial access", "Basic vehicle tracking", "Email support"],
                canCreateManagers: false,
                canAccessReports: false,
                canUseIntegrations: false
            )
        case .basic:
            return SubscriptionLimitations(
                maxVehicles: 5,
                maxManagers: 1,
                maxTechnicians: 5,
                maxLocations: 1,
                features: ["Basic vehicle tracking", "Email support"],
                canCreateManagers: false,
                canAccessReports: false,
                canUseIntegrations: false
            )
        case .pro:
            return SubscriptionLimitations(
                maxVehicles: 15,
                maxManagers: 4,
                maxTechnicians: 15,
                maxLocations: 3,
                features: ["Advanced reporting", "Multi-location", "Priority support"],
                canCreateManagers: true,
                canAccessReports: true,
                canUseIntegrations: false
            )
        case .enterprise:
            return SubscriptionLimitations(
                maxVehicles: 999,
                maxManagers: 999,
                maxTechnicians: 999,
                maxLocations: 999,
                features: ["Unlimited everything", "Custom integrations", "Dedicated support"],
                canCreateManagers: true,
                canAccessReports: true,
                canUseIntegrations: true
            )
        }
    }
}

// MARK: - Account Creation Helpers

extension BusinessSetupInfo {
    func createBusinessPlan() -> BusinessPlan {
        switch managementStructure {
        case .singleManager:
            return .basic
        case .multipleManagers:
            return estimatedManagerCount <= 4 ? .pro : .enterprise
        case .hierarchical:
            return .enterprise
        }
    }
    
    func createOwnerAccount(passwordHash: String) -> UserAccount {
        let permissions: [Permission] = managementStructure == .singleManager
            ? AccountType.owner.defaultPermissions
            : Permission.allCases
        
        return UserAccount(
            fullName: primaryManagerName,
            email: primaryManagerEmail,
            passwordHash: passwordHash,
            accountType: .owner,
            permissions: permissions
        )
    }
}

// MARK: - First-Time Setup State

@Model
class FirstTimeSetupState {
    var setupID: UUID = UUID() // Remove unique constraint for CloudKit
    var isCompleted: Bool = false
    var hasShownWalkthrough: Bool = false
    var businessAccountID: UUID? // Already optional
    var createdAt: Date = Date()
    
    init() {
        self.setupID = UUID()
        self.isCompleted = false
        self.hasShownWalkthrough = false
        self.createdAt = Date()
    }
} 