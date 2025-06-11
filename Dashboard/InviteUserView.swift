import SwiftUI
import SwiftData

struct InviteUserView: View {
    @EnvironmentObject var authService: AppAuthService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let businessAccount: BusinessAccount?
    let limitations: SubscriptionLimitations
    let onUserInvited: () -> Void
    
    @State private var fullName = ""
    @State private var email = ""
    @State private var selectedAccountType: AccountType = .technician
    @State private var selectedDepartments: Set<String> = []
    @State private var selectedLocations: Set<String> = []
    @State private var customPermissions: Set<Permission> = []
    @State private var isInviting = false
    @State private var inviteError: String?
    @State private var showingError = false
    
    private let departments = [
        "Service", "Sales", "Parts", "Administration", "Field Operations"
    ]
    
    private let locations = [
        "Main Office", "Service Center", "Remote"
    ]
    
    var currentUserAccount: UserAccount? {
        authService.getCurrentUserAccount()
    }
    
    var availableAccountTypes: [AccountType] {
        guard let currentUser = currentUserAccount else { return [] }
        return currentUser.accountType.canInviteAccountTypes.filter { canCreateUserOfType($0) }
    }
    
    var defaultPermissions: [Permission] {
        selectedAccountType.defaultPermissions
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Basic Information
                    basicInfoSection
                    
                    // Account Type Selection
                    accountTypeSection
                    
                    // Department Access (for managers)
                    if selectedAccountType == .manager {
                        departmentAccessSection
                    }
                    
                    // Location Access (if multi-location)
                    if businessAccount?.managementStructure == "Multiple Managers" {
                        locationAccessSection
                    }
                    
                    // Custom Permissions
                    permissionsSection
                    
                    // Limitations Notice
                    limitationsSection
                }
                .padding()
            }
            .navigationTitle("Invite Team Member")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Send Invite") {
                        sendInvite()
                    }
                    .disabled(!isFormValid || isInviting)
                }
            }
            .alert("Invite Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(inviteError ?? "Unknown error occurred")
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(Color.vehixBlue)
            
            VStack(spacing: 8) {
                Text("Invite New Team Member")
                    .font(.title2.bold())
                    .foregroundColor(Color.vehixText)
                
                Text("Add someone to your team and set their permissions")
                    .font(.subheadline)
                    .foregroundColor(Color.vehixSecondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(Color.vehixSecondaryBackground)
        .cornerRadius(16)
    }
    
    // MARK: - Basic Info Section
    
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Basic Information")
                .font(.headline)
                .foregroundColor(Color.vehixText)
            
            VStack(spacing: 12) {
                CustomTextField(
                    title: "Full Name",
                    text: $fullName,
                    placeholder: "Enter full name"
                )
                
                CustomTextField(
                    title: "Email Address",
                    text: $email,
                    placeholder: "user@company.com"
                )
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
            }
        }
        .padding()
        .background(Color.vehixSecondaryBackground)
        .cornerRadius(16)
    }
    
    // MARK: - Account Type Section
    
    private var accountTypeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Account Type")
                .font(.headline)
                .foregroundColor(Color.vehixText)
            
            VStack(spacing: 12) {
                ForEach(availableAccountTypes, id: \.self) { accountType in
                    AccountTypeSelectionCard(
                        accountType: accountType,
                        isSelected: selectedAccountType == accountType,
                        canCreate: canCreateUserOfType(accountType)
                    ) {
                        selectedAccountType = accountType
                        // Reset permissions when account type changes
                        customPermissions = Set(accountType.defaultPermissions)
                    }
                }
            }
        }
        .padding()
        .background(Color.vehixSecondaryBackground)
        .cornerRadius(16)
    }
    
    // MARK: - Department Access Section
    
    private var departmentAccessSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Department Access")
                .font(.headline)
                .foregroundColor(Color.vehixText)
            
            Text("Select which departments this manager can access")
                .font(.caption)
                .foregroundColor(Color.vehixSecondaryText)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(departments, id: \.self) { department in
                    DepartmentToggle(
                        department: department,
                        isSelected: selectedDepartments.contains(department)
                    ) {
                        if selectedDepartments.contains(department) {
                            selectedDepartments.remove(department)
                        } else {
                            selectedDepartments.insert(department)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.vehixSecondaryBackground)
        .cornerRadius(16)
    }
    
    // MARK: - Location Access Section
    
    private var locationAccessSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Location Access")
                .font(.headline)
                .foregroundColor(Color.vehixText)
            
            Text("Select which locations this user can access")
                .font(.caption)
                .foregroundColor(Color.vehixSecondaryText)
            
            VStack(spacing: 8) {
                ForEach(locations, id: \.self) { location in
                    LocationToggle(
                        location: location,
                        isSelected: selectedLocations.contains(location)
                    ) {
                        if selectedLocations.contains(location) {
                            selectedLocations.remove(location)
                        } else {
                            selectedLocations.insert(location)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.vehixSecondaryBackground)
        .cornerRadius(16)
    }
    
    // MARK: - Permissions Section
    
    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Permissions")
                .font(.headline)
                .foregroundColor(Color.vehixText)
            
            Text("Customize what this user can do in the app")
                .font(.caption)
                .foregroundColor(Color.vehixSecondaryText)
            
            PermissionsCategoryView(
                permissions: Array(customPermissions),
                onPermissionToggle: { permission in
                    if customPermissions.contains(permission) {
                        customPermissions.remove(permission)
                    } else {
                        customPermissions.insert(permission)
                    }
                }
            )
        }
        .padding()
        .background(Color.vehixSecondaryBackground)
        .cornerRadius(16)
    }
    
    // MARK: - Limitations Section
    
    private var limitationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Subscription Limitations")
                .font(.headline)
                .foregroundColor(Color.vehixText)
            
            VStack(spacing: 8) {
                InviteLimitationRow(
                    title: "Managers",
                    current: getCurrentUserCount(.manager),
                    maximum: limitations.maxManagers
                )
                
                InviteLimitationRow(
                    title: "Technicians",
                    current: getCurrentUserCount(.technician),
                    maximum: limitations.maxTechnicians
                )
            }
            
            if !limitations.canCreateManagers && selectedAccountType == .manager {
                Text("⚠️ Manager accounts require Pro or Enterprise plan")
                    .font(.caption)
                    .foregroundColor(Color.vehixOrange)
                    .padding(.top, 8)
            }
        }
        .padding()
        .background(Color.vehixSecondaryBackground)
        .cornerRadius(16)
    }
    
    // MARK: - Helper Methods
    
    private func canCreateUserOfType(_ accountType: AccountType) -> Bool {
        guard let _ = businessAccount else { return false }
        
        let currentCount = getCurrentUserCount(accountType)
        
        switch accountType {
        case .owner:
            return currentCount < 1
        case .manager:
            return limitations.canCreateManagers && currentCount < limitations.maxManagers
        case .technician:
            return currentCount < limitations.maxTechnicians
        }
    }
    
    private func getCurrentUserCount(_ accountType: AccountType) -> Int {
        guard let businessID = businessAccount?.businessID else { return 0 }
        
        do {
            let descriptor = FetchDescriptor<UserAccount>()
            let allUsers = try modelContext.fetch(descriptor)
            return allUsers.filter { 
                $0.businessAccount?.businessID == businessID && $0.accountType == accountType 
            }.count
        } catch {
            return 0
        }
    }
    
    private var isFormValid: Bool {
        !fullName.isEmpty && 
        !email.isEmpty && 
        email.contains("@") &&
        canCreateUserOfType(selectedAccountType)
    }
    
    private func sendInvite() {
        isInviting = true
        inviteError = nil
        
        Task {
            do {
                try await createUserAccount()
                
                await MainActor.run {
                    isInviting = false
                    onUserInvited()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isInviting = false
                    inviteError = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    private func createUserAccount() async throws {
        guard let businessAccount = businessAccount else {
            throw InviteError.noBusinessAccount
        }
        
        // Create password hash (in production, generate temporary password)
        let tempPassword = generateTemporaryPassword()
        let passwordHash = hashPassword(tempPassword)
        
        // Create user account
        let userAccount = UserAccount(
            fullName: fullName,
            email: email,
            passwordHash: passwordHash,
            accountType: selectedAccountType,
            permissions: Array(customPermissions),
            departmentAccess: Array(selectedDepartments),
            locationAccess: Array(selectedLocations)
        )
        
        // Set inviter
        userAccount.invitedBy = currentUserAccount?.userID
        userAccount.businessAccount = businessAccount
        
        // Create corresponding AuthUser
        let authUser = AuthUser(
            email: email,
            fullName: fullName,
            role: selectedAccountType == .owner ? .owner : 
                  selectedAccountType == .manager ? .admin : .technician,
            isVerified: false, // Require email verification
            isTwoFactorEnabled: true
        )
        authUser.businessAccountID = businessAccount.businessID
        
        // Insert into database
        modelContext.insert(userAccount)
        modelContext.insert(authUser)
        
        try modelContext.save()
        
        // In production, send invitation email with temporary password
        await sendInvitationEmail(to: email, tempPassword: tempPassword)
    }
    
    private func generateTemporaryPassword() -> String {
        // Generate secure temporary password
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%"
        return String((0..<12).map { _ in characters.randomElement()! })
    }
    
    private func hashPassword(_ password: String) -> String {
        // In production, use proper password hashing
        return password.data(using: .utf8)?.base64EncodedString() ?? ""
    }
    
    private func sendInvitationEmail(to email: String, tempPassword: String) async {
        // In production, integrate with email service
        print("📧 Invitation email sent to \(email) with temp password: \(tempPassword)")
    }
}

// MARK: - Supporting Views

struct AccountTypeSelectionCard: View {
    let accountType: AccountType
    let isSelected: Bool
    let canCreate: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: canCreate ? onTap : {}) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: accountType.systemImage)
                            .foregroundColor(canCreate ? Color.vehixBlue : Color.vehixSecondaryText)
                        
                        Text(accountType.rawValue)
                            .font(.headline)
                            .foregroundColor(canCreate ? Color.vehixText : Color.vehixSecondaryText)
                    }
                    
                    Text(accountType.description)
                        .font(.caption)
                        .foregroundColor(Color.vehixSecondaryText)
                }
                
                Spacer()
                
                if isSelected && canCreate {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color.vehixBlue)
                } else if !canCreate {
                    Image(systemName: "lock.circle")
                        .foregroundColor(Color.vehixSecondaryText)
                }
            }
            .padding()
            .background(isSelected && canCreate ? Color.vehixUIBlue.opacity(0.1) : Color.vehixBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected && canCreate ? Color.vehixBlue : .clear, lineWidth: 2)
            )
            .opacity(canCreate ? 1.0 : 0.6)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!canCreate)
    }
}

struct DepartmentToggle: View {
    let department: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(department)
                    .font(.subheadline)
                    .foregroundColor(Color.vehixText)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(Color.vehixBlue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.vehixUIBlue.opacity(0.1) : Color.vehixBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.vehixBlue : Color.vehixSecondaryText.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct LocationToggle: View {
    let location: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: "location")
                    .foregroundColor(Color.vehixBlue)
                
                Text(location)
                    .font(.subheadline)
                    .foregroundColor(Color.vehixText)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(Color.vehixBlue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.vehixUIBlue.opacity(0.1) : Color.vehixBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.vehixBlue : Color.vehixSecondaryText.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PermissionsCategoryView: View {
    let permissions: [Permission]
    let onPermissionToggle: (Permission) -> Void
    
    private var groupedPermissions: [PermissionCategory: [Permission]] {
        Dictionary(grouping: Permission.allCases) { $0.category }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ForEach(PermissionCategory.allCases, id: \.self) { category in
                PermissionCategorySection(
                    category: category,
                    categoryPermissions: groupedPermissions[category] ?? [],
                    selectedPermissions: permissions,
                    onToggle: onPermissionToggle
                )
            }
        }
    }
}

struct PermissionCategorySection: View {
    let category: PermissionCategory
    let categoryPermissions: [Permission]
    let selectedPermissions: [Permission]
    let onToggle: (Permission) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(category.rawValue)
                .font(.subheadline.bold())
                .foregroundColor(Color.vehixText)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 6) {
                ForEach(categoryPermissions, id: \.self) { permission in
                    PermissionToggle(
                        permission: permission,
                        isSelected: selectedPermissions.contains(permission),
                        onToggle: { onToggle(permission) }
                    )
                }
            }
        }
    }
}

struct PermissionToggle: View {
    let permission: Permission
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark.square.fill")
                        .foregroundColor(Color.vehixBlue)
                } else {
                    Image(systemName: "square")
                        .foregroundColor(Color.vehixSecondaryText)
                }
                
                Text(permission.displayName)
                    .font(.caption)
                    .foregroundColor(Color.vehixText)
                    .multilineTextAlignment(.leading)
                
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isSelected ? Color.vehixUIBlue.opacity(0.1) : .clear)
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct InviteLimitationRow: View {
    let title: String
    let current: Int
    let maximum: Int
    
    private var isAtLimit: Bool {
        current >= maximum
    }
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(Color.vehixText)
            
            Spacer()
            
            Text("\(current)/\(maximum == 999 ? "∞" : String(maximum))")
                .font(.subheadline.bold())
                .foregroundColor(isAtLimit ? Color.vehixOrange : Color.vehixText)
            
            if isAtLimit {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(Color.vehixOrange)
            }
        }
    }
}

// MARK: - Custom Text Field

struct CustomTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(Color.vehixText)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }
}

// MARK: - Errors

enum InviteError: Error, LocalizedError {
    case noBusinessAccount
    case subscriptionLimitReached
    case emailAlreadyExists
    case invalidEmail
    
    var errorDescription: String? {
        switch self {
        case .noBusinessAccount:
            return "No business account found"
        case .subscriptionLimitReached:
            return "Subscription limit reached for this account type"
        case .emailAlreadyExists:
            return "A user with this email already exists"
        case .invalidEmail:
            return "Please enter a valid email address"
        }
    }
}

#Preview {
    InviteUserView(
        businessAccount: nil,
        limitations: SubscriptionLimitations.limitations(for: .pro),
        onUserInvited: {}
    )
    .environmentObject(AppAuthService())
} 