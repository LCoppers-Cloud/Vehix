import SwiftUI
import SwiftData

struct BusinessAccountManagementView: View {
    @EnvironmentObject var authService: AppAuthService
    @EnvironmentObject var storeKit: StoreKitManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var businessAccount: BusinessAccount?
    @State private var currentUserAccount: UserAccount?
    @State private var allUsers: [UserAccount] = []
    @State private var showingInviteUser = false
    @State private var showingSubscriptionManagement = false
    @State private var showingUserDetail: UserAccount? = nil
    @State private var isLoading = true
    
    var subscriptionLimitations: SubscriptionLimitations {
        SubscriptionLimitations.limitations(for: storeKit.currentPlan)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    if let businessAccount = businessAccount {
                        // Business Overview
                        businessOverviewSection(businessAccount)
                        
                        // Team Management
                        teamManagementSection
                        
                        // Subscription Information
                        subscriptionSection(businessAccount)
                        
                        // Account Hierarchy
                        accountHierarchySection
                    } else if isLoading {
                        ProgressView("Loading business account...")
                    } else {
                        Text("No business account found")
                            .foregroundColor(Color.vehixSecondaryText)
                    }
                }
                .padding()
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
        .sheet(isPresented: $showingInviteUser) {
            InviteUserView(
                businessAccount: businessAccount,
                limitations: subscriptionLimitations,
                onUserInvited: loadBusinessData
            )
            .environmentObject(authService)
        }
        .sheet(isPresented: $showingSubscriptionManagement) {
            SubscriptionManagementView()
                .environmentObject(storeKit)
        }
        .sheet(item: $showingUserDetail) { user in
            UserDetailManagementView(userAccount: user) {
                loadBusinessData()
            }
            .environmentObject(authService)
        }
        .onAppear {
            loadBusinessData()
        }
    }
    
    // MARK: - Business Overview Section
    
    private func businessOverviewSection(_ business: BusinessAccount) -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "building.2")
                    .font(.title2)
                    .foregroundColor(Color.vehixBlue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(business.businessName)
                        .font(.title2.bold())
                        .foregroundColor(Color.vehixText)
                    
                    Text("\(business.businessType) • \(business.fleetSize)")
                        .font(.subheadline)
                        .foregroundColor(Color.vehixSecondaryText)
                }
                
                Spacer()
            }
            
            HStack {
                InfoPill(
                    icon: "person.3",
                    title: "Team Size",
                    value: "\(allUsers.count) users"
                )
                
                Spacer()
                
                InfoPill(
                    icon: "car.2",
                    title: "Fleet Capacity",
                    value: "\(business.maxVehicles) vehicles"
                )
            }
        }
        .padding()
        .background(Color.vehixSecondaryBackground)
        .cornerRadius(16)
    }
    
    // MARK: - Team Management Section
    
    private var teamManagementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Team Management")
                    .font(.title3.bold())
                    .foregroundColor(Color.vehixText)
                
                Spacer()
                
                if canInviteUsers {
                    Button("Invite User") {
                        showingInviteUser = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            
            LazyVStack(spacing: 12) {
                ForEach(groupedUsers.keys.sorted(by: { accountTypePriority($0) < accountTypePriority($1) }), id: \.self) { accountType in
                    AccountTypeSection(
                        accountType: accountType,
                        users: groupedUsers[accountType] ?? [],
                        limitations: subscriptionLimitations,
                        currentUser: currentUserAccount
                    ) { user in
                        showingUserDetail = user
                    }
                }
            }
        }
        .padding()
        .background(Color.vehixSecondaryBackground)
        .cornerRadius(16)
    }
    
    private var groupedUsers: [AccountType: [UserAccount]] {
        Dictionary(grouping: allUsers) { $0.accountType }
    }
    
    private func accountTypePriority(_ type: AccountType) -> Int {
        switch type {
        case .owner: return 0
        case .manager: return 1
        case .technician: return 2
        }
    }
    
    private var canInviteUsers: Bool {
        guard let currentUser = currentUserAccount else { return false }
        return currentUser.canInviteUsers() && 
               (allUsers.count < subscriptionLimitations.maxManagers + subscriptionLimitations.maxTechnicians)
    }
    
    // MARK: - Subscription Section
    
    private func subscriptionSection(_ business: BusinessAccount) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Subscription Plan")
                    .font(.title3.bold())
                    .foregroundColor(Color.vehixText)
                
                Spacer()
                
                if currentUserAccount?.canManageSubscription() == true {
                    Button("Manage Plan") {
                        showingSubscriptionManagement = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(business.subscriptionPlan)
                            .font(.headline)
                            .foregroundColor(Color.vehixText)
                        
                        Text(business.billingPeriod)
                            .font(.subheadline)
                            .foregroundColor(Color.vehixSecondaryText)
                    }
                    
                    Spacer()
                    
                    if business.subscriptionPlan != "Enterprise" {
                        Text("$\(Int(getCurrentPlanPrice()))/month")
                            .font(.title3.bold())
                            .foregroundColor(Color.vehixBlue)
                    } else {
                        Text("$50/vehicle")
                            .font(.title3.bold())
                            .foregroundColor(Color.vehixBlue)
                    }
                }
                
                SubscriptionLimitationsBadges(limitations: subscriptionLimitations)
            }
        }
        .padding()
        .background(Color.vehixSecondaryBackground)
        .cornerRadius(16)
    }
    
    private func getCurrentPlanPrice() -> Double {
        switch storeKit.currentPlan {
        case .basic: return 125
        case .pro: return 385
        case .enterprise: return 50
        case .trial: return 0
        }
    }
    
    // MARK: - Account Hierarchy Section
    
    private var accountHierarchySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Account Hierarchy")
                .font(.title3.bold())
                .foregroundColor(Color.vehixText)
            
            VStack(spacing: 8) {
                ForEach(allUsers.sorted(by: { accountTypePriority($0.accountType) < accountTypePriority($1.accountType) }), id: \.userID) { user in
                    UserHierarchyRow(
                        user: user,
                        isCurrentUser: user.userID == currentUserAccount?.userID
                    ) {
                        showingUserDetail = user
                    }
                }
            }
        }
        .padding()
        .background(Color.vehixSecondaryBackground)
        .cornerRadius(16)
    }
    
    // MARK: - Helper Methods
    
    private func loadBusinessData() {
        isLoading = true
        
        DispatchQueue.main.async {
            self.businessAccount = authService.getCurrentBusinessAccount()
            self.currentUserAccount = authService.getCurrentUserAccount()
            
            if let businessID = self.businessAccount?.businessID {
                do {
                    let descriptor = FetchDescriptor<UserAccount>()
                    let allAccounts = try modelContext.fetch(descriptor)
                    self.allUsers = allAccounts.filter { $0.businessAccount?.businessID == businessID }
                } catch {
                    print("Error loading user accounts: \(error)")
                }
            }
            
            self.isLoading = false
        }
    }
}

// MARK: - Supporting Views

struct InfoPill: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(Color.vehixBlue)
                Text(title)
                    .font(.caption)
                    .foregroundColor(Color.vehixSecondaryText)
            }
            
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(Color.vehixText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.vehixBackground)
        .cornerRadius(8)
    }
}

struct AccountTypeSection: View {
    let accountType: AccountType
    let users: [UserAccount]
    let limitations: SubscriptionLimitations
    let currentUser: UserAccount?
    let onUserTap: (UserAccount) -> Void
    
    private var maxUsersForType: Int {
        switch accountType {
        case .owner: return 1
        case .manager: return limitations.maxManagers
        case .technician: return limitations.maxTechnicians
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(accountType.rawValue + "s")
                    .font(.headline)
                    .foregroundColor(Color.vehixText)
                
                Spacer()
                
                Text("\(users.count)/\(maxUsersForType)")
                    .font(.caption)
                    .foregroundColor(Color.vehixSecondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.vehixBackground)
                    .cornerRadius(4)
            }
            
            if users.isEmpty {
                Text("No \(accountType.rawValue.lowercased())s yet")
                    .font(.caption)
                    .foregroundColor(Color.vehixSecondaryText)
                    .italic()
            } else {
                ForEach(users, id: \.userID) { user in
                    BusinessUserRow(
                        user: user,
                        isCurrentUser: user.userID == currentUser?.userID,
                        onTap: { onUserTap(user) }
                    )
                }
            }
        }
    }
}

struct BusinessUserRow: View {
    let user: UserAccount
    let isCurrentUser: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(user.fullName)
                            .font(.subheadline.bold())
                            .foregroundColor(Color.vehixText)
                        
                        if isCurrentUser {
                            Text("(You)")
                                .font(.caption)
                                .foregroundColor(Color.vehixBlue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.vehixUIBlue.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(user.email)
                        .font(.caption)
                        .foregroundColor(Color.vehixSecondaryText)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Circle()
                        .fill(user.isActive ? Color.vehixGreen : Color.vehixSecondaryText)
                        .frame(width: 8, height: 8)
                    
                    if let lastLogin = user.lastLoginAt {
                        Text(lastLogin, style: .relative)
                            .font(.caption2)
                            .foregroundColor(Color.vehixSecondaryText)
                    }
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Color.vehixSecondaryText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.vehixBackground)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct UserHierarchyRow: View {
    let user: UserAccount
    let isCurrentUser: Bool
    let onTap: () -> Void
    
    private var indentLevel: Int {
        switch user.accountType {
        case .owner: return 0
        case .manager: return 1
        case .technician: return 2
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                // Indent based on hierarchy
                Rectangle()
                    .fill(.clear)
                    .frame(width: CGFloat(indentLevel * 20))
                
                // Hierarchy indicator
                if indentLevel > 0 {
                    Rectangle()
                        .fill(Color.vehixSecondaryText.opacity(0.3))
                        .frame(width: 2, height: 20)
                    
                    Rectangle()
                        .fill(Color.vehixSecondaryText.opacity(0.3))
                        .frame(width: 10, height: 2)
                }
                
                // Account type icon
                Image(systemName: user.accountType.systemImage)
                    .font(.caption)
                    .foregroundColor(Color.vehixBlue)
                    .frame(width: 16)
                
                // User info
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(user.fullName)
                            .font(.subheadline)
                            .foregroundColor(Color.vehixText)
                        
                        if isCurrentUser {
                            Text("(You)")
                                .font(.caption2)
                                .foregroundColor(Color.vehixBlue)
                        }
                    }
                    
                    Text(user.accountType.rawValue)
                        .font(.caption)
                        .foregroundColor(Color.vehixSecondaryText)
                }
                
                Spacer()
                
                // Status indicator
                Circle()
                    .fill(user.isActive ? Color.vehixGreen : Color.vehixSecondaryText)
                    .frame(width: 6, height: 6)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SubscriptionLimitationsBadges: View {
    let limitations: SubscriptionLimitations
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 8) {
            LimitationBadge(
                icon: "car.2",
                label: "Vehicles",
                value: limitations.maxVehicles == 999 ? "Unlimited" : "\(limitations.maxVehicles)"
            )
            
            LimitationBadge(
                icon: "person.3",
                label: "Managers",
                value: limitations.maxManagers == 999 ? "Unlimited" : "\(limitations.maxManagers)"
            )
            
            LimitationBadge(
                icon: "wrench.and.screwdriver",
                label: "Technicians",
                value: limitations.maxTechnicians == 999 ? "Unlimited" : "\(limitations.maxTechnicians)"
            )
        }
    }
}

struct LimitationBadge: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(Color.vehixBlue)
            
            Text(value)
                .font(.caption.bold())
                .foregroundColor(Color.vehixText)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(Color.vehixSecondaryText)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.vehixBackground)
        .cornerRadius(6)
    }
}

// MARK: - Extensions

extension AccountType {
    var systemImage: String {
        switch self {
        case .owner: return "crown"
        case .manager: return "person.badge.key"
        case .technician: return "wrench.and.screwdriver"
        }
    }
}

#Preview {
    BusinessAccountManagementView()
        .environmentObject(AppAuthService())
        .environmentObject(StoreKitManager())
} 