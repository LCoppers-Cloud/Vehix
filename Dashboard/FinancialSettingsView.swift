import SwiftUI
import SwiftData

struct FinancialSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authService: AppAuthService
    
    @State private var settingsManager = AppSettingsManager()
    @State private var isLoading = false
    @State private var showingSaveAlert = false
    @State private var saveMessage = ""
    
    // Local state for editing
    @State private var showFinancialDataToManagers = true
    @State private var showVehicleInventoryValues = true
    @State private var showPurchaseOrderSpending = true
    @State private var showDetailedFinancialReports = false
    @State private var enableExecutiveFinancialSection = true
    @State private var showDataAnalyticsToManagers = true
    @State private var showMonthlySpendingAlerts = true
    @State private var financialAlertThreshold = 10000.0
    @State private var showInventoryValuesInVehicleList = true
    @State private var enableInventoryValueTracking = true
    @State private var enableAutomaticFinancialReports = false
    
    // Check if user has permission to modify settings
    private var hasPermission: Bool {
        authService.currentUser?.userRole == .admin || 
        authService.currentUser?.userRole == .dealer
    }
    
    var body: some View {
        NavigationStack {
            Form {
                if hasPermission {
                    settingsContent
                } else {
                    accessDeniedSection
                }
            }
            .navigationTitle("Financial Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                if hasPermission {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            saveSettings()
                        }
                        .disabled(isLoading)
                    }
                }
            }
            .onAppear {
                settingsManager.setModelContext(modelContext)
                loadCurrentSettings()
            }
            .alert("Settings Saved", isPresented: $showingSaveAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text(saveMessage)
            }
        }
    }
    
    private var settingsContent: some View {
        Group {
            // Manager Visibility Section
            Section {
                Toggle("Show Financial Data to Managers", isOn: $showFinancialDataToManagers)
                    .help("Allow managers to see financial metrics and spending data")
                
                Toggle("Show Vehicle Inventory Values", isOn: $showVehicleInventoryValues)
                    .help("Display inventory values on vehicles in lists and details")
                
                Toggle("Show Purchase Order Spending", isOn: $showPurchaseOrderSpending)
                    .help("Display monthly, quarterly, and yearly PO spending amounts")
                
                Toggle("Allow Detailed Financial Reports", isOn: $showDetailedFinancialReports)
                    .help("Give managers access to detailed financial reports and analytics")
                
                Toggle("Show Data & Analytics Tab", isOn: $showDataAnalyticsToManagers)
                    .help("Allow managers to access the Data & Analytics tab with business intelligence")
            } header: {
                Text("Manager Visibility")
            } footer: {
                Text("Control what financial information managers can see. Owners and admins always have full access.")
            }
            
            // Dashboard Customization Section
            Section {
                Toggle("Enable Executive Financial Section", isOn: $enableExecutiveFinancialSection)
                    .help("Show the executive financial overview section on the dashboard")
                
                Toggle("Show Monthly Spending Alerts", isOn: $showMonthlySpendingAlerts)
                    .help("Display alerts when monthly spending exceeds the threshold")
                
                HStack {
                    Text("Alert Threshold")
                    Spacer()
                    TextField("Amount", value: $financialAlertThreshold, format: .currency(code: "USD"))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                        .keyboardType(.decimalPad)
                }
                .help("Alert when monthly spending exceeds this amount")
            } header: {
                Text("Dashboard Settings")
            } footer: {
                Text("Customize how financial information appears on the dashboard.")
            }
            
            // Inventory Settings Section
            Section {
                Toggle("Show Inventory Values in Vehicle List", isOn: $showInventoryValuesInVehicleList)
                    .help("Display inventory values next to each vehicle in the vehicle list")
                
                Toggle("Enable Inventory Value Tracking", isOn: $enableInventoryValueTracking)
                    .help("Track and calculate inventory values across all locations")
            } header: {
                Text("Inventory Settings")
            } footer: {
                Text("Control how inventory values are displayed and tracked.")
            }
            
            // Reporting Settings Section
            Section {
                Toggle("Enable Automatic Financial Reports", isOn: $enableAutomaticFinancialReports)
                    .help("Automatically generate and send monthly financial reports")
                
                if enableAutomaticFinancialReports {
                    NavigationLink("Configure Report Recipients") {
                        ReportRecipientsView(settingsManager: settingsManager)
                    }
                }
            } header: {
                Text("Reporting Settings")
            } footer: {
                Text("Configure automatic financial reporting and distribution.")
            }
            
            // Current Settings Info
            Section {
                if let settings = settingsManager.settings {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Last Updated:")
                            Spacer()
                            Text(settings.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                .foregroundColor(.secondary)
                        }
                        
                        if !settings.updatedByUserId.isEmpty {
                            HStack {
                                Text("Updated By:")
                                Spacer()
                                Text(settings.updatedByUserId)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text("Settings Information")
            }
        }
    }
    
    private var accessDeniedSection: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.red)
                
                Text("Access Restricted")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Only owners and administrators can modify financial settings.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
    }
    
    private func loadCurrentSettings() {
        guard let settings = settingsManager.settings else { return }
        
        showFinancialDataToManagers = settings.showFinancialDataToManagers
        showVehicleInventoryValues = settings.showVehicleInventoryValues
        showPurchaseOrderSpending = settings.showPurchaseOrderSpending
        showDetailedFinancialReports = settings.showDetailedFinancialReports
        enableExecutiveFinancialSection = settings.enableExecutiveFinancialSection
        showDataAnalyticsToManagers = settings.showDataAnalyticsToManagers
        showMonthlySpendingAlerts = settings.showMonthlySpendingAlerts
        financialAlertThreshold = settings.financialAlertThreshold
        showInventoryValuesInVehicleList = settings.showInventoryValuesInVehicleList
        enableInventoryValueTracking = settings.enableInventoryValueTracking
        enableAutomaticFinancialReports = settings.enableAutomaticFinancialReports
    }
    
    private func saveSettings() {
        guard let currentSettings = settingsManager.settings,
              let userId = authService.currentUser?.id else { return }
        
        isLoading = true
        
        // Update settings with new values
        currentSettings.showFinancialDataToManagers = showFinancialDataToManagers
        currentSettings.showVehicleInventoryValues = showVehicleInventoryValues
        currentSettings.showPurchaseOrderSpending = showPurchaseOrderSpending
        currentSettings.showDetailedFinancialReports = showDetailedFinancialReports
        currentSettings.enableExecutiveFinancialSection = enableExecutiveFinancialSection
        currentSettings.showDataAnalyticsToManagers = showDataAnalyticsToManagers
        currentSettings.showMonthlySpendingAlerts = showMonthlySpendingAlerts
        currentSettings.financialAlertThreshold = financialAlertThreshold
        currentSettings.showInventoryValuesInVehicleList = showInventoryValuesInVehicleList
        currentSettings.enableInventoryValueTracking = enableInventoryValueTracking
        currentSettings.enableAutomaticFinancialReports = enableAutomaticFinancialReports
        
        Task {
            let success = await settingsManager.updateSettings(currentSettings, updatedBy: userId)
            
            await MainActor.run {
                isLoading = false
                
                if success {
                    saveMessage = "Financial settings have been updated successfully."
                    showingSaveAlert = true
                } else {
                    saveMessage = settingsManager.errorMessage ?? "Failed to save settings."
                    showingSaveAlert = true
                }
            }
        }
    }
}

// MARK: - Report Recipients View

struct ReportRecipientsView: View {
    @Environment(\.dismiss) private var dismiss
    let settingsManager: AppSettingsManager
    
    @State private var recipients: [String] = []
    @State private var newRecipient = ""
    @State private var showingAddAlert = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(recipients, id: \.self) { recipient in
                        HStack {
                            Text(recipient)
                            Spacer()
                            Button("Remove") {
                                recipients.removeAll { $0 == recipient }
                            }
                            .foregroundColor(.red)
                        }
                    }
                    
                    Button("Add Recipient") {
                        showingAddAlert = true
                    }
                } header: {
                    Text("Email Recipients")
                } footer: {
                    Text("Monthly financial reports will be sent to these email addresses.")
                }
            }
            .navigationTitle("Report Recipients")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        saveRecipients()
                        dismiss()
                    }
                }
            }
            .onAppear {
                recipients = settingsManager.settings?.monthlyReportRecipients ?? []
            }
            .alert("Add Email Recipient", isPresented: $showingAddAlert) {
                TextField("Email Address", text: $newRecipient)
                Button("Add") {
                    if !newRecipient.isEmpty && newRecipient.contains("@") {
                        recipients.append(newRecipient)
                        newRecipient = ""
                    }
                }
                Button("Cancel", role: .cancel) {
                    newRecipient = ""
                }
            } message: {
                Text("Enter the email address to receive monthly financial reports.")
            }
        }
    }
    
    private func saveRecipients() {
        settingsManager.settings?.monthlyReportRecipients = recipients
    }
}

#Preview {
    FinancialSettingsView()
        .environmentObject(AppAuthService())
        .modelContainer(for: AppSettings.self, inMemory: true)
} 