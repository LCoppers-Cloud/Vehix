import SwiftUI
import SwiftData


struct SettingsView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authService: AppAuthService
    @EnvironmentObject var cloudKitManager: CloudKitManager
    @EnvironmentObject var storeKitManager: StoreKitManager
    @EnvironmentObject var aiDataManager: AISharedDataManager
    
    @State private var showServiceTitanSettings = false
    @State private var showSamsaraSettings = false
    @State private var showNotificationSettings = false
    @State private var showAccountSettings = false
    @State private var showSubscriptionSheet = false
    @State private var showTechnicianManagement = false
    @State private var showUserManagement = false
    @State private var showBusinessManagement = false
    
    // Developer mode states
    @State private var devModeEnabled = false
    @State private var tapCount = 0
    
    // Integration services
    @StateObject private var serviceTitanService = ServiceTitanService()
    @StateObject private var samsaraService = SamsaraService()
    
    @State private var showClearDataConfirmation = false
    @State private var showClearInventoryConfirmation = false
    
    var accentColor: Color {
        colorScheme == .dark ? Color(red: 0.2, green: 0.5, blue: 0.9) : Color(red: 0.2, green: 0.5, blue: 0.9)
    }
    
    var body: some View {
        // Remove NavigationView to prevent conflicts when presented as sheet
        List {
            AccountSection(
                authService: authService,
                cloudKitManager: cloudKitManager,
                storeKitManager: storeKitManager,
                accentColor: accentColor,
                showAccountSettings: $showAccountSettings,
                showSubscriptionSheet: $showSubscriptionSheet,
                showTechnicianManagement: $showTechnicianManagement,
                showUserManagement: $showUserManagement,
                showBusinessManagement: $showBusinessManagement
            )
            
            IntegrationsSection(
                serviceTitanService: serviceTitanService,
                samsaraService: samsaraService,
                showServiceTitanSettings: $showServiceTitanSettings,
                showSamsaraSettings: $showSamsaraSettings
            )
            
            // AI & Privacy Section
            AIPrivacySection(aiDataManager: aiDataManager)
            
            // Add Warehouse Management Section
            if authService.currentUser?.userRole == .admin || authService.currentUser?.userRole == .dealer || authService.currentUser?.userRole == .premium {
                WarehouseManagementSection()
            }
            
            AppSettingsSection()
            
            AboutSection(devModeEnabled: $devModeEnabled, tapCount: $tapCount)
            
            if authService.currentUser?.userRole == .admin || authService.currentUser?.userRole == .dealer || authService.currentUser?.userRole == .premium {
                DataManagementSection(
                    showClearDataConfirmation: $showClearDataConfirmation,
                    showClearInventoryConfirmation: $showClearInventoryConfirmation
                )
            }
            
            if devModeEnabled {
                DeveloperSection(authService: authService, modelContext: modelContext)
            }
        }
        .listStyle(InsetGroupedListStyle())
        .onAppear {
            serviceTitanService.loadConfiguration()
            samsaraService.loadConfiguration()
        }
        .alert("Clear App Data", isPresented: $showClearDataConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All Data", role: .destructive) {
                authService.clearUserData()
            }
        } message: {
            Text("This will delete all tasks, vehicles, and staff (except your user). This action cannot be undone. Are you sure you want to continue?")
        }
        .alert("Clear Inventory Data", isPresented: $showClearInventoryConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear Inventory", role: .destructive) {
                authService.clearInventoryData()
            }
        } message: {
            Text("This will delete all inventory items, warehouses, and stock locations. This action cannot be undone. Are you sure you want to continue?")
        }
    }
}

// MARK: - Account Section
struct AccountSection: View {
    let authService: AppAuthService
    let cloudKitManager: CloudKitManager
    let storeKitManager: StoreKitManager
    let accentColor: Color
    @Binding var showAccountSettings: Bool
    @Binding var showSubscriptionSheet: Bool
    @Binding var showTechnicianManagement: Bool
    @Binding var showUserManagement: Bool
    @Binding var showBusinessManagement: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            userInfoSection
            dataSyncSection
            subscriptionSection
            managementButtons
            signOutSection
        }
    }
    
    @ViewBuilder
    private var userInfoSection: some View {
        if let user = authService.currentUser {
            UserInfoView(user: user, accentColor: accentColor, showAccountSettings: $showAccountSettings)
        }
    }
    
    @ViewBuilder
    private var dataSyncSection: some View {
        DataSyncStatusView(cloudKitManager: cloudKitManager)
    }
    
    @ViewBuilder
    private var subscriptionSection: some View {
        SubscriptionButtonView(
            showSubscriptionSheet: $showSubscriptionSheet,
            storeKitManager: storeKitManager,
            authService: authService
        )
    }
    
    @ViewBuilder
    private var managementButtons: some View {
        // Business Management (for owners and managers)
        if isBusinessManagementAllowed {
            BusinessManagementButtonView(
                showBusinessManagement: $showBusinessManagement,
                authService: authService,
                storeKitManager: storeKitManager
            )
        }
        
        if authService.currentUser?.userRole == .admin || authService.currentUser?.userRole == .dealer || authService.currentUser?.userRole == .premium {
            TechnicianManagementButtonView(
                showTechnicianManagement: $showTechnicianManagement,
                authService: authService
            )
        }
        
        if isUserManagementAllowed {
            UserManagementButtonView(
                showUserManagement: $showUserManagement, 
                authService: authService
            )
        }
    }
    
    @ViewBuilder
    private var signOutSection: some View {
        SignOutButtonView(authService: authService)
    }
    
    private var isUserManagementAllowed: Bool {
        guard let userRole = authService.currentUser?.userRole else { return false }
        return userRole == .admin || userRole == .dealer || userRole == .premium
    }
    
    private var isBusinessManagementAllowed: Bool {
        guard let userRole = authService.currentUser?.userRole else { return false }
        return userRole == .owner || userRole == .admin || userRole == .dealer || userRole == .premium
    }
}

// MARK: - Integrations Section
struct IntegrationsSection: View {
    let serviceTitanService: ServiceTitanService
    let samsaraService: SamsaraService
    @Binding var showServiceTitanSettings: Bool
    @Binding var showSamsaraSettings: Bool
    
    var body: some View {
        Group {
            ServiceTitanIntegrationView(
                service: serviceTitanService,
                showSettings: $showServiceTitanSettings
            )
            
            SamsaraIntegrationView(
                service: samsaraService,
                showSettings: $showSamsaraSettings
            )
        }
    }
}

// MARK: - User Info View
struct UserInfoView: View {
    let user: AppUser
    let accentColor: Color
    @Binding var showAccountSettings: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(user.fullName ?? user.email)
                    .font(.headline)
                Text(user.email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("Role: \(user.userRole.rawValue.capitalized)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                showAccountSettings = true
            }) {
                Image(systemName: "pencil.circle")
                    .font(.title2)
                    .foregroundColor(accentColor)
            }
        }
    }
}

// MARK: - Data Sync Status View
struct DataSyncStatusView: View {
    let cloudKitManager: CloudKitManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "icloud.fill")
                    .foregroundColor(cloudKitManager.isCloudKitAvailable ? .blue : .gray)
                Text("Data Sync")
                    .font(.headline)
                Spacer()
                Text(cloudKitManager.syncStatus)
                    .font(.caption)
                    .foregroundColor(cloudKitManager.isCloudKitAvailable ? .green : .orange)
            }
            
            Text(cloudKitManager.getDataRetentionInfo())
                .font(.caption)
                .foregroundColor(.secondary)
            
            if case .gracePeriod(let daysRemaining) = cloudKitManager.subscriptionStatus {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Data will be deleted in \(daysRemaining) days")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Business Management Button View
struct BusinessManagementButtonView: View {
    @Binding var showBusinessManagement: Bool
    let authService: AppAuthService
    let storeKitManager: StoreKitManager
    
    var body: some View {
        Button(action: { showBusinessManagement = true }) {
            HStack {
                Image(systemName: "building.2.fill")
                    .foregroundColor(Color.vehixBlue)
                    .font(.title2)
                VStack(alignment: .leading) {
                    Text("Business Management")
                        .font(.headline)
                    Text("Company info, usage analytics, and subscription billing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding(10)
            .background(Color.vehixBlue.opacity(0.08))
            .cornerRadius(12)
        }
        .sheet(isPresented: $showBusinessManagement) {
            EnhancedBusinessManagementView()
                .environmentObject(authService)
                .environmentObject(storeKitManager)
        }
    }
}

// MARK: - Subscription Button View
struct SubscriptionButtonView: View {
    @Binding var showSubscriptionSheet: Bool
    let storeKitManager: StoreKitManager
    let authService: AppAuthService
    
    var body: some View {
        Button(action: { showSubscriptionSheet = true }) {
            HStack {
                Image(systemName: "creditcard.fill")
                    .foregroundColor(.accentColor)
                    .font(.title2)
                VStack(alignment: .leading) {
                    Text("Manage Subscription")
                        .font(.headline)
                    Text("View, upgrade, or cancel your plan")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding(10)
            .background(Color.accentColor.opacity(0.08))
            .cornerRadius(12)
        }
        .sheet(isPresented: $showSubscriptionSheet) {
            AppleSubscriptionManagementView()
                .environmentObject(storeKitManager)
                .environmentObject(authService)
        }
    }
}

// MARK: - Technician Management Button View
struct TechnicianManagementButtonView: View {
    @Binding var showTechnicianManagement: Bool
    let authService: AppAuthService
    
    var body: some View {
        Button(action: { showTechnicianManagement = true }) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(Color.vehixGreen)
                    .font(.title2)
                VStack(alignment: .leading) {
                    Text("Manage Technicians")
                        .font(.headline)
                    Text("Assign technicians to vehicles and track GPS locations")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding(10)
            .background(Color.vehixGreen.opacity(0.08))
            .cornerRadius(12)
        }
        .sheet(isPresented: $showTechnicianManagement) {
            EnhancedTechnicianManagementView()
                .environmentObject(authService)
        }
    }
}

// MARK: - User Management Button View
struct UserManagementButtonView: View {
    @Binding var showUserManagement: Bool
    let authService: AppAuthService
    
    var body: some View {
        Button(action: { showUserManagement = true }) {
            HStack {
                Image(systemName: "person.3.fill")
                    .foregroundColor(Color.vehixOrange)
                    .font(.title2)
                VStack(alignment: .leading) {
                    Text("User Management")
                        .font(.headline)
                    Text("Manage user roles, permissions, and account access levels")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding(10)
            .background(Color.vehixOrange.opacity(0.08))
            .cornerRadius(12)
        }
        .sheet(isPresented: $showUserManagement) {
            EnhancedUserManagementView()
                .environmentObject(authService)
        }
    }
}

// MARK: - Sign Out Button View
struct SignOutButtonView: View {
    let authService: AppAuthService
    
    var body: some View {
        Button(action: {
            authService.signOut()
        }) {
            HStack {
                Image(systemName: "arrow.right.square")
                Text("Sign Out")
            }
            .foregroundColor(.red)
        }
    }
}



// MARK: - ServiceTitan Integration View
struct ServiceTitanIntegrationView: View {
    let service: ServiceTitanService
    @Binding var showSettings: Bool
    
    var body: some View {
        Button(action: {
            showSettings = true
        }) {
            HStack {
                Image(systemName: "link.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                VStack(alignment: .leading) {
                    Text("ServiceTitan Integration")
                        .font(.headline)
                    Text("Sync POs, inventory, and technicians")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if service.isConnected {
                    Text("Connected")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Text("Not Connected")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
        }
        .sheet(isPresented: $showSettings) {
            ServiceTitanSettingsView(service: service)
        }
    }
}

// MARK: - Samsara Integration View
struct SamsaraIntegrationView: View {
    let service: SamsaraService
    @Binding var showSettings: Bool
    
    var body: some View {
        Button(action: {
            showSettings = true
        }) {
            HStack {
                Image(systemName: "location.circle.fill")
                    .foregroundColor(.orange)
                    .font(.title2)
                VStack(alignment: .leading) {
                    Text("Samsara Integration")
                        .font(.headline)
                    Text("Vehicle tracking and mileage monitoring")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if service.isConnected {
                    Text("Connected")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Text("Not Connected")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
        }
        .sheet(isPresented: $showSettings) {
            SamsaraSettingsView(service: service)
        }
    }
}

// MARK: - App Settings Section
struct AppSettingsSection: View {
    var body: some View {
        Section {
            NavigationLink(destination: NotificationPreferencesView()) {
                HStack {
                    Image(systemName: "bell.fill")
                        .foregroundColor(.purple)
                    Text("Notification Preferences")
                    Spacer()
                }
            }
            
            NavigationLink(destination: OilChangeReminderSettingsView()) {
                HStack {
                    Image(systemName: "drop.fill")
                        .foregroundColor(.red)
                    Text("Oil Change Reminders")
                }
            }
            
            NavigationLink(destination: AppearanceSettingsView()) {
                HStack {
                    Image(systemName: "paintbrush.fill")
                        .foregroundColor(.yellow)
                    Text("Appearance")
                }
            }
        } header: {
            Text("Application Settings")
        }
    }
}

// MARK: - About Section
struct AboutSection: View {
    @Binding var devModeEnabled: Bool
    @Binding var tapCount: Int
    
    var body: some View {
        Section {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("Version")
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }
            .onTapGesture {
                tapCount += 1
                if tapCount >= 7 {
                    devModeEnabled = true
                    tapCount = 0
                }
            }
            
            NavigationLink(destination: PrivacyPolicyView()) {
                HStack {
                    Image(systemName: "hand.raised.fill")
                        .foregroundColor(Color.vehixGreen)
                    Text("Privacy Policy")
                }
            }
            
            NavigationLink(destination: TermsOfServiceView()) {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(Color.vehixOrange)
                    Text("Terms of Service")
                }
            }
        } header: {
            Text("About")
        }
    }
}

// MARK: - Data Management Section
struct DataManagementSection: View {
    @Binding var showClearDataConfirmation: Bool
    @Binding var showClearInventoryConfirmation: Bool
    
    var body: some View {
        Section {
            Button(action: {
                showClearDataConfirmation = true
            }) {
                HStack {
                    Image(systemName: "trash.fill")
                        .foregroundColor(.red)
                    Text("Clear Tasks, Vehicles & Staff")
                        .foregroundColor(.red)
                }
            }
            
            Button(action: {
                showClearInventoryConfirmation = true
            }) {
                HStack {
                    Image(systemName: "cube.box.fill")
                        .foregroundColor(.red)
                    Text("Clear Inventory Data")
                        .foregroundColor(.red)
                }
            }
        } header: {
            Text("Data Management")
        }
    }
}

// MARK: - Developer Section
struct DeveloperSection: View {
    let authService: AppAuthService
    let modelContext: ModelContext
    @State private var showPromoteConfirmation = false
    @State private var showSchemaTestingSheet = false
    
    var body: some View {
        Section {
            NavigationLink(destination: SchemaTestingView()) {
                HStack {
                    Image(systemName: "externaldrive.connected.to.line.below")
                        .foregroundColor(.blue)
                    Text("Schema Testing")
                    Spacer()
                    Text("CloudKit")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            NavigationLink(destination: DeveloperCloudKitDocumentationView()) {
                HStack {
                    Image(systemName: "cloud.fill")
                        .foregroundColor(.purple)
                    Text("CloudKit Documentation")
                }
            }
            
            Button(action: {
                showPromoteConfirmation = true
            }) {
                HStack {
                    Image(systemName: "person.badge.key.fill")
                        .foregroundColor(.orange)
                    Text("Promote to Admin")
                        .foregroundColor(.orange)
                }
            }
            .alert("Promote to Admin", isPresented: $showPromoteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Promote", role: .destructive) {
                    promoteCurrentUserToAdmin()
                }
            } message: {
                Text("This will promote your current account to admin level access for testing purposes.")
            }
            

            
            Button(action: {
                clearAllUsersExceptCurrent()
            }) {
                HStack {
                    Image(systemName: "trash.fill")
                        .foregroundColor(.red)
                    Text("🚨 Clear ALL Users (Keep Only Me)")
                        .foregroundColor(.red)
                }
            }
            
        } header: {
            Text("Developer Options")
        }
    }
    
    private func promoteCurrentUserToAdmin() {
        guard let currentUser = authService.currentUser else { return }
        
        currentUser.userRole = .admin
        
        do {
            try modelContext.save()
            print("✅ Promoted user to admin: \(currentUser.email)")
        } catch {
            print("❌ Failed to promote user: \(error)")
        }
    }
    
    // Sample technician clearing removed - no longer needed for production
    
    private func clearAllUsersExceptCurrent() {
        Task { @MainActor in
            do {
                guard let currentUser = authService.currentUser else {
                    print("❌ No current user found")
                    return
                }
                
                // Fetch all users safely
                let descriptor = FetchDescriptor<AppUser>()
                let allUsers = try modelContext.fetch(descriptor)
                
                // Filter out current user and already deleted users
                let usersToDelete = allUsers.filter { user in
                    user.id != currentUser.id && 
                    user.email != currentUser.email && 
                    !user.isDeleted
                }
                
                guard !usersToDelete.isEmpty else {
                    print("✅ No users to delete - only current user exists")
                    return
                }
                
                print("🧹 Deleting \(usersToDelete.count) users...")
                
                // Delete users safely one by one
                for user in usersToDelete {
                    if !user.isDeleted {
                        modelContext.delete(user)
                    }
                }
                
                try modelContext.save()
                print("✅ Cleared \(usersToDelete.count) users (kept current user: \(currentUser.email))")
            } catch {
                print("❌ Failed to clear users: \(error)")
                // Don't crash the app if cleanup fails
            }
        }
    }
}

struct ServiceTitanSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var service: ServiceTitanService
    
    @State private var clientId: String = ""
    @State private var tenantId: String = ""
    @State private var clientSecret: String = ""
    @State private var syncInventory: Bool = true
    @State private var syncTechnicians: Bool = true
    @State private var syncVendors: Bool = true
    @State private var syncPurchaseOrders: Bool = true
    @State private var isTesting: Bool = false
    @State private var showSuccessAlert: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text("Connect Vehix to your ServiceTitan account to sync inventory, technicians, and purchase orders. You'll need administrator access to your ServiceTitan account to get the required credentials.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("About ServiceTitan Integration")
                }
                
                Section {
                    TextField("Client ID", text: $clientId)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    
                    TextField("Tenant ID", text: $tenantId)
                        .keyboardType(.numberPad)
                    
                    SecureField("Client Secret", text: $clientSecret)
                } header: {
                    Text("API Credentials")
                }
                
                Section {
                    Toggle("Sync Inventory", isOn: $syncInventory)
                    Toggle("Sync Technicians", isOn: $syncTechnicians)
                    Toggle("Sync Vendors", isOn: $syncVendors)
                    Toggle("Sync Purchase Orders", isOn: $syncPurchaseOrders)
                } header: {
                    Text("Sync Settings")
                }
                
                Section {
                    Button(action: testConnection) {
                        if isTesting {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                Spacer()
                            }
                        } else {
                            HStack {
                                Spacer()
                                Text("Test Connection")
                                    .bold()
                                Spacer()
                            }
                        }
                    }
                    .disabled(isTesting || clientId.isEmpty || tenantId.isEmpty || clientSecret.isEmpty)
                    
                    Button(action: saveSettings) {
                        HStack {
                            Spacer()
                            Text("Save Settings")
                                .bold()
                            Spacer()
                        }
                    }
                    .disabled(isTesting || clientId.isEmpty || tenantId.isEmpty || clientSecret.isEmpty)
                }
                
                if let lastSync = service.lastSyncDate {
                    Section {
                        HStack {
                            Text("Last Sync")
                            Spacer()
                            Text("\(formattedDate(lastSync))")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("ServiceTitan Integration")
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
            .onAppear(perform: loadSettings)
            .alert("Connection Successful", isPresented: $showSuccessAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Successfully connected to ServiceTitan.")
            }
            .alert("Connection Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func loadSettings() {
        // Load service settings from UserDefaults
        let config = ServiceTitanUserConfig.load()
        clientId = config.clientId
        tenantId = config.tenantId > 0 ? "\(config.tenantId)" : ""
        clientSecret = config.getClientSecret()
        syncInventory = config.syncInventory
        syncTechnicians = config.syncTechnicians
        syncVendors = config.syncVendors
        syncPurchaseOrders = config.syncPurchaseOrders
    }
    
    private func saveSettings() {
        var config = ServiceTitanUserConfig.load()
        
        config.clientId = clientId
        config.tenantId = Int64(tenantId) ?? 0
        config.setClientSecret(clientSecret)
        config.syncInventory = syncInventory
        config.syncTechnicians = syncTechnicians
        config.syncVendors = syncVendors
        config.syncPurchaseOrders = syncPurchaseOrders
        config.updatedAt = Date()
        
        config.save()
        service.loadConfiguration()
        showSuccessAlert = true
    }
    
    private func testConnection() {
        isTesting = true
        
        // Test connection with current values
        var config = ServiceTitanUserConfig.load()
        config.clientId = clientId
        config.tenantId = Int64(tenantId) ?? 0
        config.setClientSecret(clientSecret)
        
        // Use service to test connection
        service.testConnection { success, error in
            isTesting = false
            
            if success {
                showSuccessAlert = true
            } else {
                errorMessage = error ?? "Unknown error"
                showErrorAlert = true
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct SamsaraSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var service: SamsaraService
    
    @State private var apiKey: String = ""
    @State private var organizationId: String = ""
    @State private var isEnabled: Bool = false
    @State private var syncIntervalMinutes: Int = 30
    @State private var isTesting: Bool = false
    @State private var showSuccessAlert: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text("Connect Vehix to your Samsara fleet management system to automatically track vehicle mileage and location. This integration enables automatic reminders for oil changes and service based on actual mileage data.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("About Samsara Integration")
                }
                
                Section {
                    TextField("API Key", text: $apiKey)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    
                    TextField("Organization ID", text: $organizationId)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                } header: {
                    Text("API Credentials")
                }
                
                Section {
                    Toggle("Enable Samsara Integration", isOn: $isEnabled)
                    
                    Stepper(value: $syncIntervalMinutes, in: 5...120, step: 5) {
                        Text("Sync Interval: \(syncIntervalMinutes) minutes")
                    }
                } header: {
                    Text("Sync Settings")
                }
                
                Section {
                    Button(action: testConnection) {
                        if isTesting {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                Spacer()
                            }
                        } else {
                            HStack {
                                Spacer()
                                Text("Test Connection")
                                    .bold()
                                Spacer()
                            }
                        }
                    }
                    .disabled(isTesting || apiKey.isEmpty || organizationId.isEmpty)
                    
                    Button(action: saveSettings) {
                        HStack {
                            Spacer()
                            Text("Save Settings")
                                .bold()
                            Spacer()
                        }
                    }
                    .disabled(isTesting || apiKey.isEmpty || organizationId.isEmpty)
                }
                
                Section {
                    NavigationLink(destination: SamsaraVehiclesView()) {
                        HStack {
                            Image(systemName: "car.2.fill")
                            Text("Manage Tracked Vehicles")
                        }
                    }
                } header: {
                    Text("Vehicle Management")
                }
                
                if let lastSync = service.lastSyncDate {
                    Section {
                        HStack {
                            Text("Last Sync")
                            Spacer()
                            Text("\(formattedDate(lastSync))")
                                .foregroundColor(.secondary)
                        }
                        
                        Button(action: syncNow) {
                            HStack {
                                Spacer()
                                Text("Sync Now")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Samsara Integration")
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
            .onAppear(perform: loadSettings)
            .alert("Connection Successful", isPresented: $showSuccessAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Successfully connected to Samsara.")
            }
            .alert("Connection Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
        .onAppear {
            service.modelContext = modelContext
            service.loadConfiguration()
        }
    }
    
    private func loadSettings() {
        do {
            let configs = try modelContext.fetch(FetchDescriptor<SamsaraConfig>())
            if let config = configs.first {
                // Retrieve API key securely from Keychain
                apiKey = config.getApiKey()
                organizationId = config.organizationId ?? ""
                isEnabled = config.isEnabled
                syncIntervalMinutes = config.syncIntervalMinutes
            }
        } catch {
            print("Error loading Samsara config: \(error)")
        }
    }
    
    private func saveSettings() {
        do {
            let configs = try modelContext.fetch(FetchDescriptor<SamsaraConfig>())
            let config = configs.first ?? SamsaraConfig()
            
            // Securely store API key using KeychainServices
            config.setApiKey(apiKey)
            
            config.organizationId = organizationId
            config.isEnabled = isEnabled
            config.syncIntervalMinutes = syncIntervalMinutes
            config.updatedAt = Date()
            
            if configs.isEmpty {
                modelContext.insert(config)
            }
            
            try modelContext.save()
            service.loadConfiguration()
            showSuccessAlert = true
        } catch {
            errorMessage = "Failed to save settings: \(error.localizedDescription)"
            showErrorAlert = true
        }
    }
    
    private func testConnection() {
        isTesting = true
        
        // Create temporary config for testing
        let config = SamsaraConfig()
        config.setApiKey(apiKey)
        config.organizationId = organizationId
        
        // Use service to test connection
        service.testConnection { success, error in
            isTesting = false
            
            if success {
                showSuccessAlert = true
            } else {
                errorMessage = error ?? "Unknown error"
                showErrorAlert = true
            }
        }
    }
    
    private func syncNow() {
        service.syncAllVehicles { success, error in
            if !success {
                errorMessage = error ?? "Failed to sync vehicles"
                showErrorAlert = true
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct SamsaraVehiclesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var vehicles: [AppVehicle]
    @StateObject private var service = SamsaraService()
    
    var trackedVehicles: [AppVehicle] {
        vehicles.filter { $0.isTrackedBySamsara }
    }
    
    var untrackedVehicles: [AppVehicle] {
        vehicles.filter { !$0.isTrackedBySamsara }
    }
    
    var body: some View {
        List {
            Section {
                if trackedVehicles.isEmpty {
                    Text("No vehicles are currently tracked by Samsara")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(trackedVehicles) { vehicle in
                        VehicleRow(vehicle: vehicle, service: service)
                    }
                }
            } header: {
                Text("Tracked by Samsara (\(trackedVehicles.count))")
            }
            
            Section {
                if untrackedVehicles.isEmpty {
                    Text("No additional vehicles available to track")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(untrackedVehicles) { vehicle in
                        VehicleRow(vehicle: vehicle, service: service)
                    }
                }
            } header: {
                Text("Available Vehicles (\(untrackedVehicles.count))")
            }
        }
        .navigationTitle("Samsara Vehicles")
        .onAppear {
            service.modelContext = modelContext
            service.loadConfiguration()
        }
    }
}

struct VehicleRow: View {
    @Environment(\.modelContext) private var modelContext
    var vehicle: AppVehicle
    var service: SamsaraService
    
    @State private var isSyncing = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("\(vehicle.year) \(vehicle.make) \(vehicle.model)")
                    .font(.headline)
                Text(vehicle.licensePlate ?? "No Plate")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if vehicle.isTrackedBySamsara {
                    HStack {
                        Text("Mileage: \(vehicle.mileage)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let location = vehicle.lastKnownLocation,
                           let _ = vehicle.lastLocationUpdateDate {
                            Text("• \(location)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            if vehicle.isTrackedBySamsara {
                HStack {
                    Button(action: syncVehicle) {
                        if isSyncing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.blue)
                        }
                    }
                    .disabled(isSyncing)
                    
                    Button(action: toggleTracking) {
                        Image(systemName: "x.circle")
                            .foregroundColor(.red)
                    }
                    .disabled(isSyncing)
                }
            } else {
                Button(action: toggleTracking) {
                    Text("Track")
                        .foregroundColor(.blue)
                }
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Error"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func toggleTracking() {
        vehicle.isTrackedBySamsara.toggle()
        
        if vehicle.isTrackedBySamsara {
            connectVehicleToSamsara()
        } else {
            vehicle.samsaraVehicleId = nil
        }
        
        do {
            try modelContext.save()
        } catch {
            alertMessage = "Failed to update vehicle tracking status: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    private func syncVehicle() {
        guard vehicle.isTrackedBySamsara else { return }
        
        isSyncing = true
        
        service.syncVehicle(vehicle) { success, error in
            isSyncing = false
            
            if !success {
                alertMessage = error ?? "Failed to sync vehicle"
                showAlert = true
            }
        }
    }
    
    private func connectVehicleToSamsara() {
        // Generate a proper Samsara vehicle ID
        // PRODUCTION MODE: Use proper ID generation instead of random
        vehicle.samsaraVehicleId = "SAM-\(vehicle.id.prefix(8))" // Use actual vehicle ID prefix
        vehicle.isTrackedBySamsara = true
        
        // Save the changes
        do {
            try modelContext.save()
            isSyncing = false
            showAlert = false
        } catch {
            print("Error connecting vehicle to Samsara: \(error)")
        }
    }
}

// MARK: - Notification Preferences View
struct NotificationPreferencesView: View {
    @State private var techniciansAssignedEnabled = true
    @State private var techniciansCompletedEnabled = true
    @State private var inventoryLowEnabled = true
    @State private var dailySummaryEnabled = false
    @State private var purchaseOrderStatusEnabled = true
    @State private var vehicleMaintenanceEnabled = true
    @State private var staffAvailabilityEnabled = false
    @State private var taskOverdueEnabled = true
    
    // Helper function to save UserDefaults value
    private func saveUserDefault(value: Bool, key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
    
    var body: some View {
        Form {
            Section("Technician Notifications") {
                Toggle("Tasks Assigned", isOn: $techniciansAssignedEnabled)
                Toggle("Tasks Completed", isOn: $techniciansCompletedEnabled)
                Toggle("Staff Availability Updates", isOn: $staffAvailabilityEnabled)
            }
            
            Section("Inventory Notifications") {
                Toggle("Low Stock Alerts", isOn: $inventoryLowEnabled)
                Toggle("Purchase Order Status", isOn: $purchaseOrderStatusEnabled)
            }
            
            Section("Vehicle Notifications") {
                Toggle("Maintenance Reminders", isOn: $vehicleMaintenanceEnabled)
                Toggle("Overdue Tasks", isOn: $taskOverdueEnabled)
            }
            
            Section("General Notifications") {
                Toggle("Daily Summary Report", isOn: $dailySummaryEnabled)
            }
            
            Section {
                Text("You'll receive push notifications for the selected items. Make sure notifications are enabled for Vehix in your device settings.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("About Notifications")
            } footer: {
                Text("Notifications help you stay updated on important events in your fleet and inventory management. You can always change these settings later.")
            }
        }
        .navigationTitle("Notification Settings")
        .onAppear {
            // Load saved preferences from UserDefaults
            techniciansAssignedEnabled = UserDefaults.standard.bool(forKey: "notification.tech.assigned")
            techniciansCompletedEnabled = UserDefaults.standard.bool(forKey: "notification.tech.completed")
            inventoryLowEnabled = UserDefaults.standard.bool(forKey: "notification.inventory.low")
            dailySummaryEnabled = UserDefaults.standard.bool(forKey: "notification.summary.daily")
            purchaseOrderStatusEnabled = UserDefaults.standard.bool(forKey: "notification.po.status")
            vehicleMaintenanceEnabled = UserDefaults.standard.bool(forKey: "notification.vehicle.maintenance")
            staffAvailabilityEnabled = UserDefaults.standard.bool(forKey: "notification.staff.availability")
            taskOverdueEnabled = UserDefaults.standard.bool(forKey: "notification.task.overdue")
        }
        // Break up the complex chain of onChange modifiers
        .onChange(of: techniciansAssignedEnabled) { _, newValue in
            saveUserDefault(value: newValue, key: "notification.tech.assigned")
        }
        .onChange(of: techniciansCompletedEnabled) { _, newValue in
            saveUserDefault(value: newValue, key: "notification.tech.completed")
        }
        .onChange(of: inventoryLowEnabled) { _, newValue in
            saveUserDefault(value: newValue, key: "notification.inventory.low")
        }
        .onChange(of: dailySummaryEnabled) { _, newValue in
            saveUserDefault(value: newValue, key: "notification.summary.daily")
        }
        .onChange(of: purchaseOrderStatusEnabled) { _, newValue in
            saveUserDefault(value: newValue, key: "notification.po.status")
        }
        .onChange(of: vehicleMaintenanceEnabled) { _, newValue in
            saveUserDefault(value: newValue, key: "notification.vehicle.maintenance")
        }
        .onChange(of: staffAvailabilityEnabled) { _, newValue in
            saveUserDefault(value: newValue, key: "notification.staff.availability")
        }
        .onChange(of: taskOverdueEnabled) { _, newValue in
            saveUserDefault(value: newValue, key: "notification.task.overdue")
        }
    }
}

// MARK: - Oil Change Reminder Settings View
struct OilChangeReminderSettingsView: View {
    @State private var remindersEnabled = true
    @State private var reminderDaysBefore = 7
    @State private var reminderMileageBefore = 500
    @State private var sendToTechnicians = true
    @State private var sendToManagers = true
    @State private var reminderFrequency = "Once"
    
    let reminderOptions = ["Once", "Daily", "Weekly"]
    let dayOptions = [3, 5, 7, 10, 14, 30]
    let mileageOptions = [100, 250, 500, 750, 1000]
    
    // Helper functions to save different types of UserDefaults values
    private func saveBoolDefault(value: Bool, key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
    
    private func saveIntDefault(value: Int, key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
    
    private func saveStringDefault(value: String, key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
    
    var body: some View {
        Form {
            Section {
                Toggle("Enable Oil Change Reminders", isOn: $remindersEnabled)
            }
            
            if remindersEnabled {
                Section {
                    Picker("Days Before Due", selection: $reminderDaysBefore) {
                        ForEach(dayOptions, id: \.self) { days in
                            Text("\(days) days").tag(days)
                        }
                    }
                    
                    Picker("At Mileage Before Due", selection: $reminderMileageBefore) {
                        ForEach(mileageOptions, id: \.self) { miles in
                            Text("\(miles) miles").tag(miles)
                        }
                    }
                    
                    Picker("Reminder Frequency", selection: $reminderFrequency) {
                        ForEach(reminderOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                } header: {
                    Text("Reminder Timing")
                }
                
                Section {
                    Toggle("Send to Technicians", isOn: $sendToTechnicians)
                    Toggle("Send to Managers", isOn: $sendToManagers)
                } header: {
                    Text("Recipients")
                }
                
                Section {
                    Text("Oil change reminders are sent based on time and mileage, whichever comes first. Make sure your vehicles have proper maintenance records for accurate reminders.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("About Oil Change Reminders")
                } footer: {
                    Text("Keep your fleet running smoothly with proper oil change maintenance.")
                }
            }
        }
        .navigationTitle("Oil Change Reminders")
        .onAppear {
            // Load saved preferences from UserDefaults
            remindersEnabled = UserDefaults.standard.bool(forKey: "oilchange.enabled")
            reminderDaysBefore = UserDefaults.standard.integer(forKey: "oilchange.days") > 0 ? UserDefaults.standard.integer(forKey: "oilchange.days") : 7
            reminderMileageBefore = UserDefaults.standard.integer(forKey: "oilchange.mileage") > 0 ? UserDefaults.standard.integer(forKey: "oilchange.mileage") : 500
            sendToTechnicians = UserDefaults.standard.bool(forKey: "oilchange.technicians")
            sendToManagers = UserDefaults.standard.bool(forKey: "oilchange.managers")
            reminderFrequency = UserDefaults.standard.string(forKey: "oilchange.frequency") ?? "Once"
        }
        // Break up complex onChange chain into separate modifiers with named closures
        .onChange(of: remindersEnabled) { _, newValue in
            saveBoolDefault(value: newValue, key: "oilchange.enabled")
        }
        .onChange(of: reminderDaysBefore) { _, newValue in
            saveIntDefault(value: newValue, key: "oilchange.days")
        }
        .onChange(of: reminderMileageBefore) { _, newValue in
            saveIntDefault(value: newValue, key: "oilchange.mileage")
        }
        .onChange(of: sendToTechnicians) { _, newValue in
            saveBoolDefault(value: newValue, key: "oilchange.technicians")
        }
        .onChange(of: sendToManagers) { _, newValue in
            saveBoolDefault(value: newValue, key: "oilchange.managers")
        }
        .onChange(of: reminderFrequency) { _, newValue in
            saveStringDefault(value: newValue, key: "oilchange.frequency")
        }
    }
}

// MARK: - Appearance Settings View
struct AppearanceSettingsView: View {
    @AppStorage("app.theme") private var selectedTheme = "Default"
    @AppStorage("app.darkMode") private var darkModePreference = "System"
    @AppStorage("app.fontSizeAdjustment") private var fontSizeAdjustment = 0
    
    let themeOptions = ["Default", "Mr. Rooter Red", "Vehix Blue", "Sunshine Yellow", "Midnight Black"]
    let darkModeOptions = ["System", "Light", "Dark"]
    let fontAdjustmentOptions = [-2, -1, 0, 1, 2]
    
    // Sample theme colors
    let themeColors: [String: Color] = [
        "Default": .blue,
        "Mr. Rooter Red": Color(red: 0.8, green: 0.1, blue: 0.1),
        "Vehix Blue": Color(red: 0.1, green: 0.4, blue: 0.8),
        "Sunshine Yellow": Color(red: 0.9, green: 0.8, blue: 0.0),
        "Midnight Black": Color(red: 0.1, green: 0.1, blue: 0.1)
    ]
    
    // Get current theme color with a fallback
    var currentThemeColor: Color {
        return themeColors[selectedTheme] ?? .blue
    }
    
    // Theme preview components extracted to reduce complexity
    @ViewBuilder
    func primaryButton() -> some View {
        Text("Primary")
            .foregroundColor(.white)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(currentThemeColor)
            .cornerRadius(8)
    }
    
    @ViewBuilder
    func secondaryButton() -> some View {
        Text("Secondary")
            .foregroundColor(currentThemeColor)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(currentThemeColor, lineWidth: 1)
            )
    }
    
    var body: some View {
        Form {
            Section {
                Picker("Color Theme", selection: $selectedTheme) {
                    ForEach(themeOptions, id: \.self) { theme in
                        HStack {
                            Circle()
                                .fill(themeColors[theme] ?? .blue)
                                .frame(width: 20, height: 20)
                            Text(theme)
                        }
                        .tag(theme)
                    }
                }
                .pickerStyle(.navigationLink)
                
                // Theme preview - simplified
                VStack(alignment: .leading) {
                    Text("Theme Preview")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 15) {
                        // Mock buttons using extracted components
                        Button(action: {}) {
                            primaryButton()
                        }
                        .disabled(true)
                        
                        Button(action: {}) {
                            secondaryButton()
                        }
                        .disabled(true)
                        
                        // Mock icon
                        Image(systemName: "car.fill")
                            .font(.title2)
                            .foregroundColor(currentThemeColor)
                    }
                    .padding(.vertical, 8)
                }
            } header: {
                Text("Theme")
            }
            
            Section {
                Picker("Dark Mode", selection: $darkModePreference) {
                    ForEach(darkModeOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                
                Picker("Font Size", selection: $fontSizeAdjustment) {
                    Text("Extra Small").tag(-2)
                    Text("Small").tag(-1)
                    Text("Default").tag(0)
                    Text("Large").tag(1)
                    Text("Extra Large").tag(2)
                }
            } header: {
                Text("Display")
            }
            
            Section {
                Text("Customize how Vehix looks to match your company's branding or personal preference.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("About Appearance")
            } footer: {
                Text("Theme changes will apply the next time you restart the app.")
            }
        }
        .navigationTitle("Appearance")
    }
}

// MARK: - Warehouse Management Section
struct WarehouseManagementSection: View {
    @State private var showingWarehouseSettings = false
    @State private var showingInventorySettings = false
    @State private var showingMapSettings = false
    @State private var showingPermissionSettings = false
    
    var body: some View {
        Section {
            Button(action: { showingWarehouseSettings = true }) {
                HStack {
                    Image(systemName: "building.2.fill")
                        .foregroundColor(Color.brown)
                        .font(.title2)
                    VStack(alignment: .leading) {
                        Text("Warehouse Management")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("Add, remove, and configure warehouse locations")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .padding(10)
                .background(Color.brown.opacity(0.08))
                .cornerRadius(12)
            }
            
            Button(action: { showingInventorySettings = true }) {
                HStack {
                    Image(systemName: "cube.box.fill")
                        .foregroundColor(Color.orange)
                        .font(.title2)
                    VStack(alignment: .leading) {
                        Text("Inventory Tracking")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("Configure warehouse assignments and tracking options")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .padding(10)
                .background(Color.orange.opacity(0.08))
                .cornerRadius(12)
            }
            
            Button(action: { showingMapSettings = true }) {
                HStack {
                    Image(systemName: "map.fill")
                        .foregroundColor(Color.green)
                        .font(.title2)
                    VStack(alignment: .leading) {
                        Text("Map Integration")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("Configure warehouse locations on map")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .padding(10)
                .background(Color.green.opacity(0.08))
                .cornerRadius(12)
            }
            
            Button(action: { showingPermissionSettings = true }) {
                HStack {
                    Image(systemName: "person.3.fill")
                        .foregroundColor(Color.purple)
                        .font(.title2)
                    VStack(alignment: .leading) {
                        Text("Permissions & Access")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("Manage warehouse access permissions")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .padding(10)
                .background(Color.purple.opacity(0.08))
                .cornerRadius(12)
            }
            
        } header: {
            Text("Warehouse & Inventory")
        }
        .sheet(isPresented: $showingWarehouseSettings) {
            WarehouseSettingsView()
        }
        .sheet(isPresented: $showingInventorySettings) {
            InventoryTrackingSettingsView()
        }
        .sheet(isPresented: $showingMapSettings) {
            WarehouseMapSettingsView()
        }
        .sheet(isPresented: $showingPermissionSettings) {
            WarehousePermissionSettingsView()
        }
    }
}

// MARK: - AI & Privacy Section
struct AIPrivacySection: View {
    let aiDataManager: AISharedDataManager
    @State private var showingAISettings = false
    
    var body: some View {
        Section {
            Button(action: { showingAISettings = true }) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(Color.blue)
                        .font(.title2)
                    VStack(alignment: .leading) {
                        Text("AI Learning & Privacy")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("Control AI data sharing and privacy settings")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if aiDataManager.isContributing {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "pause.circle.fill")
                            .foregroundColor(.orange)
                    }
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .padding(10)
                .background(Color.blue.opacity(0.08))
                .cornerRadius(12)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "lock.shield.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("Your Data is Private")
                        .font(.caption.bold())
                        .foregroundColor(.green)
                }
                
                Text("• Only anonymized patterns are shared\n• No personal or business information\n• No prices or financial data\n• Data stays on your device")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.green.opacity(0.05))
            .cornerRadius(8)
            
        } header: {
            Text("AI & Machine Learning")
        } footer: {
            Text("Help improve AI accuracy for all users while maintaining complete privacy. Only anonymized data patterns are shared.")
        }
        .sheet(isPresented: $showingAISettings) {
            AIDataSharingSettingsView(aiDataManager: aiDataManager)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppAuthService())
} 
