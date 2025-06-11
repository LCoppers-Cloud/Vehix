import SwiftUI
import StoreKit

@available(iOS 15.0, *)
struct SubscriptionManagementView: View {
    @EnvironmentObject var storeKit: StoreKitManager
    @Environment(\.dismiss) var dismiss
    @State private var selectedPlan: SubscriptionPlan = .basic
    @State private var showingTerms = false
    @State private var billingPeriod: BillingPeriod = .monthly
    
    enum BillingPeriod: String, CaseIterable {
        case monthly = "Monthly"
        case yearly = "Yearly"
        
        var savings: String {
            switch self {
            case .monthly: return ""
            case .yearly: return "Save 10%"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Current Plan Status
                    currentPlanSection
                    
                    // Billing Period Toggle
                    billingPeriodToggle
                    
                    // Plan Options
                    planOptionsSection
                    
                    // Selected Plan Details
                    selectedPlanDetailsSection
                    
                    // Action Button
                    actionButtonSection
                    
                    // Terms and Fine Print
                    termsSection
                }
                .padding()
            }
            .navigationTitle("Subscription Plans")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingTerms) {
            termsAndConditionsView
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
                                 Image(systemName: "star.circle.fill")
                         .font(.system(size: 50))
                         .foregroundColor(Color.vehixYellow)
            
            Text("Choose Your Vehix Plan")
                .font(.title.bold())
            
            Text("Powerful vehicle inventory management for your business")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top)
    }
    
    // MARK: - Current Plan Section
    private var currentPlanSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Current Plan: \(storeKit.currentPlanName)")
                    .font(.headline)
                Spacer()
            }
            
            if storeKit.isInTrial {
                Text("Trial ends in \(storeKit.trialDaysRemaining) days")
                    .font(.subheadline)
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Billing Period Toggle
    private var billingPeriodToggle: some View {
        HStack {
            Text("Billing Period:")
                .font(.headline)
            
            Spacer()
            
            Picker("Billing Period", selection: $billingPeriod) {
                ForEach(BillingPeriod.allCases, id: \.self) { period in
                    HStack {
                        Text(period.rawValue)
                        if !period.savings.isEmpty {
                            Text(period.savings)
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    .tag(period)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }
    
    // MARK: - Plan Options Section
    private var planOptionsSection: some View {
        VStack(spacing: 16) {
            Text("Available Plans")
                .font(.title2.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ForEach(SubscriptionPlan.allCases.filter { $0 != .trial }, id: \.self) { plan in
                planCard(for: plan)
            }
        }
    }
    
    // MARK: - Plan Card
    private func planCard(for plan: SubscriptionPlan) -> some View {
        Button(action: {
            selectedPlan = plan
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // Plan Header
                HStack {
                    VStack(alignment: .leading) {
                        Text(plan.displayName)
                            .font(.title3.bold())
                            .foregroundColor(.primary)
                        
                        Text(priceText(for: plan))
                            .font(.title2.bold())
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    if selectedPlan == plan {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title2)
                    } else {
                        Image(systemName: "circle")
                            .foregroundColor(.gray)
                            .font(.title2)
                    }
                }
                
                // Plan Features
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(plan.features.prefix(4), id: \.self) { feature in
                        HStack(alignment: .top, spacing: 8) {
                                                 Image(systemName: "checkmark")
                                 .foregroundColor(Color.vehixGreen)
                                .font(.caption.bold())
                            Text(feature)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                }
                
                                 // Popular badge for Pro plan
                 if plan == .pro {
                     Text("MOST POPULAR")
                         .font(.caption.bold())
                         .foregroundColor(.white)
                         .padding(.horizontal, 8)
                         .padding(.vertical, 4)
                         .background(Color.vehixOrange)
                         .cornerRadius(4)
                         .frame(maxWidth: .infinity, alignment: .leading)
                 }
            }
            .padding()
            .background(selectedPlan == plan ? Color.blue.opacity(0.1) : Color(.secondarySystemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedPlan == plan ? Color.blue : Color.clear, lineWidth: 2)
            )
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Selected Plan Details
    private var selectedPlanDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(selectedPlan.displayName) Plan Features")
                .font(.headline)
            
            ForEach(selectedPlan.features, id: \.self) { feature in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(feature)
                        .font(.subheadline)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Action Button Section
    private var actionButtonSection: some View {
        VStack(spacing: 12) {
            if storeKit.currentPlan == selectedPlan {
                Text("Current Plan")
                    .font(.headline)
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
            } else {
                Button(action: {
                    Task {
                        await purchaseSelectedPlan()
                    }
                }) {
                    HStack {
                        if storeKit.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Text(actionButtonText)
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                                         .background(Color.vehixBlue)
                     .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(storeKit.isLoading)
                
                if billingPeriod == .yearly {
                    Text("Save \(String(format: "%.0f", (selectedPlan.monthlyPrice * 12 - selectedPlan.yearlyPrice))) per year with annual billing")
                        .font(.caption)
                        .foregroundColor(.green)
                        .multilineTextAlignment(.center)
                }
            }
            
            // Restore Purchases Button
            Button("Restore Purchases") {
                Task {
                    await storeKit.restorePurchases()
                }
            }
            .font(.footnote)
            .foregroundColor(.blue)
        }
    }
    
    // MARK: - Terms Section
    private var termsSection: some View {
        VStack(spacing: 12) {
            Button(action: {
                showingTerms = true
            }) {
                Text("Terms & Conditions")
                    .font(.footnote)
                    .underline()
            }
            
            Text("Subscription automatically renews unless cancelled at least 24 hours before the end of the current period. You can manage and cancel your subscription in your Apple ID account settings.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom)
    }
    
    // MARK: - Helper Functions
    private func priceText(for plan: SubscriptionPlan) -> String {
        switch plan {
        case .trial:
            return "Free for 7 days"
        case .basic:
            return billingPeriod == .monthly ? "$125/month" : "$1,350/year"
        case .pro:
            return billingPeriod == .monthly ? "$385/month" : "$4,158/year"
        case .enterprise:
            return "$50/vehicle/month"
        }
    }
    
    private var actionButtonText: String {
        if storeKit.isInTrial {
            return "Continue with \(selectedPlan.displayName)"
        } else if selectedPlan.monthlyPrice > storeKit.currentPlan.monthlyPrice {
            return "Upgrade to \(selectedPlan.displayName)"
        } else {
            return "Switch to \(selectedPlan.displayName)"
        }
    }
    
    private func purchaseSelectedPlan() async {
        let productID: String
        switch selectedPlan {
        case .basic:
            productID = "com.lcoppers.Vehix.basic"
        case .pro:
            productID = "com.lcoppers.Vehix.pro"
        case .enterprise:
            productID = "com.lcoppers.Vehix.enterprise"
        case .trial:
            return // Should not happen
        }
        
        // Add yearly product ID suffix if yearly billing is selected
        let finalProductID = billingPeriod == .yearly ? "\(productID).yearly" : productID
        
        await storeKit.purchaseSubscription(productID: finalProductID)
    }
    
    // MARK: - Terms and Conditions View
    private var termsAndConditionsView: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Subscription Terms & Conditions")
                        .font(.title2.bold())
                        .padding(.bottom)
                    
                    Group {
                        termsSection(title: "Plan Comparison", content: """
                        • Basic ($125/month): 2 staff, 5 vehicles, 5 technicians, email support
                        • Pro ($385/month): 4 staff + 1 owner, 15 vehicles, 15 technicians, priority support, advanced analytics
                        • Enterprise ($50/vehicle/month): Unlimited staff, vehicles, technicians, direct developer contact, dedicated support
                        """)
                        
                        termsSection(title: "Free Trial", content: "7-day free trial includes access to all Basic plan features. No charges during trial period. Cancel anytime before trial ends to avoid charges.")
                        
                        termsSection(title: "Billing", content: "Subscriptions automatically renew unless cancelled 24+ hours before the current period ends. Annual plans offer 10% savings over monthly billing.")
                        
                        termsSection(title: "Cancellation", content: "Cancel anytime through your Apple ID account settings. Cancellation takes effect at the end of the current billing period.")
                        
                        termsSection(title: "Data Handling", content: "Cancelled subscriptions retain data for 90 days to allow reactivation. After 90 days, data is permanently deleted unless subscription is renewed.")
                        
                        termsSection(title: "Support", content: """
                        • Basic: Email support during business hours
                        • Pro: Priority email support with faster response times
                        • Enterprise: Direct developer contact with issues resolved within weeks, dedicated support team
                        """)
                    }
                }
                .padding()
            }
            .navigationTitle("Terms & Conditions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingTerms = false
                    }
                }
            }
        }
    }
    
    private func termsSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
            
            Divider()
                .padding(.top, 8)
        }
    }
}

#Preview {
    SubscriptionManagementView()
        .environmentObject(StoreKitManager())
} 