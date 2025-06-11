import SwiftUI
import StoreKit

struct AppleSubscriptionManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var storeKitManager: StoreKitManager
    @EnvironmentObject var authService: AppAuthService
    
    @State private var showingAppleManagement = false
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    currentPlanSection
                    subscriptionDetailsSection
                    appleManagementSection
                    usageSection
                    billingSection
                }
                .padding()
            }
            .navigationTitle("Subscription")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            Task {
                await loadSubscriptionInfo()
            }
        }
    }
    
    private var currentPlanSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Plan")
                .font(.headline.bold())
                .foregroundColor(Color.vehixBlue)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(storeKitManager.currentPlanName)
                        .font(.title2.bold())
                        .foregroundColor(Color.vehixText)
                    
                    if storeKitManager.isInTrial {
                        Text("\(storeKitManager.trialDaysRemaining) days remaining")
                            .font(.subheadline)
                            .foregroundColor(Color.vehixOrange)
                    } else {
                        Text(subscriptionStatusText)
                            .font(.subheadline)
                            .foregroundColor(storeKitManager.hasActiveSubscription ? Color.vehixGreen : Color.vehixOrange)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(currentPricing)
                        .font(.title3.bold())
                        .foregroundColor(Color.vehixText)
                    
                    if storeKitManager.currentPlan == .enterprise {
                        Text("Per vehicle")
                            .font(.caption)
                            .foregroundColor(Color.vehixSecondaryText)
                    }
                }
            }
            .padding()
            .background(Color.vehixSecondaryBackground)
            .cornerRadius(12)
        }
    }
    
    private var subscriptionDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Plan Features")
                .font(.headline.bold())
                .foregroundColor(Color.vehixBlue)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(storeKitManager.currentPlan.features, id: \.self) { feature in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color.vehixGreen)
                            .font(.caption)
                        
                        Text(feature)
                            .font(.body)
                            .foregroundColor(Color.vehixText)
                        
                        Spacer()
                    }
                }
            }
            .padding()
            .background(Color.vehixSecondaryBackground)
            .cornerRadius(12)
        }
    }
    
    private var appleManagementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Subscription Management")
                .font(.headline.bold())
                .foregroundColor(Color.vehixBlue)
            
            VStack(spacing: 12) {
                Button(action: openAppleSubscriptionManagement) {
                    HStack {
                        Image(systemName: "gear")
                            .foregroundColor(Color.vehixBlue)
                            .font(.title2)
                        
                        VStack(alignment: .leading) {
                            Text("Manage with Apple")
                                .font(.headline)
                                .foregroundColor(Color.vehixText)
                            
                            Text("Change plan, cancel, or update payment method")
                                .font(.caption)
                                .foregroundColor(Color.vehixSecondaryText)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(Color.vehixSecondaryText)
                    }
                    .padding()
                    .background(Color.vehixSecondaryBackground)
                    .cornerRadius(12)
                }
                .disabled(isLoading)
                
                if storeKitManager.isInTrial {
                    Button(action: showUpgradeOptions) {
                        HStack {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundColor(Color.vehixGreen)
                                .font(.title2)
                            
                            VStack(alignment: .leading) {
                                Text("Upgrade Plan")
                                    .font(.headline)
                                    .foregroundColor(Color.vehixText)
                                
                                Text("Choose a paid plan before trial expires")
                                    .font(.caption)
                                    .foregroundColor(Color.vehixSecondaryText)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(Color.vehixSecondaryText)
                        }
                        .padding()
                        .background(Color.vehixGreen.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
    
    private var usageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Usage")
                .font(.headline.bold())
                .foregroundColor(Color.vehixBlue)
            
            VStack(spacing: 12) {
                UsageRowView(
                    title: "Vehicles",
                    current: storeKitManager.currentVehicleCount,
                    limit: storeKitManager.vehicleLimit,
                    icon: "car.fill"
                )
                
                UsageRowView(
                    title: "Staff Members",
                    current: storeKitManager.currentStaffCount,
                    limit: storeKitManager.staffLimit,
                    icon: "person.3.fill"
                )
                
                UsageRowView(
                    title: "Technicians",
                    current: storeKitManager.currentTechnicianCount,
                    limit: storeKitManager.technicianLimit,
                    icon: "wrench.and.screwdriver.fill"
                )
            }
            .padding()
            .background(Color.vehixSecondaryBackground)
            .cornerRadius(12)
        }
    }
    
    private var billingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Billing Information")
                .font(.headline.bold())
                .foregroundColor(Color.vehixBlue)
            
            VStack(alignment: .leading, spacing: 8) {
                if let subscription = storeKitManager.subscription {
                    BillingRowView(title: "Next Billing Date", value: formatDate(subscription.expirationDate))
                    BillingRowView(title: "Auto-Renewal", value: subscription.isAutoRenewable ? "Enabled" : "Disabled")
                    
                    if storeKitManager.currentPlan == .enterprise {
                        BillingRowView(title: "Monthly Total", value: String(format: "$%.0f", storeKitManager.enterpriseMonthlyTotal))
                        BillingRowView(title: "Vehicles", value: "\(storeKitManager.currentVehicleCount) × $50")
                    }
                } else {
                    Text("Billing information will be available after subscription purchase")
                        .font(.body)
                        .foregroundColor(Color.vehixSecondaryText)
                        .padding()
                }
            }
            .padding()
            .background(Color.vehixSecondaryBackground)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Computed Properties
    
    private var subscriptionStatusText: String {
        if storeKitManager.hasActiveSubscription {
            return "Active subscription"
        } else {
            return "No active subscription"
        }
    }
    
    private var currentPricing: String {
        switch storeKitManager.currentPlan {
        case .trial:
            return "Free"
        case .enterprise:
            return String(format: "$%.0f/month", storeKitManager.enterpriseMonthlyTotal)
        default:
            return String(format: "$%.0f/month", storeKitManager.currentPlan.monthlyPrice)
        }
    }
    
    // MARK: - Actions
    
    private func loadSubscriptionInfo() async {
        isLoading = true
        await storeKitManager.checkSubscriptionStatus()
        isLoading = false
    }
    
    private func openAppleSubscriptionManagement() {
        Task {
            do {
                // This opens Apple's native subscription management
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    try await AppStore.showManageSubscriptions(in: windowScene)
                }
            } catch {
                print("Failed to open Apple subscription management: \(error)")
                // Fallback to opening Settings app
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    await MainActor.run {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
            }
        }
    }
    
    private func showUpgradeOptions() {
        // Show upgrade options - this could navigate to a plan selection view
        // For now, we'll also open Apple's subscription management
        openAppleSubscriptionManagement()
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "Not available" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Views

struct UsageRowView: View {
    let title: String
    let current: Int
    let limit: Int
    let icon: String
    
    private var progressPercentage: Double {
        guard limit > 0 else { return 0 }
        return min(1.0, Double(current) / Double(limit))
    }
    
    private var progressColor: Color {
        if progressPercentage < 0.7 {
            return Color.vehixGreen
        } else if progressPercentage < 0.9 {
            return Color.vehixYellow
        } else {
            return Color.vehixOrange
        }
    }
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(Color.vehixBlue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundColor(Color.vehixText)
                    
                    Spacer()
                    
                    Text("\(current) / \(limit == 999999 ? "∞" : "\(limit)")")
                        .font(.subheadline)
                        .foregroundColor(Color.vehixSecondaryText)
                }
                
                if limit != 999999 {
                    ProgressView(value: progressPercentage)
                        .progressViewStyle(LinearProgressViewStyle(tint: progressColor))
                        .scaleEffect(y: 0.5)
                }
            }
        }
    }
}

struct BillingRowView: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundColor(Color.vehixText)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .foregroundColor(Color.vehixSecondaryText)
        }
    }
}

#Preview {
    AppleSubscriptionManagementView()
        .environmentObject(StoreKitManager())
        .environmentObject(AppAuthService())
} 