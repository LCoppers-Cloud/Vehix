//
//  VehixApp.swift
//  Vehix
//
//  Created by Loren Coppers on 5/9/25.
//

import SwiftUI
import SwiftData
import AuthenticationServices
import StoreKit
import CloudKit
import UserNotifications

/*
 IMPORTANT NOTES FOR PRODUCTION DEPLOYMENT:
 
 Current Configuration (Simulator/Development):
 - CloudKit integration is disabled in DEBUG builds (#if DEBUG)
 - Using local-only storage configuration with ModelConfiguration(isStoredInMemoryOnly: false)
 - This allows testing in the simulator without CloudKit/iCloud account errors
 
 Required Changes for Production:
 1. CloudKit Integration:
    - Remove or modify the #if DEBUG condition to enable CloudKit in production
    - Use a proper CloudKit container identifier in the configuration
    
 2. Configure CloudKit Container:
    - In production, use:
      let cloudKitConfig = ModelConfiguration.CloudKitDatabase(
          containerIdentifier: "iCloud.com.lcoppers.Vehix"
      )
      var configuration = ModelConfiguration(cloudKitDatabase: cloudKitConfig)
      
 3. Ensure iCloud Capabilities:
    - Verify app has proper iCloud and CloudKit entitlements in Xcode project
    - Check that the CloudKit container is properly set up in Apple Developer portal
    
 4. User Authentication:
    - Implement proper iCloud user authentication checks
    - Handle accounts that are not signed into iCloud
    
 5. Data Migration:
    - Consider adding migration strategy for users upgrading from simulator/local storage
    - Implement SchemaMigrationPlan if model schema changes
 
 IMPLEMENTATION EXAMPLE FOR PRODUCTION:
 ```
 // Production configuration with CloudKit
 let cloudKitConfig = ModelConfiguration.CloudKitDatabase(
     containerIdentifier: "iCloud.com.lcoppers.Vehix"
 )
 let configuration = ModelConfiguration(cloudKitDatabase: cloudKitConfig)
 ```
 
 For a hybrid approach that works in both environments:
 ```
 #if DEBUG && targetEnvironment(simulator)
     // Simulator: Use local storage only
     configuration = ModelConfiguration(isStoredInMemoryOnly: false)
 #else
     // Real device or production: Use CloudKit
     let cloudKitConfig = ModelConfiguration.CloudKitDatabase(
         containerIdentifier: "iCloud.com.lcoppers.Vehix"
     )
     configuration = ModelConfiguration(cloudKitDatabase: cloudKitConfig)
 #endif
 ```
*/

// MARK: - Environment Detection

// Helper to detect simulator environment
#if targetEnvironment(simulator)
let isRunningInSimulator = true
#else
let isRunningInSimulator = false
#endif

#if DEBUG
let isDebugBuild = true
#else
let isDebugBuild = false
#endif

// Combined condition for development/testing environment
let isDevEnvironment = isDebugBuild || isRunningInSimulator

@main
struct VehixApp: App {
    @State private var isFinishedLoading = false
    @State private var showLaunchScreen = true
    
    // Create a model container for user data
    let modelContainer: ModelContainer
    
    // Setup services
    @StateObject private var authService: AppAuthService
    @StateObject private var serviceTitanService: ServiceTitanService
    @StateObject private var samsaraService: SamsaraService
    @StateObject private var cloudKitManager: CloudKitManager
    @StateObject private var storeKitManager: StoreKitManager
    @StateObject private var notificationDelegate = NotificationDelegate()
    
    init() {
        // Use the Vehix namespace schema to ensure consistent model usage
        let schema = Schema(Vehix.completeSchema())
        
        // Configure model container based on environment
        var configuration = ModelConfiguration()
        
        // TEMPORARY: Force development environment until authentication issues are resolved
        // This will allow the app to run without CloudKit errors
        let forceDevelopmentMode = true
        
        // For presentations: Auto-login as developer (enable for testing)
        let presentationMode = true
        
        // Regular environment detection (will be overridden by forceDevelopmentMode for now)
        #if DEBUG 
        let isSimulator = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil
        #else
        let isSimulator = false
        #endif
        
        // Use the forced development flag for now
        let isDevEnvironment = isSimulator || forceDevelopmentMode
        
        // App environment configuration
        if isDevEnvironment {
            // Development/Simulator: Disable CloudKit integration completely
            print("Development environment detected - using local storage only")
            configuration = ModelConfiguration(isStoredInMemoryOnly: false)
        } else {
            // TEMPORARY: Disable CloudKit until all relationship issues are fixed
            print("Production environment detected - but using local storage due to ongoing CloudKit integration issues")
            configuration = ModelConfiguration(isStoredInMemoryOnly: false)
            
            // Original production configuration (commented out until fixed):
            // configuration = ModelConfiguration(cloudKitDatabase: .private("iCloud.com.lcoppers.Vehix"))
        }
        
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to initialize model container: \(error)")
        }
        
        // Initialize services based on environment
        let modelContext = ModelContext(modelContainer)
        
        // Simplify service initialization to ensure consistent behavior
        // Always use the same modelContext for all services
        print("📱 Initializing services for \(isDevEnvironment ? "development" : "production") environment")
        
        // Initialize auth service with context
        let auth = AppAuthService(useMockData: isDevEnvironment)
        auth.modelContext = modelContext
        _authService = StateObject(wrappedValue: auth)
        
        // Initialize other services with the same pattern
        _serviceTitanService = StateObject(wrappedValue: ServiceTitanService(modelContext: modelContext, isSimulatorEnvironment: isDevEnvironment))
        
        // Initialize Samsara service with additional setup for demo purposes
        let samsara = SamsaraService(modelContext: modelContext, isSimulatorEnvironment: isDevEnvironment)
        _samsaraService = StateObject(wrappedValue: samsara)
        
        _cloudKitManager = StateObject(wrappedValue: CloudKitManager(modelContext: modelContext, isSimulatorEnvironment: isDevEnvironment))
        _storeKitManager = StateObject(wrappedValue: StoreKitManager(isSimulatorEnvironment: isDevEnvironment))
        
        // After all properties are initialized, we can safely call helper methods
        if presentationMode {
            // Auto-login with a developer account
            setupDeveloperAccount(auth: auth, modelContext: modelContext)
        }
        
        // Ensure a Samsara config exists for demo purposes
        setupSamsaraConfigIfNeeded(modelContext: modelContext)
        
        // Set up BETA tester account with premium access for 10 years
        setupBetaTesterAccount(modelContext: modelContext)
    }
    
    private func setupDeveloperAccount(auth: AppAuthService, modelContext: ModelContext) {
        // Auto-login with a developer account
        var developerUser = AuthUser(
            id: "developer-account-123",
            email: "lorenjohn21@yahoo.com",
            fullName: "Loren Coppers",
            role: .admin,
            isVerified: true
        )
        
        // Check if developer account already exists
        do {
            // Get all users and filter in memory instead of using predicate
            let descriptor = FetchDescriptor<AuthUser>()
            let allUsers = try modelContext.fetch(descriptor)
            let existingUsers = allUsers.filter { user in
                user.email == "lorenjohn21@yahoo.com"
            }
            
            if existingUsers.isEmpty {
                // Create developer account if it doesn't exist
                modelContext.insert(developerUser)
                try modelContext.save()
                print("Created developer account in database")
            } else {
                // Use existing developer account
                developerUser = existingUsers.first!
                print("Using existing developer account from database")
            }
            auth.currentUser = developerUser
            auth.isLoggedIn = true
        } catch {
            print("Error setting up developer account: \(error)")
            // Fall back to developer account in memory
            auth.currentUser = developerUser
            auth.isLoggedIn = true
        }
    }
    
    private func setupSamsaraConfigIfNeeded(modelContext: ModelContext) {
        // Check if Samsara config exists
        do {
            let descriptor = FetchDescriptor<SamsaraConfig>()
            let existingConfigs = try modelContext.fetch(descriptor)
            
            if existingConfigs.isEmpty {
                // Create a sample Samsara config for demo purposes
                let config = SamsaraConfig(
                    apiKey: "sample-api-key",
                    organizationId: "demo-org-123",
                    isEnabled: true,
                    syncIntervalMinutes: 30
                )
                modelContext.insert(config)
                try modelContext.save()
                print("✅ Created sample Samsara configuration for demonstration")
            } else {
                print("✅ Using existing Samsara configuration")
            }
        } catch {
            print("❌ Error setting up Samsara configuration: \(error)")
        }
    }
    
    private func setupBetaTesterAccount(modelContext: ModelContext) {
        // Check if the special beta tester account exists
        let appleId = "lorenjohn21@yahoo.com" // Beta tester Apple ID
        
        do {
            // Look for existing premium account - use in-memory filtering
            let descriptor = FetchDescriptor<AuthUser>()
            let allUsers = try modelContext.fetch(descriptor)
            let users = allUsers.filter { user in
                user.email == appleId
            }
            
            if let existingUser = users.first {
                // Ensure the user has premium access
                if existingUser.userRole != .premium {
                    existingUser.userRole = .premium
                    try modelContext.save()
                    print("✅ Beta tester account updated to premium status")
                }
            } else {
                // Create a new premium account for beta testing
                let betaTester = AuthUser(
                    email: appleId,
                    fullName: "Beta Tester",
                    role: .premium,
                    isVerified: true,
                    isTwoFactorEnabled: false
                )
                
                modelContext.insert(betaTester)
                try modelContext.save()
                print("✅ Created new premium beta tester account")
            }
            
            // Reset app walkthrough to show up for the user
            UserDefaults.standard.set(false, forKey: "hasCompletedAppWalkthrough")
            print("✅ Reset walkthrough status for beta testing")
            
        } catch {
            print("❌ Error setting up beta tester account: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if showLaunchScreen {
                    LaunchScreenView()
                        .onAppear {
                            // Show launch screen for 2 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation {
                                    showLaunchScreen = false
                                    setupNotifications() // Setup notifications when app launches
                                }
                            }
                        }
                } else {
                    // Use the AuthWrapper to handle authentication state
                    AuthWrapper()
                        .environmentObject(authService)
                        .environmentObject(serviceTitanService)
                        .environmentObject(samsaraService)
                        .environmentObject(cloudKitManager)
                        .environmentObject(storeKitManager)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut, value: showLaunchScreen)
            .animation(.easeInOut, value: isFinishedLoading)
            .animation(.easeInOut, value: authService.isLoggedIn)
        }
        .modelContainer(modelContainer)
    }
    
    /// Creates sample data for the app if needed (for demonstration/testing purposes)
    private static func createSampleDataIfNeeded(modelContext: ModelContext) async {
        // Check if we already have data
        let vehicleDescriptor = FetchDescriptor<AppVehicle>()
        let inventoryDescriptor = FetchDescriptor<AppInventoryItem>()
        let warehouseDescriptor = FetchDescriptor<AppWarehouse>()
        
        do {
            let existingVehicles = try modelContext.fetch(vehicleDescriptor)
            let existingInventory = try modelContext.fetch(inventoryDescriptor)
            let existingWarehouses = try modelContext.fetch(warehouseDescriptor)
            
            // Only create sample data if we don't have any
            if existingVehicles.isEmpty && existingInventory.isEmpty && existingWarehouses.isEmpty {
                print("Creating sample data for first-time app use")
                await createSampleData(modelContext: modelContext)
            } else {
                print("Sample data already exists, skipping creation")
            }
        } catch {
            print("Error checking for existing data: \(error)")
        }
    }
    
    /// Creates sample data for demo/testing
    private static func createSampleData(modelContext: ModelContext) async {
        // Create sample inventory items but don't assign them to warehouses
        let item1 = AppInventoryItem(name: "Oil Filter", partNumber: "OF-123", category: "Filters")
        let item2 = AppInventoryItem(name: "Air Filter", partNumber: "AF-456", category: "Filters")
        let item3 = AppInventoryItem(name: "Wiper Blades", partNumber: "WB-789", category: "Accessories")
        let item4 = AppInventoryItem(name: "Brake Pads", partNumber: "BP-234", category: "Brakes")
        let item5 = AppInventoryItem(name: "Spark Plugs", partNumber: "SP-567", category: "Engine")
        
        modelContext.insert(item1)
        modelContext.insert(item2)
        modelContext.insert(item3)
        modelContext.insert(item4)
        modelContext.insert(item5)
        
        // Create a sample purchase order
        let po1 = PurchaseOrder(
            poNumber: "PO-2025-001",
            date: Date(),
            vendorName: "AutoParts Wholesale",
            status: PurchaseOrderStatus(rawValue: "Draft") ?? .draft, // Use draft status instead of submitted
            subtotal: 0.0,
            tax: 0.0,
            total: 0.0,
            createdByName: "System"
        )
        
        // Insert purchase order without line items
        modelContext.insert(po1)
        
        // Try to save all entities
        do {
            try modelContext.save()
            print("Sample inventory data created successfully")
        } catch {
            print("Error saving sample data: \(error)")
        }
    }
    
    // Setup notification handling
    private func setupNotifications() {
        UNUserNotificationCenter.current().delegate = notificationDelegate
        
        // Request notification permission if not already granted
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
        
        // Create notification categories for purchase orders
        let resumeAction = UNNotificationAction(
            identifier: "RESUME_ACTION",
            title: "Continue PO",
            options: .foreground
        )
        
        let category = UNNotificationCategory(
            identifier: "PURCHASE_ORDER",
            actions: [resumeAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
}

// Notification handler for the app
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, ObservableObject {
    // Show notifications even when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                               willPresent notification: UNNotification, 
                               withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Always show purchase order notifications in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification response when user taps a notification
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                               didReceive response: UNNotificationResponse, 
                               withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        // Handle purchase order notifications
        if response.notification.request.content.categoryIdentifier == "PURCHASE_ORDER",
           let poId = userInfo["po_id"] as? String {
            // Post a notification that will be observed by the PO creation screen
            NotificationCenter.default.post(name: NSNotification.Name("ResumePurchaseOrder"), 
                                          object: nil,
                                          userInfo: ["po_id": poId])
        }
        
        completionHandler()
    }
}

// View to handle authentication state
struct AuthStateView: View {
    @EnvironmentObject var authService: AppAuthService
    @EnvironmentObject var serviceTitanService: ServiceTitanService
    @EnvironmentObject var samsaraService: SamsaraService
    @EnvironmentObject var cloudKitManager: CloudKitManager
    
    var body: some View {
        if authService.isLoggedIn, let user = authService.currentUser {
            // Check if first-time setup is needed
            if !user.hasCompletedSetup {
                InitialSetupView()
            } else {
                // User is logged in and has completed setup - show appropriate view based on role
                switch user.userRole {
                case .admin:
                    MainTabView()
                case .dealer:
                    MainTabView()
                case .technician:
                    MainTabView()
                case .premium:
                    Text("Premium User Dashboard")
                case .standard:
                    Text("Standard User Dashboard")
                }
            }
        } else {
            // Not logged in - show login screen
            LoginView()
        }
    }
}

// Main Tab View with bottom tabs
struct MainTabView: View {
    @EnvironmentObject var authService: AppAuthService
    @EnvironmentObject var cloudKitManager: CloudKitManager
    @EnvironmentObject var storeKitManager: StoreKitManager
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 0
    @State private var showSharedInventory = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Dashboard Tab
            if authService.currentUser?.userRole == .dealer || authService.currentUser?.userRole == .admin {
                NavigationStack {
                    ManagerDashboardView()
                        .environment(\.modelContext, modelContext)
                }
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar")
                }
                .tag(0)
            } else {
                NavigationStack {
                    TechnicianDashboardView()
                        .environment(\.modelContext, modelContext)
                }
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar")
                }
                .tag(0)
            }
            // Inventory Tab
            NavigationStack {
                InventoryView()
                    .environmentObject(authService)
                    .environmentObject(storeKitManager)
                    .environment(\.modelContext, modelContext)
            }
            .tabItem {
                Label("Inventory", systemImage: "shippingbox")
            }
            .tag(1)
            // Vehicles Tab
            NavigationStack {
                VehicleListView()
                    .environmentObject(authService)
                    .environmentObject(storeKitManager)
                    .environment(\.modelContext, modelContext)
            }
            .tabItem {
                Label("Vehicles", systemImage: "car.fill")
            }
            .tag(2)
            // Tasks Tab (For all users)
            NavigationStack {
                TaskView()
                    .environmentObject(authService)
                    .environment(\.modelContext, modelContext)
            }
            .tabItem {
                Label("Tasks", systemImage: "checklist")
            }
            .tag(3)
            // Staff Tab (Inventory Managers/Admins only)
            if authService.currentUser?.userRole == .dealer || authService.currentUser?.userRole == .admin {
                NavigationStack {
                    StaffListView()
                        .environmentObject(authService)
                        .environmentObject(storeKitManager)
                }
                .tabItem {
                    Label("Staff", systemImage: "person.2.fill")
                }
                .tag(4)
            }
            // Track Usage Tab (For Technicians)
            if authService.currentUser?.userRole == .technician {
                NavigationStack {
                    InventoryUsageView()
                }
                .environment(\.modelContext, modelContext)
                .tabItem {
                    Label("Track Usage", systemImage: "list.bullet.clipboard")
                }
                .tag(4)
            }
            // Replenishment Tab (For Managers/Admins)
            if authService.currentUser?.userRole == .dealer || authService.currentUser?.userRole == .admin {
                NavigationStack {
                    InventoryReplenishmentView()
                }
                .environment(\.modelContext, modelContext)
                .tabItem {
                    Label("Replenishment", systemImage: "arrow.clockwise")
                }
                .tag(5)
            }
            // Receipt Scanner Tab
            NavigationStack {
                ReceiptScannerView()
            }
            .tabItem {
                Label("Scan", systemImage: "doc.text.viewfinder")
            }
            .tag(6)
            // Settings Tab
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(7)
        }
        .environmentObject(authService)
        .environmentObject(storeKitManager)
        .onAppear {
            print("MODEL CONTEXT CHECK: Available")
            print("STORE KIT MANAGER: \(storeKitManager)")
            print("AUTH SERVICE: \(authService)")
        }
    }
}

// Dashboard placeholder
struct DashboardView: View {
    var body: some View {
        Text("Dashboard")
            .font(.largeTitle)
            .bold()
    }
}

// Settings placeholder - removing duplicate definition 
// To fix this, define a single SettingsView in a dedicated file

// Integration tab
struct IntegrationTabView: View {
    @State private var showingReceiptScanner = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink(destination: VendorManagementView()) {
                        Label("Vendor Management", systemImage: "building.2.fill")
                    }
                    
                    Button(action: {
                        showingReceiptScanner = true
                    }) {
                        Label("Scan Receipt", systemImage: "doc.text.viewfinder")
                    }
                } header: {
                    Text("Integration Tools")
                }
                
                Section {
                    NavigationLink(destination: Text("Import/Export Data View")) {
                        Label("Import/Export Data", systemImage: "square.and.arrow.up.on.square")
                    }
                    
                    NavigationLink(destination: Text("Synchronization Settings")) {
                        Label("Sync Settings", systemImage: "arrow.triangle.2.circlepath")
                    }
                } header: {
                    Text("Data Management")
                }
            }
            .navigationTitle("Integration")
            .sheet(isPresented: $showingReceiptScanner) {
                ReceiptScannerView()
            }
        }
    }
}

// Simple model for SwiftData (keeping this for other app data)
@Model
final class Item {
    var timestamp: Date = Date()
    
    init(timestamp: Date = Date()) {
        self.timestamp = timestamp
    }
}

// Legacy ContentView - commented out since MainTabView is now the primary tab interface
/*
struct ContentView: View {
    @EnvironmentObject var authService: AppAuthService
    @EnvironmentObject var storeKitManager: StoreKitManager
    @Environment(\.modelContext) private var modelContext
    
    // View state
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Dashboard
            NavigationStack {
                Text("Dashboard")
                    .navigationTitle("Dashboard")
            }
            .tabItem {
                Label("Dashboard", systemImage: "gauge")
            }
            .tag(0)
            
            // Inventory
            NavigationStack {
                InventoryView()
            }
            .tabItem {
                Label("Inventory", systemImage: "shippingbox")
            }
            .tag(1)
            
            // Vehicles
            NavigationStack {
                VehicleListView()
                    .environmentObject(authService)
                    .environmentObject(storeKitManager)
            }
            .tabItem {
                Label("Vehicles", systemImage: "car")
            }
            .tag(2)
            
            // More
            NavigationStack {
                MoreTabView()
            }
            .tabItem {
                Label("More", systemImage: "ellipsis")
            }
            .tag(3)
        }
    }
}
*/

// Simple More tab view
struct MoreTabView: View {
    @EnvironmentObject var authService: AppAuthService
    
    var body: some View {
        List {
            // Services section
            Text("Services")
                .font(.headline)
                .padding(.top)
            
            NavigationLink(destination: Text("Services")) {
                Label("Services", systemImage: "wrench")
            }
            
            NavigationLink(destination: Text("Reports")) {
                Label("Reports", systemImage: "chart.bar")
            }
            
            // Account section
            Text("Account")
                .font(.headline)
                .padding(.top, 20)
            
            NavigationLink(destination: Text("Settings")) {
                Label("Settings", systemImage: "gear")
            }
            
            Button(action: {
                // Sign out action using the correct method
                authService.signOut()
            }) {
                Label("Sign Out", systemImage: "arrow.right.square")
                    .foregroundColor(.red)
            }
        }
        .listStyle(GroupedListStyle())
        .navigationTitle("More")
    }
}

// View to handle authentication state
struct AuthWrapper: View {
    @EnvironmentObject var authService: AppAuthService
    @State private var showWalkthrough = false
    @State private var showResetConfirmation = false
    @State private var isFinishedLoading = false
    
    var body: some View {
        ZStack {
            if authService.isLoggedIn {
                // Main app content when logged in
                ContentView()
                    .environmentObject(authService)
                    .onAppear {
                        // Check if user should see walkthrough
                        if let _ = authService.currentUser, 
                           !UserDefaults.standard.bool(forKey: "hasCompletedAppWalkthrough") {
                            showWalkthrough = true
                        }
                    }
                    .sheet(isPresented: $showWalkthrough) {
                        AppWalkthroughView()
                    }
                    .alert("Reset App Data", isPresented: $showResetConfirmation) {
                        Button("Cancel", role: .cancel) {}
                        Button("Reset", role: .destructive) {
                            // Reset all app data
                            authService.resetAppData()
                            // Force logout
                            authService.signOut()
                        }
                    } message: {
                        Text("This will delete all app data and return to factory settings. This action cannot be undone.")
                    }
            } else if authService.isLoading {
                // Loading state
                LoadingView(isFinishedLoading: $isFinishedLoading)
            } else {
                // Auth flow when not logged in
                LoginView()
                    .environmentObject(authService)
            }
        }
    }
}

// Add this before the AuthWrapper struct
struct ContentView: View {
    @EnvironmentObject var authService: AppAuthService
    @EnvironmentObject var storeKitManager: StoreKitManager
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        // Check user role to determine which view to show
        if let user = authService.currentUser {
            switch user.userRole {
            case .admin, .dealer:
                ManagerDashboardView()
                    .environmentObject(authService)
                    .environment(\.modelContext, modelContext)
            case .technician:
                TechnicianDashboardView()
                    .environmentObject(authService)
                    .environment(\.modelContext, modelContext)
            case .premium, .standard:
                MainTabView()
                    .environmentObject(authService)
                    .environmentObject(storeKitManager)
                    .environment(\.modelContext, modelContext)
            }
        } else {
            // Fallback to main tab view if user data is incomplete
            MainTabView()
                .environmentObject(authService)
                .environmentObject(storeKitManager)
                .environment(\.modelContext, modelContext)
        }
    }
}


