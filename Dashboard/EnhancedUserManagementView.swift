import SwiftUI
import SwiftData

struct EnhancedUserManagementView: View {
    @EnvironmentObject var authService: AppAuthService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var users: [UserAccount] = []
    @State private var businessAccount: BusinessAccount?
    @State private var currentUser: UserAccount?
    @State private var isLoading = true
    @State private var showingInviteUser = false
    @State private var showingUserDetail: UserAccount?
    @State private var showingPermissionEditor: UserAccount?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView("Loading users...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    userManagementContent
                }
            }
            .navigationTitle("User Management")
            .navigationBarTitleDisplayMode(.large)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if canInviteUsers {
                        Button("Invite User") {
                            showingInviteUser = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            })
        }
        .sheet(isPresented: $showingInviteUser) {
            UserInvitationView(
                businessAccount: businessAccount,
                currentUserLimits: subscriptionLimits,
                onUserInvited: loadData
            )
            .environmentObject(authService)
        }
        .sheet(item: $showingUserDetail) { user in
            EnhancedUserDetailView(user: user, currentUser: currentUser)
                .environmentObject(authService)
        }
        .sheet(item: $showingPermissionEditor) { user in
            PermissionEditorView(
                user: user,
                currentUser: currentUser,
                onPermissionsUpdated: loadData
            )
        }
        .onAppear {
            loadData()
        }
    }
    
    private var userManagementContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                subscriptionOverviewSection
                usersByRoleSection
            }
            .padding()
        }
    }
    
    // MARK: - Subscription Overview Section
    
    private var subscriptionOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account Limits")
                .font(.headline.bold())
                .foregroundColor(Color.vehixBlue)
            
            HStack(spacing: 16) {
                UserLimitCard(
                    title: "Owners",
                    current: ownerCount,
                    limit: 1,
                    icon: "crown.fill",
                    color: Color.vehixBlue
                )
                
                UserLimitCard(
                    title: "Managers",
                    current: managerCount,
                    limit: subscriptionLimits.maxManagers,
                    icon: "person.badge.key.fill",
                    color: Color.vehixGreen
                )
                
                UserLimitCard(
                    title: "Technicians",
                    current: technicianCount,
                    limit: subscriptionLimits.maxTechnicians,
                    icon: "wrench.and.screwdriver.fill",
                    color: Color.vehixOrange
                )
            }
        }
        .padding()
        .background(Color.vehixSecondaryBackground)
        .cornerRadius(16)
    }
    
    // MARK: - Users by Role Section
    
    private var usersByRoleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Team Members")
                .font(.headline.bold())
                .foregroundColor(Color.vehixBlue)
            
            LazyVStack(spacing: 12) {
                // Owners
                if !owners.isEmpty {
                    UserRoleSection(
                        title: "Owners",
                        users: owners,
                        icon: "crown.fill",
                        color: Color.vehixBlue,
                        currentUser: currentUser,
                        onViewDetails: { showingUserDetail = $0 },
                        onEditPermissions: { showingPermissionEditor = $0 }
                    )
                }
                
                // Managers
                if !managers.isEmpty {
                    UserRoleSection(
                        title: "Managers",
                        users: managers,
                        icon: "person.badge.key.fill",
                        color: Color.vehixGreen,
                        currentUser: currentUser,
                        onViewDetails: { showingUserDetail = $0 },
                        onEditPermissions: { showingPermissionEditor = $0 }
                    )
                }
                
                // Technicians
                if !technicians.isEmpty {
                    UserRoleSection(
                        title: "Technicians",
                        users: technicians,
                        icon: "wrench.and.screwdriver.fill",
                        color: Color.vehixOrange,
                        currentUser: currentUser,
                        onViewDetails: { showingUserDetail = $0 },
                        onEditPermissions: { showingPermissionEditor = $0 }
                    )
                }
                
                if users.isEmpty {
                    EmptyUsersView()
                }
            }
        }
        .padding()
        .background(Color.vehixSecondaryBackground)
        .cornerRadius(16)
    }
    
    // MARK: - Computed Properties
    
    private var owners: [UserAccount] {
        users.filter { $0.accountType == .owner }
    }
    
    private var managers: [UserAccount] {
        users.filter { $0.accountType == .manager }
    }
    
    private var technicians: [UserAccount] {
        users.filter { $0.accountType == .technician }
    }
    
    private var ownerCount: Int { owners.count }
    private var managerCount: Int { managers.count }
    private var technicianCount: Int { technicians.count }
    
    private var subscriptionLimits: SubscriptionLimitations {
        // This should come from your StoreKit manager
        return SubscriptionLimitations.limitations(for: .pro) // Placeholder
    }
    
    private var canInviteUsers: Bool {
        guard let currentUser = currentUser else { return false }
        return currentUser.canInviteUsers() && 
               (users.count < subscriptionLimits.maxManagers + subscriptionLimits.maxTechnicians + 1)
    }
    
    // MARK: - Data Loading
    
    private func loadData() {
        isLoading = true
        
        Task {
            do {
                // Load users
                let userDescriptor = FetchDescriptor<UserAccount>()
                let loadedUsers = try modelContext.fetch(userDescriptor)
                
                // Load business account
                let businessDescriptor = FetchDescriptor<BusinessAccount>()
                let businessAccounts = try modelContext.fetch(businessDescriptor)
                
                // Find current user
                let currentUserAccount = loadedUsers.first { $0.email == authService.currentUser?.email }
                
                await MainActor.run {
                    self.users = loadedUsers
                    self.businessAccount = businessAccounts.first
                    self.currentUser = currentUserAccount
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    print("Error loading data: \(error)")
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - User Limit Card

struct UserLimitCard: View {
    let title: String
    let current: Int
    let limit: Int
    let icon: String
    let color: Color
    
    private var progress: Double {
        guard limit > 0 else { return 0 }
        return min(1.0, Double(current) / Double(limit))
    }
    
    private var progressColor: Color {
        if progress < 0.8 { return Color.vehixGreen }
        else if progress < 1.0 { return Color.vehixYellow }
        else { return Color.vehixOrange }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            VStack(spacing: 4) {
                Text("\(current)/\(limit == 999999 ? "∞" : "\(limit)")")
                    .font(.headline.bold())
                    .foregroundColor(Color.vehixText)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(Color.vehixSecondaryText)
                
                if limit != 999999 {
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: progressColor))
                        .scaleEffect(y: 0.5)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.vehixBackground)
        .cornerRadius(12)
    }
}

// MARK: - User Role Section

struct UserRoleSection: View {
    let title: String
    let users: [UserAccount]
    let icon: String
    let color: Color
    let currentUser: UserAccount?
    let onViewDetails: (UserAccount) -> Void
    let onEditPermissions: (UserAccount) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                
                Text("\(title) (\(users.count))")
                    .font(.subheadline.bold())
                    .foregroundColor(Color.vehixText)
                
                Spacer()
            }
            
            LazyVStack(spacing: 8) {
                ForEach(users, id: \.userID) { user in
                    UserRowView(
                        user: user,
                        isCurrentUser: user.userID == currentUser?.userID,
                        canEdit: canEditUser(user),
                        onViewDetails: { onViewDetails(user) },
                        onEditPermissions: { onEditPermissions(user) }
                    )
                }
            }
        }
        .padding()
        .background(Color.vehixBackground)
        .cornerRadius(12)
    }
    
    private func canEditUser(_ user: UserAccount) -> Bool {
        guard let currentUser = currentUser else { return false }
        
        // Owners can edit everyone except other owners
        if currentUser.accountType == .owner {
            return user.accountType != .owner || user.userID == currentUser.userID
        }
        
        // Managers can edit technicians and themselves
        if currentUser.accountType == .manager {
            return user.accountType == .technician || user.userID == currentUser.userID
        }
        
        // Technicians can only edit themselves
        return user.userID == currentUser.userID
    }
}

// MARK: - User Row View

struct UserRowView: View {
    let user: UserAccount
    let isCurrentUser: Bool
    let canEdit: Bool
    let onViewDetails: () -> Void
    let onEditPermissions: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(user.fullName)
                        .font(.body.bold())
                        .foregroundColor(Color.vehixText)
                    
                    if isCurrentUser {
                        Text("(You)")
                            .font(.caption)
                            .foregroundColor(Color.vehixBlue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.vehixBlue.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                Text(user.email)
                    .font(.caption)
                    .foregroundColor(Color.vehixSecondaryText)
                
                HStack {
                    StatusBadge(
                        text: user.isActive ? "Active" : "Inactive",
                        color: user.isActive ? Color.vehixGreen : Color.vehixOrange
                    )
                    
                    if let lastLogin = user.lastLoginAt {
                        Text("Last seen \(timeAgo(lastLogin))")
                            .font(.caption2)
                            .foregroundColor(Color.vehixSecondaryText)
                    }
                }
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                Button("Details") {
                    onViewDetails()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                if canEdit {
                    Button("Permissions") {
                        onEditPermissions()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .background(Color.vehixSecondaryBackground)
        .cornerRadius(12)
    }
    
    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Permission Editor View

struct PermissionEditorView: View {
    let user: UserAccount
    let currentUser: UserAccount?
    let onPermissionsUpdated: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var selectedPermissions: Set<Permission> = []
    @State private var isUpdating = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    userInfoSection
                    permissionCategoriesSection
                }
                .padding()
            }
            .navigationTitle("Edit Permissions")
            .navigationBarTitleDisplayMode(.large)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        updatePermissions()
                    }
                    .disabled(isUpdating)
                }
            })
        }
        .onAppear {
            selectedPermissions = Set(user.permissions)
        }
    }
    
    private var userInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("User Information")
                .font(.headline.bold())
                .foregroundColor(Color.vehixBlue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user.fullName)
                    .font(.title3.bold())
                    .foregroundColor(Color.vehixText)
                
                Text(user.email)
                    .font(.subheadline)
                    .foregroundColor(Color.vehixSecondaryText)
                
                Text("Role: \(user.accountType.rawValue)")
                    .font(.subheadline)
                    .foregroundColor(Color.vehixSecondaryText)
            }
        }
        .padding()
        .background(Color.vehixSecondaryBackground)
        .cornerRadius(16)
    }
    
    private var permissionCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Permissions")
                .font(.headline.bold())
                .foregroundColor(Color.vehixBlue)
            
            LazyVStack(spacing: 12) {
                ForEach(PermissionCategory.allCases, id: \.self) { category in
                    PermissionCategoryView(
                        category: category,
                        permissions: permissionsForCategory(category),
                        selectedPermissions: $selectedPermissions,
                        userAccountType: user.accountType
                    )
                }
            }
        }
        .padding()
        .background(Color.vehixSecondaryBackground)
        .cornerRadius(16)
    }
    
    private func permissionsForCategory(_ category: PermissionCategory) -> [Permission] {
        Permission.allCases.filter { $0.category == category }
    }
    
    private func updatePermissions() {
        isUpdating = true
        
        user.permissions = Array(selectedPermissions)
        
        do {
            try modelContext.save()
            onPermissionsUpdated()
            dismiss()
        } catch {
            print("Error updating permissions: \(error)")
        }
        
        isUpdating = false
    }
}

// MARK: - Permission Category View

struct PermissionCategoryView: View {
    let category: PermissionCategory
    let permissions: [Permission]
    @Binding var selectedPermissions: Set<Permission>
    let userAccountType: AccountType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(category.rawValue)
                .font(.subheadline.bold())
                .foregroundColor(Color.vehixText)
            
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(permissions, id: \.self) { permission in
                    PermissionToggleView(
                        permission: permission,
                        isSelected: selectedPermissions.contains(permission),
                        isEnabled: isPermissionAllowed(permission),
                        onToggle: { isSelected in
                            if isSelected {
                                selectedPermissions.insert(permission)
                            } else {
                                selectedPermissions.remove(permission)
                            }
                        }
                    )
                }
            }
        }
        .padding()
        .background(Color.vehixBackground)
        .cornerRadius(12)
    }
    
    private func isPermissionAllowed(_ permission: Permission) -> Bool {
        // Check if this permission is allowed for the user's account type
        return userAccountType.defaultPermissions.contains(permission) || 
               userAccountType == .owner || 
               (userAccountType == .manager && permission != .manageSubscription)
    }
}

// MARK: - Permission Toggle View

struct PermissionToggleView: View {
    let permission: Permission
    let isSelected: Bool
    let isEnabled: Bool
    let onToggle: (Bool) -> Void
    
    var body: some View {
        HStack {
            Button(action: {
                if isEnabled {
                    onToggle(!isSelected)
                }
            }) {
                HStack {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .foregroundColor(isSelected ? Color.vehixGreen : Color.vehixSecondaryText)
                    
                    Text(permission.displayName)
                        .font(.body)
                        .foregroundColor(isEnabled ? Color.vehixText : Color.vehixSecondaryText)
                    
                    Spacer()
                }
            }
            .disabled(!isEnabled)
        }
        .opacity(isEnabled ? 1.0 : 0.6)
    }
}

// MARK: - User Detail View

struct EnhancedUserDetailView: View {
    let user: UserAccount
    let currentUser: UserAccount?
    @EnvironmentObject var authService: AppAuthService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    profileSection
                    permissionsSection
                    accessSection
                }
                .padding()
            }
            .navigationTitle("User Details")
            .navigationBarTitleDisplayMode(.large)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            })
        }
    }
    
    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Profile Information")
                .font(.headline.bold())
                .foregroundColor(Color.vehixBlue)
            
            VStack(spacing: 8) {
                DetailRow(label: "Full Name", value: user.fullName)
                DetailRow(label: "Email", value: user.email)
                DetailRow(label: "Account Type", value: user.accountType.rawValue)
                DetailRow(label: "Status", value: user.isActive ? "Active" : "Inactive")
                
                if let lastLogin = user.lastLoginAt {
                    DetailRow(label: "Last Login", value: formatDate(lastLogin))
                }
                
                DetailRow(label: "Created", value: formatDate(user.createdAt))
                
                if let invitedBy = user.invitedBy {
                    DetailRow(label: "Invited By", value: "User ID: \(invitedBy)")
                }
            }
        }
        .padding()
        .background(Color.vehixSecondaryBackground)
        .cornerRadius(16)
    }
    
    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Permissions")
                .font(.headline.bold())
                .foregroundColor(Color.vehixBlue)
            
            if user.permissions.isEmpty {
                Text("Using default \(user.accountType.rawValue.lowercased()) permissions")
                    .font(.body)
                    .foregroundColor(Color.vehixSecondaryText)
                    .padding()
            } else {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(user.permissions, id: \.self) { permission in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color.vehixGreen)
                                .font(.caption)
                            
                            Text(permission.displayName)
                                .font(.body)
                                .foregroundColor(Color.vehixText)
                        }
                    }
                }
                .padding()
            }
        }
        .padding()
        .background(Color.vehixSecondaryBackground)
        .cornerRadius(16)
    }
    
    private var accessSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Access Control")
                .font(.headline.bold())
                .foregroundColor(Color.vehixBlue)
            
            VStack(spacing: 8) {
                if !user.departmentAccess.isEmpty {
                    DetailRow(label: "Department Access", value: user.departmentAccess.joined(separator: ", "))
                }
                
                if !user.locationAccess.isEmpty {
                    DetailRow(label: "Location Access", value: user.locationAccess.joined(separator: ", "))
                }
                
                if user.departmentAccess.isEmpty && user.locationAccess.isEmpty {
                    Text("Full access to all departments and locations")
                        .font(.body)
                        .foregroundColor(Color.vehixSecondaryText)
                        .padding()
                }
            }
        }
        .padding()
        .background(Color.vehixSecondaryBackground)
        .cornerRadius(16)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - User Invitation View

struct UserInvitationView: View {
    let businessAccount: BusinessAccount?
    let currentUserLimits: SubscriptionLimitations
    let onUserInvited: () -> Void
    
    @EnvironmentObject var authService: AppAuthService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var fullName: String = ""
    @State private var email: String = ""
    @State private var selectedAccountType: AccountType = .technician
    @State private var isInviting = false
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Full Name", text: $fullName)
                    TextField("Email Address", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    Picker("Account Type", selection: $selectedAccountType) {
                        ForEach(availableAccountTypes, id: \.self) { accountType in
                            Text(accountType.rawValue).tag(accountType)
                        }
                    }
                } header: {
                    Text("User Information")
                } footer: {
                    Text("The user will receive an email invitation to join your team.")
                }
                
                Section {
                    Text(selectedAccountType.description)
                        .font(.body)
                        .foregroundColor(Color.vehixSecondaryText)
                } header: {
                    Text("Role Description")
                }
            }
            .navigationTitle("Invite User")
            .navigationBarTitleDisplayMode(.large)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Send Invitation") {
                        inviteUser()
                    }
                    .disabled(!isFormValid || isInviting)
                }
            })
        }
    }
    
    private var availableAccountTypes: [AccountType] {
        // Only show account types that the current user can invite
        guard authService.currentUser != nil else { return [] }
        
        // This would be based on the current user's permissions
        return [.manager, .technician] // Simplified for now
    }
    
    private var isFormValid: Bool {
        !fullName.isEmpty && !email.isEmpty && email.contains("@")
    }
    
    private func inviteUser() {
        isInviting = true
        
        // Create new user account
        let newUser = UserAccount(
            fullName: fullName,
            email: email,
            passwordHash: "", // Will be set when user accepts invitation
            accountType: selectedAccountType,
            permissions: selectedAccountType.defaultPermissions
        )
        
        // Set business relationship
        newUser.businessAccount = businessAccount
        
        modelContext.insert(newUser)
        
        do {
            try modelContext.save()
            
            // Here you would send the actual email invitation
            // For now, we'll just complete the process
            
            onUserInvited()
            dismiss()
        } catch {
            print("Error inviting user: \(error)")
        }
        
        isInviting = false
    }
}

// MARK: - Empty Users View

struct EmptyUsersView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.slash")
                .font(.system(size: 60))
                .foregroundColor(Color.vehixSecondaryText)
            
            Text("No Team Members")
                .font(.title2.bold())
                .foregroundColor(Color.vehixText)
            
            Text("Invite team members to collaborate on vehicle management and maintenance tasks.")
                .font(.body)
                .foregroundColor(Color.vehixSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

#Preview {
    EnhancedUserManagementView()
        .environmentObject(AppAuthService())
} 