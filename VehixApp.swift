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
    @StateObject private var aiDataManager: AISharedDataManager
    @StateObject private var marketingManager = MarketingDataManager()
    @StateObject private var notificationDelegate = NotificationDelegate()
    @StateObject private var settingsManager = AppSettingsManager()
    
    init() {
        // Register secure transformers to fix CoreData security warnings
        IntArrayTransformer.register()
        StringArrayTransformer.register()
        CLLocationCoordinate2DTransformer.register()
        ExtendedDataTransformer.register()
        
        // SCHEMA BLOAT FIX: Use clean schema system instead of progressive system
        migrateToCleanSchema() // Migrate from old system
        
        let currentLevel = getCleanSchemaLevel()
        print("🧹 Current clean schema level: \(currentLevel.displayName)")
        
        // For production stability, start with minimal and advance gradually
        let targetLevel: CleanSchemaLevel = {
            switch currentLevel {
            case .minimal:
                // Stay minimal until we confirm stability
                print("📊 Maintaining minimal schema for stability")
                return .minimal
            case .production:
                print("📊 Using production schema with \(currentLevel.modelCount) models")
                return .production
            }
        }()
        
        let schema = targetLevel.schema
        print("📊 Clean schema contains exactly \(schema.entities.count) entities")
        
        // Configure model container based on environment
        var configuration = ModelConfiguration()
        
        // CLOUDKIT ENABLED: Now that app is stable, enable CloudKit progressively
        let _ = true // Enable CloudKit for data synchronization
        let forceDevelopmentMode = false // Allow production CloudKit for testing
        
        // Regular environment detection
        #if DEBUG 
        let isSimulator = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil
        #else
        let isSimulator = false
        #endif
        
        // Use more intelligent environment detection
        let isDevEnvironment = isSimulator || forceDevelopmentMode
        
        // CLEAN SCHEMA FIX: Use clean schema system instead of ultra-minimal hack
        let useCleanSchema = true
        
        // Select schema based on clean schema system
        let finalSchema: Schema
        if useCleanSchema {
            // Use clean schema system - exactly 4 or 10 models, no bloat
            finalSchema = targetLevel.schema
            print("🧹 Using clean \(targetLevel.displayName) schema (\(finalSchema.entities.count) models)")
            
            // Validate schema has expected entity count
            _ = validateCleanSchema(finalSchema, expectedCount: targetLevel.modelCount)
        } else {
            // Fallback to ultra-minimal (should not be needed with clean schema)
            finalSchema = Schema([
                AuthUser.self,
                Vehix.Vehicle.self,
                Vehix.InventoryItem.self,
                AppSettings.self
            ], version: .init(1, 0, 0))
            print("🚨 Using fallback ultra-minimal schema (4 models)")
        }
        
        // Always use local storage to prevent CloudKit crashes
        configuration = ModelConfiguration(
            schema: finalSchema,
            isStoredInMemoryOnly: false
        )
        print("🔧 Using local storage only for maximum stability")
        
        do {
            modelContainer = try ModelContainer(
                for: finalSchema, 
                configurations: [configuration]
            )
            print("✅ Model container initialized successfully with clean schema (\(finalSchema.entities.count) entities) and local storage")
            
            #if DEBUG
            debugPrintSchemaInfo(finalSchema)
            #endif
            
        } catch {
            print("❌ Failed to initialize model container: \(error)")
            fatalError("Could not initialize model container: \(error)")
        }
        
        // Initialize services with minimal setup to prevent crashes
        let modelContext = ModelContext(modelContainer)
        
        print("📱 Initializing services for \(isDevEnvironment ? "development" : "production") environment")
        
        // Initialize auth service with context
        let auth = AppAuthServiceImpl(modelContext: modelContext)
        _authService = StateObject(wrappedValue: auth)
        
        // Initialize other services with minimal setup - defer complex initialization
        _serviceTitanService = StateObject(wrappedValue: ServiceTitanService(modelContext: modelContext))
        
        // Initialize Samsara service with minimal setup
        let samsara = SamsaraService(modelContext: modelContext)
        _samsaraService = StateObject(wrappedValue: samsara)
        
        // Initialize CloudKit manager and set model context - defer complex setup
        let cloudKit = CloudKitManager()
        cloudKit.modelContext = modelContext
        _cloudKitManager = StateObject(wrappedValue: cloudKit)
        
        _storeKitManager = StateObject(wrappedValue: StoreKitManager())
        
        // Initialize AI shared data manager for machine learning improvements
        let aiData = AISharedDataManager(modelContext: modelContext, cloudKitManager: cloudKit)
        _aiDataManager = StateObject(wrappedValue: aiData)
        
        // Connect auth service to CloudKit manager
        auth.setCloudKitManager(cloudKit)
        
        // Clean up UserDefaults to prevent 4MB storage violations
        UserDefaultsCleanup.performCleanup()
        UserDefaultsCleanup.checkUserDefaultsSize()
        
        print("✅ App initialization completed successfully")
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if showLaunchScreen {
                    LaunchScreenView()
                        .onAppear {
                            // Show launch screen for longer to allow safe initialization
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation {
                                    showLaunchScreen = false
                                    setupNotifications() // Setup notifications when app launches
                                    
                                    // Initialize complex services after UI is ready
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                        initializeComplexServices()
                                    }
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
                        .environmentObject(aiDataManager)
                        .environmentObject(marketingManager)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut, value: showLaunchScreen)
            .animation(.easeInOut, value: isFinishedLoading)
            .animation(.easeInOut, value: authService.isLoggedIn)
        }
        .modelContainer(modelContainer)
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
    
    // Initialize complex services after app UI has loaded
    private func initializeComplexServices() {
        print("🔧 Initializing complex services...")
        

        
        // Start Samsara auto sync if enabled
        samsaraService.startAutoSyncIfEnabled()
        
        // Setup GPS manager context
        AppleGPSTrackingManager.shared.setModelContext(ModelContext(modelContainer))
        
        print("✅ Complex services initialized")
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
    @EnvironmentObject var storeKit: StoreKitManager
    
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
                    MainTabView() // Premium users get full access
                case .standard:
                    MainTabView() // Standard users also get access (can be limited per feature)
                case .owner:
                    MainTabView() // Business owners get full access
                case .manager:
                    MainTabView() // Business managers get full access
                }
            }
        } else {
            // Check if this is a first-time launch
            if authService.checkFirstTimeSetup() {
                // First time - show business onboarding
                BusinessOnboardingFlow()
                    .environmentObject(authService)
                    .environmentObject(storeKit)
            } else {
                // Returning user - show login screen
                LoginView()
            }
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
    @StateObject private var settingsManager = AppSettingsManager()
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Dashboard Tab
            if authService.currentUser?.userRole == .dealer || authService.currentUser?.userRole == .admin || authService.currentUser?.userRole == .premium {
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
            if authService.currentUser?.userRole == .dealer || authService.currentUser?.userRole == .admin || authService.currentUser?.userRole == .premium {
                NavigationStack {
                    StaffListView()
                        .environmentObject(authService)
                        .environmentObject(storeKitManager)
                }
                .tabItem {
                    Label("Staff", systemImage: "person.2.fill")
                }
                .tag(4)
                
                // Data & Analytics Tab (Managers/Admins only)
                if settingsManager.canUserSeeDataAnalytics(userRole: authService.currentUser?.userRole ?? .standard) {
                    NavigationStack {
                        DataAnalyticsView()
                            .environmentObject(authService)
                            .environment(\.modelContext, modelContext)
                    }
                    .tabItem {
                        Label("Data", systemImage: "chart.bar.xaxis")
                    }
                    .tag(5)
                }
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
            if authService.currentUser?.userRole == .dealer || authService.currentUser?.userRole == .admin || authService.currentUser?.userRole == .premium {
                NavigationStack {
                    InventoryReplenishmentView()
                }
                .environment(\.modelContext, modelContext)
                .tabItem {
                    Label("Replenishment", systemImage: "arrow.clockwise")
                }
                .tag(6)
            }
            // Receipt Scanner Tab
            NavigationStack {
                ReceiptScannerView()
            }
            .tabItem {
                Label("Scan", systemImage: "doc.text.viewfinder")
            }
            .tag(7)
            // Settings Tab
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(8)
        }
        .environmentObject(authService)
        .environmentObject(storeKitManager)
        .onAppear {
            print("MODEL CONTEXT CHECK: Available")
            print("STORE KIT MANAGER: \(storeKitManager)")
            print("AUTH SERVICE: \(authService)")
            settingsManager.setModelContext(modelContext)
            
            // Update StoreKit plan based on user role for beta testing and premium users
            if let userRole = authService.currentUser?.userRole {
                storeKitManager.updateCurrentPlanFromUserRole(userRole)
                print("✅ Updated StoreKit plan to \(storeKitManager.currentPlan) for user role \(userRole)")
            }
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
    @EnvironmentObject var storeKitManager: StoreKitManager
    @Environment(\.modelContext) private var modelContext
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
                        // PRODUCTION MODE: No sample data manager needed
                        
                        // Check if user should see walkthrough (production users get clean walkthrough)
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
                    .environmentObject(storeKitManager)
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
            case .owner:
                MainTabView()
                    .environmentObject(authService)
                    .environmentObject(storeKitManager)
                    .environment(\.modelContext, modelContext)
            case .manager:
                ManagerDashboardView()
                    .environmentObject(authService)
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


