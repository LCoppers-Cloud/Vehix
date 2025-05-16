import SwiftUI
import SwiftData

// Import DeveloperCloudKitDocumentationView
import SwiftUI

struct SettingsView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authService: AppAuthService
    @EnvironmentObject var cloudKitManager: CloudKitManager
    
    @State private var showServiceTitanSettings = false
    @State private var showSamsaraSettings = false
    @State private var showNotificationSettings = false
    @State private var showAccountSettings = false
    @State private var showCloudKitSettings = false
    @State private var showSubscriptionSheet = false
    
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
        NavigationView {
            List {
                // Account section
                Section(header: Text("Account")) {
                    if let user = authService.currentUser {
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
                    
                    // --- Modern Manage Subscription Button ---
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
                        if #available(iOS 18.0, *) {
                            SubscriptionView()
                                .environmentObject(StoreKitManager())
                        } else {
                            Text("Subscription management requires iOS 18+")
                                .padding()
                        }
                    }
                    // --- End Modern Manage Subscription Button ---

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
                
                // Integrations section
                Section(header: Text("External Integrations")) {
                    // CloudKit Integration
                    Button(action: {
                        showCloudKitSettings = true
                    }) {
                        HStack {
                            Image(systemName: "cloud.fill")
                                .foregroundColor(.cyan)
                                .font(.title2)
                            VStack(alignment: .leading) {
                                Text("CloudKit Integration")
                                    .font(.headline)
                                Text("Inventory sharing and cloud sync")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if cloudKitManager.isSharingEnabled {
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
                    .sheet(isPresented: $showCloudKitSettings) {
                        CloudKitSettingsView()
                            .environmentObject(cloudKitManager)
                    }
                    
                    // ServiceTitan Integration
                    Button(action: {
                        showServiceTitanSettings = true
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
                            if serviceTitanService.isConnected {
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
                    .sheet(isPresented: $showServiceTitanSettings) {
                        ServiceTitanSettingsView(service: serviceTitanService)
                    }
                    
                    // Samsara Integration
                    Button(action: {
                        showSamsaraSettings = true
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
                            if samsaraService.isConnected {
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
                    .sheet(isPresented: $showSamsaraSettings) {
                        SamsaraSettingsView(service: samsaraService)
                    }
                }
                
                // App Settings section
                Section(header: Text("Application Settings")) {
                    // Notifications
                    NavigationLink(destination: NotificationPreferencesView()) {
                        HStack {
                            Image(systemName: "bell.fill")
                                .foregroundColor(.purple)
                            Text("Notification Preferences")
                            Spacer()
                        }
                    }
                    
                    // Oil Change Reminder Settings
                    NavigationLink(destination: OilChangeReminderSettingsView()) {
                        HStack {
                            Image(systemName: "drop.fill")
                                .foregroundColor(.red)
                            Text("Oil Change Reminders")
                        }
                    }
                    
                    // App Appearance
                    NavigationLink(destination: AppearanceSettingsView()) {
                        HStack {
                            Image(systemName: "paintbrush.fill")
                                .foregroundColor(.yellow)
                            Text("Appearance")
                        }
                    }
                }
                
                // About section
                Section(header: Text("About")) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    NavigationLink(destination: Text("Privacy Policy").padding()) {
                        HStack {
                            Image(systemName: "hand.raised.fill")
                                .foregroundColor(.green)
                            Text("Privacy Policy")
                        }
                    }
                    
                    NavigationLink(destination: Text("Terms of Service").padding()) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(.purple)
                            Text("Terms of Service")
                        }
                    }
                }
                
                // Only show data management for admin and dealer roles
                if authService.currentUser?.userRole == .admin || authService.currentUser?.userRole == .dealer {
                    Section(header: Text("Data Management")) {
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
                    }
                }
                
                // Developer section (only visible when enabled and for the developer account)
                if devModeEnabled {
                    Section(header: Text("Developer Options")) {
                        NavigationLink(destination: DeveloperCloudKitDocumentationView()) {
                            HStack {
                                Image(systemName: "cloud.fill")
                                    .foregroundColor(.purple)
                                Text("CloudKit Documentation")
                            }
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Settings")
            .onAppear {
                // Initialize services with model context
                serviceTitanService.loadConfiguration()
                samsaraService.loadConfiguration()
            }
            .alert("Clear App Data", isPresented: $showClearDataConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All Data", role: .destructive) {
                    // Call the clearUserData method from AuthService
                    authService.clearUserData()
                }
            } message: {
                Text("This will delete all tasks, vehicles, and staff (except your user). This action cannot be undone. Are you sure you want to continue?")
            }
            .alert("Clear Inventory Data", isPresented: $showClearInventoryConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear Inventory", role: .destructive) {
                    // Call the clearInventoryData method from AuthService
                    authService.clearInventoryData()
                }
            } message: {
                Text("This will delete all inventory items, warehouses, and stock locations. This action cannot be undone. Are you sure you want to continue?")
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
                Section(header: Text("About ServiceTitan Integration")) {
                    Text("Connect Vehix to your ServiceTitan account to sync inventory, technicians, and purchase orders. You'll need administrator access to your ServiceTitan account to get the required credentials.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("API Credentials")) {
                    TextField("Client ID", text: $clientId)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    
                    TextField("Tenant ID", text: $tenantId)
                        .keyboardType(.numberPad)
                    
                    SecureField("Client Secret", text: $clientSecret)
                }
                
                Section(header: Text("Sync Settings")) {
                    Toggle("Sync Inventory", isOn: $syncInventory)
                    Toggle("Sync Technicians", isOn: $syncTechnicians)
                    Toggle("Sync Vendors", isOn: $syncVendors)
                    Toggle("Sync Purchase Orders", isOn: $syncPurchaseOrders)
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
        // Load service settings
        do {
            let configs = try modelContext.fetch(FetchDescriptor<ServiceTitanConfig>())
            if let config = configs.first {
                clientId = config.clientId ?? ""
                tenantId = config.tenantId != nil ? "\(config.tenantId!)" : ""
                // Retrieve client secret from Keychain
                clientSecret = config.getClientSecret()
                syncInventory = config.syncInventory
                syncTechnicians = config.syncTechnicians
                syncVendors = config.syncVendors
                syncPurchaseOrders = config.syncPurchaseOrders
            }
        } catch {
            print("Error loading ServiceTitan config: \(error)")
        }
    }
    
    private func saveSettings() {
        do {
            let configs = try modelContext.fetch(FetchDescriptor<ServiceTitanConfig>())
            let config = configs.first ?? ServiceTitanConfig()
            
            config.clientId = clientId
            config.tenantId = Int64(tenantId) ?? 0
            
            // Securely store client secret using the method that uses KeychainServices
            config.setClientSecret(clientSecret)
            
            config.syncInventory = syncInventory
            config.syncTechnicians = syncTechnicians
            config.syncVendors = syncVendors
            config.syncPurchaseOrders = syncPurchaseOrders
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
        
        // Test connection with current values
        let config = ServiceTitanConfig()
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
                Section(header: Text("About Samsara Integration")) {
                    Text("Connect Vehix to your Samsara fleet management system to automatically track vehicle mileage and location. This integration enables automatic reminders for oil changes and service based on actual mileage data.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("API Credentials")) {
                    TextField("API Key", text: $apiKey)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    
                    TextField("Organization ID", text: $organizationId)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
                
                Section(header: Text("Sync Settings")) {
                    Toggle("Enable Samsara Integration", isOn: $isEnabled)
                    
                    Stepper(value: $syncIntervalMinutes, in: 5...120, step: 5) {
                        Text("Sync Interval: \(syncIntervalMinutes) minutes")
                    }
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
                
                Section(header: Text("Vehicle Management")) {
                    NavigationLink(destination: SamsaraVehiclesView()) {
                        HStack {
                            Image(systemName: "car.2.fill")
                            Text("Manage Tracked Vehicles")
                        }
                    }
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
            Section(header: Text("Tracked by Samsara (\(trackedVehicles.count))")) {
                if trackedVehicles.isEmpty {
                    Text("No vehicles are currently tracked by Samsara")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(trackedVehicles) { vehicle in
                        VehicleRow(vehicle: vehicle, service: service)
                    }
                }
            }
            
            Section(header: Text("Available Vehicles (\(untrackedVehicles.count))")) {
                if untrackedVehicles.isEmpty {
                    Text("No additional vehicles available to track")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(untrackedVehicles) { vehicle in
                        VehicleRow(vehicle: vehicle, service: service)
                    }
                }
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
            // Generate a fake Samsara ID if enabling tracking
            vehicle.samsaraVehicleId = "SAM-\(Int.random(in: 1000...9999))"
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
}

struct CloudKitSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var cloudKitManager: CloudKitManager
    
    @State private var isTesting = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var alertMessage = ""
    @State private var shareInventory = false
    @State private var sharePrices = false
    @State private var shareUsageData = false
    @State private var showPrivacyConsentView = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("About CloudKit Integration")) {
                    Text("CloudKit allows you to share inventory data between multiple devices and users. Your inventory can be shared with others while keeping sensitive pricing and usage data private.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("Connection Status")) {
                    HStack {
                        Text("Container")
                        Spacer()
                        Text("iCloud.com.lcoppers.Vehix")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(cloudKitManager.syncStatus)
                            .foregroundColor(cloudKitManager.syncError == nil ? .green : .red)
                    }
                    
                    if let error = cloudKitManager.syncError {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
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
                    .disabled(isTesting)
                }
                
                Section(header: HStack {
                    Text("Sharing Settings")
                    Spacer()
                    Button(action: {
                        showPrivacyConsentView = true
                    }) {
                        Text("Privacy Settings")
                            .font(.caption)
                    }
                }) {
                    Toggle("Share Inventory", isOn: $shareInventory)
                        .onChange(of: shareInventory) { _, newValue in
                            if !newValue {
                                // Disable sub-options if sharing is disabled
                                sharePrices = false
                                shareUsageData = false
                            }
                        }
                    
                    if shareInventory {
                        Toggle("Share Pricing Information", isOn: $sharePrices)
                            .padding(.leading)
                        
                        Toggle("Share Usage Data", isOn: $shareUsageData)
                            .padding(.leading)
                    }
                }
                
                if shareInventory {
                    Section {
                        Button(action: syncNow) {
                            HStack {
                                Spacer()
                                Text("Sync Inventory Now")
                                    .bold()
                                Spacer()
                            }
                        }
                    }
                }
                
                Section {
                    Button(action: saveSettings) {
                        HStack {
                            Spacer()
                            Text("Save Settings")
                                .bold()
                            Spacer()
                        }
                    }
                }
                
                if let lastSync = cloudKitManager.lastSyncDate {
                    Section {
                        HStack {
                            Text("Last Sync")
                            Spacer()
                            Text("\(formattedDate(lastSync))")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(header: Text("Privacy & Security")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Data Privacy")
                            .font(.headline)
                        
                        Text("All shared data is anonymized. No personal identifiable information is ever shared with other users. You can review and adjust your privacy settings at any time.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                    
                    Button(action: {
                        showPrivacyConsentView = true
                    }) {
                        HStack {
                            Image(systemName: "shield.fill")
                                .foregroundColor(.green)
                            Text("Review Privacy Settings")
                        }
                    }
                }
            }
            .navigationTitle("CloudKit Settings")
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
            .onAppear(perform: loadSettings)
            .alert("Connection Successful", isPresented: $showSuccessAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .alert("Connection Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $showPrivacyConsentView) {
                PrivacyConsentView()
                    .environmentObject(cloudKitManager)
            }
        }
    }
    
    private func loadSettings() {
        // Load current CloudKit settings from the privacy manager
        shareInventory = CloudKitPrivacyManager.shared.shouldShareInventory
        sharePrices = CloudKitPrivacyManager.shared.shouldSharePrices
        shareUsageData = CloudKitPrivacyManager.shared.shouldShareUsageData
    }
    
    private func saveSettings() {
        // Save CloudKit sharing settings
        CloudKitPrivacyManager.shared.setUserConsent(
            consent: shareInventory,
            shareInventory: shareInventory,
            sharePrices: sharePrices,
            shareUsageData: shareUsageData
        )
        
        cloudKitManager.configureSharing(
            shareInventory: shareInventory,
            sharePrices: sharePrices,
            shareUsageData: shareUsageData
        )
        
        showSuccessAlert = true
        alertMessage = "CloudKit settings saved successfully"
    }
    
    private func testConnection() {
        isTesting = true
        
        cloudKitManager.verifyContainerConnection { success, message in
            isTesting = false
            alertMessage = message ?? (success ? "Successfully connected to CloudKit" : "Failed to connect to CloudKit")
            
            if success {
                showSuccessAlert = true
            } else {
                showErrorAlert = true
            }
        }
    }
    
    private func syncNow() {
        cloudKitManager.syncInventoryItems()
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
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
            Section(header: Text("Technician Notifications")) {
                Toggle("Tasks Assigned", isOn: $techniciansAssignedEnabled)
                Toggle("Tasks Completed", isOn: $techniciansCompletedEnabled)
                Toggle("Staff Availability Updates", isOn: $staffAvailabilityEnabled)
            }
            
            Section(header: Text("Inventory Notifications")) {
                Toggle("Low Stock Alerts", isOn: $inventoryLowEnabled)
                Toggle("Purchase Order Status", isOn: $purchaseOrderStatusEnabled)
            }
            
            Section(header: Text("Vehicle Notifications")) {
                Toggle("Maintenance Reminders", isOn: $vehicleMaintenanceEnabled)
                Toggle("Overdue Tasks", isOn: $taskOverdueEnabled)
            }
            
            Section(header: Text("General Notifications")) {
                Toggle("Daily Summary Report", isOn: $dailySummaryEnabled)
            }
            
            Section(header: Text("About Notifications"), footer: Text("Notifications help you stay updated on important events in your fleet and inventory management. You can always change these settings later.")) {
                Text("You'll receive push notifications for the selected items. Make sure notifications are enabled for Vehix in your device settings.")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                Section(header: Text("Reminder Timing")) {
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
                }
                
                Section(header: Text("Recipients")) {
                    Toggle("Send to Technicians", isOn: $sendToTechnicians)
                    Toggle("Send to Managers", isOn: $sendToManagers)
                }
                
                Section(header: Text("About Oil Change Reminders"), footer: Text("Keep your fleet running smoothly with proper oil change maintenance.")) {
                    Text("Oil change reminders are sent based on time and mileage, whichever comes first. Make sure your vehicles have proper maintenance records for accurate reminders.")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
            Section(header: Text("Theme")) {
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
            }
            
            Section(header: Text("Display")) {
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
            }
            
            Section(header: Text("About Appearance"), footer: Text("Theme changes will apply the next time you restart the app.")) {
                Text("Customize how Vehix looks to match your company's branding or personal preference.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Appearance")
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppAuthService())
} 
