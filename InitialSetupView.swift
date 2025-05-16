import SwiftUI
import SwiftData

struct InitialSetupView: View {
    @EnvironmentObject var authService: AppAuthService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // State for tracking the setup steps
    @State private var currentStep = 0
    
    // Business info
    @State private var businessName = ""
    @State private var businessType = ""
    @State private var numberOfVehicles = 5
    @State private var numberOfTechnicians = 3
    
    // Inventory preferences
    @State private var trackWarehouseInventory = true
    @State private var trackVehicleInventory = true
    @State private var trackVehicleTools = false
    
    // Integration preferences
    @State private var useServiceTitan = false
    @State private var useSamsara = false
    @State private var useBuiltInLocationTracking = true
    
    // Data sharing options
    @State private var shareInventoryCatalog = true
    @State private var sharePricingInfo = false
    @State private var shareUsageData = false
    
    // References to integration services
    @StateObject private var cloudKitManager = CloudKitManager()
    @ObservedObject var serviceTitanService = ServiceTitanService()
    @ObservedObject var samsaraService = SamsaraService()
    
    // Setup is complete
    @State private var isSetupComplete = false
    
    var steps = [
        "Welcome",
        "Business Info",
        "Vehicles",
        "Inventory",
        "Integrations",
        "Data Sharing",
        "Complete"
    ]
    
    var body: some View {
        VStack {
            // Progress indicator
            ProgressView(value: Double(currentStep), total: Double(steps.count - 1))
                .padding()
            
            Text(steps[currentStep])
                .font(.headline)
                .padding(.bottom)
            
            // Different content based on current step
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch currentStep {
                    case 0:
                        welcomeView
                    case 1:
                        businessInfoView
                    case 2:
                        vehiclesView
                    case 3:
                        inventoryView
                    case 4:
                        integrationsView
                    case 5:
                        dataSharingView
                    case 6:
                        completeView
                    default:
                        Text("Unknown step")
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Spacer()
            
            // Navigation buttons
            HStack {
                if currentStep > 0 {
                    Button("Back") {
                        withAnimation {
                            currentStep -= 1
                        }
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
                
                if currentStep < steps.count - 1 {
                    Button(currentStep == steps.count - 2 ? "Finish" : "Next") {
                        withAnimation {
                            if currentStep == steps.count - 2 {
                                // Final step, save all settings
                                saveSettings()
                                currentStep += 1
                            } else {
                                currentStep += 1
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Start Using Vehix") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .onAppear {
            // Set model contexts
            cloudKitManager.modelContext = modelContext
            serviceTitanService.modelContext = modelContext
            samsaraService.modelContext = modelContext
        }
    }
    
    // MARK: - Step Views
    
    // Step 1: Welcome
    private var welcomeView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Welcome to Vehix!")
                .font(.title)
                .foregroundColor(.primary)
            
            Text("Let's set up your account to best fit your business needs. This process will only take a few minutes.")
                .font(.body)
            
            Text("We'll help you configure:")
                .font(.headline)
                .padding(.top)
            
            VStack(alignment: .leading, spacing: 10) {
                bulletPoint(text: "Your business information")
                bulletPoint(text: "Vehicle tracking preferences")
                bulletPoint(text: "Inventory management options")
                bulletPoint(text: "Integration with other systems")
                bulletPoint(text: "Data sharing preferences")
            }
            
            Spacer()
                .frame(height: 20)
            
            Text("Tap 'Next' to begin.")
                .font(.body)
                .italic()
        }
    }
    
    // Step 2: Business Info
    private var businessInfoView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Business Information")
                .font(.title)
                .foregroundColor(.primary)
            
            Text("Tell us a bit about your business")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.bottom)
            
            Group {
                Text("Business Name")
                    .font(.headline)
                
                TextField("Enter your business name", text: $businessName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.bottom)
                
                Text("Business Type")
                    .font(.headline)
                
                Picker("Select business type", selection: $businessType) {
                    Text("Auto Repair").tag("Auto Repair")
                    Text("Fleet Management").tag("Fleet Management")
                    Text("Dealership").tag("Dealership")
                    Text("Other").tag("Other")
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.bottom)
            }
            
            Text("This information helps us customize your dashboard and reports.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // Step 3: Vehicles
    private var vehiclesView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Vehicle Tracking")
                .font(.title)
                .foregroundColor(.primary)
            
            Text("Configure your vehicle tracking preferences")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.bottom)
            
            Group {
                Text("Approximate Number of Vehicles")
                    .font(.headline)
                
                Stepper("\(numberOfVehicles) vehicles", value: $numberOfVehicles, in: 1...100)
                    .padding(.bottom)
                
                Text("Approximate Number of Technicians")
                    .font(.headline)
                
                Stepper("\(numberOfTechnicians) technicians", value: $numberOfTechnicians, in: 1...50)
                    .padding(.bottom)
            }
            
            Text("This helps us optimize your dashboard and allocate resources appropriately.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // Step 4: Inventory
    private var inventoryView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Inventory Tracking")
                .font(.title)
                .foregroundColor(.primary)
            
            Text("Configure how you want to track inventory")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.bottom)
            
            Toggle("Track Warehouse Inventory", isOn: $trackWarehouseInventory)
                .padding(.bottom, 5)
            
            Text("Track parts and supplies stored in your warehouse or shop")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom)
            
            Toggle("Track Vehicle Inventory", isOn: $trackVehicleInventory)
                .padding(.bottom, 5)
            
            Text("Track parts and supplies assigned to specific vehicles")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom)
            
            Toggle("Track Vehicle Tools", isOn: $trackVehicleTools)
                .padding(.bottom, 5)
            
            Text("Track tools and equipment assigned to specific vehicles")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom)
            
            Text("You can change these preferences later in Settings.")
                .font(.caption)
                .italic()
                .foregroundColor(.secondary)
        }
    }
    
    // Step 5: Integrations
    private var integrationsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Integrations")
                .font(.title)
                .foregroundColor(.primary)
            
            Text("Connect with other systems to enhance functionality")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.bottom)
            
            Group {
                VStack(alignment: .leading, spacing: 5) {
                    Toggle("ServiceTitan Integration", isOn: $useServiceTitan)
                    
                    Text("Sync inventory, purchase orders, and job information with ServiceTitan")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom)
                }
                
                Divider()
                
                Text("Vehicle Location Tracking")
                    .font(.headline)
                    .padding(.top)
                
                VStack(alignment: .leading, spacing: 5) {
                    Toggle("Samsara Fleet Management", isOn: $useSamsara)
                    
                    Text("Connect with Samsara for real-time GPS tracking, diagnostics, and mileage")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom)
                }
                
                VStack(alignment: .leading, spacing: 5) {
                    Toggle("Built-in Location Tracking", isOn: $useBuiltInLocationTracking)
                    
                    Text("Use iOS location services to track vehicle locations and mileage")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if useBuiltInLocationTracking {
                    Text("Note: iOS location tracking requires users to install the Vehix app on their devices and grant location permissions.")
                        .font(.caption)
                        .italic()
                        .foregroundColor(.secondary)
                        .padding(.top, 5)
                }
            }
            
            Text("You can configure these integrations in detail later in Settings.")
                .font(.caption)
                .italic()
                .foregroundColor(.secondary)
                .padding(.top)
        }
    }
    
    // Step 6: Data Sharing
    private var dataSharingView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Data Sharing")
                .font(.title)
                .foregroundColor(.primary)
            
            Text("Configure how your data is shared with the Vehix community")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.bottom)
            
            VStack(alignment: .leading, spacing: 5) {
                Toggle("Share Inventory Catalog", isOn: $shareInventoryCatalog)
                
                Text("Share your inventory items with other Vehix users to help build a comprehensive parts catalog")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom)
            }
            
            if shareInventoryCatalog {
                VStack(alignment: .leading, spacing: 5) {
                    Toggle("Share Pricing Information", isOn: $sharePricingInfo)
                    
                    Text("Include your pricing information with shared inventory items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom)
                }
                
                VStack(alignment: .leading, spacing: 5) {
                    Toggle("Share Usage Data", isOn: $shareUsageData)
                    
                    Text("Share inventory usage statistics to help improve inventory recommendations")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom)
                }
            }
            
            Text("Benefits of sharing:")
                .font(.headline)
                .padding(.top)
            
            VStack(alignment: .leading, spacing: 10) {
                bulletPoint(text: "Access to a comprehensive parts database")
                bulletPoint(text: "Improved part recommendations")
                bulletPoint(text: "Faster inventory setup with smart suggestions")
            }
            
            Text("Your business identity is never shared with other users.")
                .font(.caption)
                .italic()
                .foregroundColor(.secondary)
                .padding(.top)
        }
    }
    
    // Step 7: Complete
    private var completeView: some View {
        VStack(alignment: .center, spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
                .padding()
            
            Text("Setup Complete!")
                .font(.title)
                .foregroundColor(.primary)
            
            Text("Your Vehix account is now configured based on your preferences. You're ready to start managing your vehicles and inventory.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Summary:")
                    .font(.headline)
                    .padding(.top)
                
                Text("• Business: \(businessName)")
                Text("• Vehicle tracking: \(numberOfVehicles) vehicles, \(numberOfTechnicians) technicians")
                
                Text("• Inventory: \(trackWarehouseInventory ? "Warehouse + " : "")\(trackVehicleInventory ? "Vehicle" : "")")
                
                Text("• Integrations: \(useServiceTitan ? "ServiceTitan, " : "")\(useSamsara ? "Samsara, " : "")\(useBuiltInLocationTracking ? "Built-in location tracking" : "")")
                
                Text("• Data sharing: \(shareInventoryCatalog ? "Enabled" : "Disabled")")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)
            
            Text("You can adjust these settings anytime from the Settings tab.")
                .font(.caption)
                .italic()
                .foregroundColor(.secondary)
                .padding(.top)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Helper Functions
    
    // Create a bullet point
    private func bulletPoint(text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("•")
                .font(.headline)
            
            Text(text)
                .font(.body)
        }
    }
    
    // Save all settings
    private func saveSettings() {
        // Save user settings
        if let user = authService.currentUser {
            user.hasCompletedSetup = true
            // Additional user settings could be saved here
        }
        
        // Configure the CloudKit manager
        cloudKitManager.configureSharing(
            shareInventory: shareInventoryCatalog,
            sharePrices: sharePricingInfo,
            shareUsageData: shareUsageData
        )
        
        // Save integration preferences
        saveIntegrationPreferences()
        
        // Save to model context
        do {
            try modelContext.save()
        } catch {
            print("Error saving setup settings: \(error)")
        }
    }
    
    // Save integration preferences
    private func saveIntegrationPreferences() {
        // ServiceTitan preferences
        if useServiceTitan {
            let config = ServiceTitanConfig()
            config.syncInventory = trackWarehouseInventory
            config.syncTechnicians = true
            config.syncVendors = true
            config.syncPurchaseOrders = true
            modelContext.insert(config)
        }
        
        // Samsara preferences
        if useSamsara {
            let config = SamsaraConfig()
            config.isEnabled = true
            config.syncIntervalMinutes = 30 // Default to 30 minutes
            modelContext.insert(config)
        }
        
        // Could add built-in location tracking settings here
        // This would involve saving a preference and then setting up location services
    }
}

extension AuthUser {
    // Add a property to track if the user has completed setup
    var hasCompletedSetup: Bool {
        get {
            // Try to get the value from UserDefaults
            // This is a workaround since we can't directly add properties to a SwiftData model
            return UserDefaults.standard.bool(forKey: "user_\(id)_hasCompletedSetup")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "user_\(id)_hasCompletedSetup")
        }
    }
}

#Preview {
    InitialSetupView()
        .environmentObject(AppAuthService())
} 