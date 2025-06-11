import SwiftUI
import SwiftData
import StoreKit

struct EnhancedBusinessManagementView: View {
    @EnvironmentObject var authService: AppAuthService
    @EnvironmentObject var storeKitManager: StoreKitManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var businessAccount: BusinessAccount?
    @State private var vehicles: [Vehix.Vehicle] = []
    @State private var users: [UserAccount] = []
    @State private var isLoading = true
    @State private var showingSubscriptionManager = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView("Loading business data...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    businessManagementContent
                }
            }
            .navigationTitle("Business Management")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingSubscriptionManager) {
            AppleSubscriptionManagementView()
                .environmentObject(storeKitManager)
        }
        .onAppear {
            loadData()
        }
    }
    
    private var businessManagementContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                businessOverviewSection
                subscriptionUsageSection
                appleSubscriptionSection
                companySettingsSection
            }
            .padding()
        }
    }
    
    // MARK: - Business Overview Section
    
    private var businessOverviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Business Overview")
                .font(.headline.bold())
                .foregroundColor(Color.vehixBlue)
            
            HStack(spacing: 16) {
                BusinessStatCard(
                    title: "Total Vehicles",
                    value: "\(vehicles.count)",
                    icon: "car.2.fill",
                    color: Color.vehixBlue
                )
                
                BusinessStatCard(
                    title: "Active Users",
                    value: "\(activeUserCount)",
                    icon: "person.3.fill",
                    color: Color.vehixGreen
                )
                
                BusinessStatCard(
                    title: "Technicians",
                    value: "\(technicianCount)",
                    icon: "wrench.and.screwdriver.fill",
                    color: Color.vehixOrange
                )
            }
        }
        .padding()
        .background(Color.vehixSecondaryBackground)
        .cornerRadius(16)
    }
    
    // MARK: - Subscription Usage Section
    
    private var subscriptionUsageSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Subscription Usage")
                .font(.headline.bold())
                .foregroundColor(Color.vehixBlue)
            
            VStack(spacing: 12) {
                UsageProgressView(
                    title: "Vehicles",
                    current: vehicles.count,
                    limit: subscriptionLimits.maxVehicles,
                    color: Color.vehixBlue
                )
                
                UsageProgressView(
                    title: "Staff Members",
                    current: users.count,
                    limit: subscriptionLimits.maxManagers + subscriptionLimits.maxTechnicians + 1, // +1 for owner
                    color: Color.vehixGreen
                )
                
                UsageProgressView(
                    title: "Technicians",
                    current: technicianCount,
                    limit: subscriptionLimits.maxTechnicians,
                    color: Color.vehixOrange
                )
            }
            
            if isNearingLimits {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    
                    Text("You're approaching your subscription limits. Consider upgrading your plan.")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color.vehixSecondaryBackground)
        .cornerRadius(16)
    }
    
    // MARK: - Apple Subscription Section
    
    private var appleSubscriptionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Subscription Management")
                .font(.headline.bold())
                .foregroundColor(Color.vehixBlue)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Plan: \(currentPlanName)")
                        .font(.subheadline.bold())
                        .foregroundColor(Color.vehixText)
                    
                    if let trialBillingDate = storeKitManager.trialBillingDate {
                        Text("Next billing: \(formatDate(trialBillingDate))")
                            .font(.caption)
                            .foregroundColor(Color.vehixSecondaryText)
                    }
                    
                    if storeKitManager.isInTrial {
                        HStack {
                            Image(systemName: "gift.fill")
                                .foregroundColor(.green)
                            Text("Trial Active")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Spacer()
                
                Button("Manage in App Store") {
                    showingSubscriptionManager = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color.vehixSecondaryBackground)
        .cornerRadius(16)
    }
    
    // MARK: - Company Settings Section
    
    private var companySettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Company Information")
                .font(.headline.bold())
                .foregroundColor(Color.vehixBlue)
            
            if let business = businessAccount {
                VStack(alignment: .leading, spacing: 12) {
                    CompanyInfoRow(
                        icon: "building.2.fill",
                        title: "Company Name",
                        value: business.businessName
                    )
                    
                    CompanyInfoRow(
                        icon: "location.fill",
                        title: "Address",
                        value: "50 Hegenberger Loop, Oakland, CA 94621"
                    )
                    
                    CompanyInfoRow(
                        icon: "envelope.fill",
                        title: "Contact Email",
                        value: "info@vehix.com" // Using standard business email
                    )
                    
                    CompanyInfoRow(
                        icon: "phone.fill",
                        title: "Phone Number",
                        value: "(510) 555-0123" // Oakland area code placeholder
                    )
                    
                    CompanyInfoRow(
                        icon: "calendar.fill",
                        title: "Created",
                        value: formatDate(business.createdAt)
                    )
                }
            } else {
                Text("Company information not available")
                    .font(.caption)
                    .foregroundColor(Color.vehixSecondaryText)
            }
        }
        .padding()
        .background(Color.vehixSecondaryBackground)
        .cornerRadius(16)
    }
    
    // MARK: - Helper Properties
    
    private var activeUserCount: Int {
        users.filter { $0.isActive }.count
    }
    
    private var technicianCount: Int {
        users.filter { $0.accountType == .technician }.count
    }
    
    private var subscriptionLimits: SubscriptionLimitations {
        return SubscriptionLimitations.limitations(for: storeKitManager.currentPlan)
    }
    
    private var isNearingLimits: Bool {
        let vehicleUsage = Double(vehicles.count) / Double(subscriptionLimits.maxVehicles)
        let totalUserLimit = subscriptionLimits.maxManagers + subscriptionLimits.maxTechnicians + 1
        let userUsage = Double(users.count) / Double(totalUserLimit)
        return vehicleUsage > 0.8 || userUsage > 0.8
    }
    
    private var currentPlanName: String {
        return storeKitManager.currentPlanName
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    // MARK: - Data Loading
    
    private func loadData() {
        isLoading = true
        
        Task {
            do {
                // Load business account
                let businessDescriptor = FetchDescriptor<BusinessAccount>()
                let businesses = try modelContext.fetch(businessDescriptor)
                
                // Load vehicles
                let vehicleDescriptor = FetchDescriptor<Vehix.Vehicle>()
                let loadedVehicles = try modelContext.fetch(vehicleDescriptor)
                
                // Load users
                let userDescriptor = FetchDescriptor<UserAccount>()
                let loadedUsers = try modelContext.fetch(userDescriptor)
                
                await MainActor.run {
                    self.businessAccount = businesses.first
                    self.vehicles = loadedVehicles
                    self.users = loadedUsers
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    print("Error loading business data: \(error)")
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct BusinessStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2.bold())
                .foregroundColor(Color.vehixText)
            
            Text(title)
                .font(.caption)
                .foregroundColor(Color.vehixSecondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.vehixBackground)
        .cornerRadius(12)
    }
}

struct UsageProgressView: View {
    let title: String
    let current: Int
    let limit: Int
    let color: Color
    
    private var progress: Double {
        guard limit > 0 else { return 0 }
        return min(Double(current) / Double(limit), 1.0)
    }
    
    private var isNearLimit: Bool {
        progress > 0.8
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(Color.vehixText)
                
                Spacer()
                
                Text("\(current) / \(limit)")
                    .font(.caption)
                    .foregroundColor(isNearLimit ? .orange : Color.vehixSecondaryText)
            }
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: isNearLimit ? .orange : color))
        }
    }
}

struct CompanyInfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(Color.vehixBlue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(Color.vehixSecondaryText)
                
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(Color.vehixText)
            }
            
            Spacer()
        }
    }
} 