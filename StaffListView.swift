import SwiftUI
import SwiftData
import MessageUI

struct StaffListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authService: AppAuthService
    @EnvironmentObject var storeKitManager: StoreKitManager
    @Query private var users: [AuthUser]
    @Query private var vehicleAssignments: [VehicleAssignment]

    @State private var showingInviteSheet = false
    @State private var showUpgradePrompt = false
    @State private var searchText = ""
    @State private var editingUser: AuthUser?
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false
    @State private var userToDelete: AuthUser?
    @State private var showGPSLiabilityAlert = false
    @State private var userForGPS: AuthUser?
    @State private var showPasswordResetAlert = false
    @State private var userForPasswordReset: AuthUser?
    @State private var isEditing = false

    var filteredUsers: [AuthUser] {
        if searchText.isEmpty {
            return users
        } else {
            return users.filter { $0.fullName?.localizedCaseInsensitiveContains(searchText) == true || $0.email.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search staff", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
                .padding(.top)
                .padding(.bottom, 10)

                // Main content area
                ZStack {
                    if users.isEmpty {
                        emptyStateView
                    } else if filteredUsers.isEmpty {
                        noResultsView
                    } else {
                        staffListScrollView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Stats bar at bottom
                statsBar
            }
            .navigationTitle("Staff Management")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        if storeKitManager.staffRemaining > 0 {
                            showingInviteSheet = true
                        } else {
                            showUpgradePrompt = true
                        }
                    }) {
                        Label("Add Staff", systemImage: "person.badge.plus")
                    }
                    .disabled(storeKitManager.staffRemaining == 0)
                }
                
                // Edit button when staff exist
                if !users.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(isEditing ? "Done" : "Edit") {
                            isEditing.toggle()
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search staff")
            .sheet(isPresented: $showingInviteSheet) {
                InviteStaffView(onInvite: { /* handle invite */ })
            }
            .sheet(item: $editingUser) { user in
                EditStaffProfileView(user: user)
            }
            .alert("Delete Staff Member?", isPresented: $showDeleteAlert, presenting: userToDelete) { user in
                Button("Delete", role: .destructive) {
                    deleteUser(user)
                }
                Button("Cancel", role: .cancel) {}
            } message: { user in
                Text("Are you sure you want to delete \(user.fullName ?? user.email)? This cannot be undone.")
            }
            .alert("Reset Password", isPresented: $showPasswordResetAlert, presenting: userForPasswordReset) { user in
                Button("Send Reset Link", role: .destructive) {
                    resetPassword(for: user)
                }
                Button("Cancel", role: .cancel) {}
            } message: { user in
                Text("Send a password reset link to \(user.email)?")
            }
            .alert("GPS Location Tracking", isPresented: $showGPSLiabilityAlert, presenting: userForGPS) { user in
                Button("Enable GPS Tracking", role: .destructive) {
                    enableGPSTracking(for: user)
                }
                Button("Cancel", role: .cancel) {}
            } message: { user in
                VStack(alignment: .leading, spacing: 10) {
                    Text("IMPORTANT: Legal & Privacy Notice")
                        .font(.headline)
                    
                    Text("By enabling GPS tracking for \(user.fullName ?? user.email), you confirm:")
                    
                    Text("1. This is a company-owned device")
                    Text("2. Your company policy allows location tracking")
                    Text("3. Staff has been informed of tracking")
                    Text("4. You accept all legal responsibility for compliance with applicable privacy and labor laws")
                    
                    Text("GPS tracking will function even when the app is not running.")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .alert(isPresented: $showUpgradePrompt) {
                Alert(
                    title: Text("Upgrade Required"),
                    message: Text("You've reached your plan's staff limit (\(storeKitManager.staffLimit)). Upgrade your subscription to invite more staff."),
                    primaryButton: .default(Text("Upgrade Now"), action: {
                        // Open subscription management
                    }),
                    secondaryButton: .cancel(Text("Cancel"))
                )
            }
        }
    }

    // Staff list with card-based UI
    private var staffListScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredUsers) { user in
                    StaffCardView(
                        user: user,
                        currentAssignment: getCurrentVehicleAssignment(for: user),
                        isEditing: isEditing,
                        onEdit: { editingUser = user },
                        onDelete: { userToDelete = user; showDeleteAlert = true },
                        onResetPassword: { userForPasswordReset = user; showPasswordResetAlert = true },
                        onToggleGPS: { userForGPS = user; showGPSLiabilityAlert = true }
                    )
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 2)
                    .padding(.horizontal, 12)
                }
            }
            .padding(.vertical, 12)
            .animation(.default, value: filteredUsers.count)
        }
        .background(Color(.systemGroupedBackground))
    }

    // Empty state
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "person.2.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.7))
            
            Text("No staff members yet")
                .font(.title2)
                .bold()
            
            Text("Invite your first staff member to get started")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
            
            Button(action: {
                if storeKitManager.staffRemaining > 0 {
                    showingInviteSheet = true
                } else {
                    showUpgradePrompt = true
                }
            }) {
                Text("Invite your first staff member to get started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100) // Make space for the stats bar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // No results state
    private var noResultsView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.7))
                
            Text("No matching staff found")
                .font(.title2)
                .bold()
                
            Text("Try adjusting your search.")
                .foregroundColor(.secondary)
                
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // Stats bar at bottom
    private var statsBar: some View {
        VStack(spacing: 0) {
            // Staff counter and invitation info
            HStack {
                VStack(alignment: .leading) {
                    Text("\(users.count) Staff Members")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("You can invite \(storeKitManager.staffRemaining) more")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.leading)
                
                Spacer()
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            
            // Role quotas
            HStack(spacing: 0) {
                roleQuotaBox(
                    title: "Admin", 
                    count: users.filter { $0.userRole == .admin }.count,
                    limit: 1
                )
                
                Divider()
                    .background(Color.white.opacity(0.3))
                    .frame(height: 30)
                
                roleQuotaBox(
                    title: "Managers", 
                    count: users.filter { $0.userRole == .dealer }.count,
                    limit: 2
                )
                
                Divider()
                    .background(Color.white.opacity(0.3))
                    .frame(height: 30)
                
                roleQuotaBox(
                    title: "Technicians", 
                    count: users.filter { $0.userRole == .technician }.count,
                    limit: storeKitManager.staffLimit - 3
                )
            }
            .frame(maxWidth: .infinity)
            .background(Color.gray.opacity(0.2))
        }
    }
    
    // Helper view for role quota display
    private func roleQuotaBox(title: String, count: Int, limit: Int) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .fontWeight(.medium)
            
            HStack(spacing: 2) {
                Text("\(count)")
                    .foregroundColor(count >= limit ? .red : .green)
                    .fontWeight(.bold)
                
                Text("/\(limit)")
                    .foregroundColor(.secondary)
            }
            .font(.callout)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
    
    // Get current vehicle assignment for a user
    private func getCurrentVehicleAssignment(for user: AuthUser) -> VehicleAssignment? {
        let now = Date()
        
        // Find the current assignment (where endDate is nil or in the future)
        return vehicleAssignments.first { assignment in
            assignment.userId == user.id &&
            assignment.startDate <= now &&
            (assignment.endDate == nil || assignment.endDate! > now)
        }
    }

    // Helper functions
    private func deleteUser(_ user: AuthUser) {
        // Remove user from model context
        modelContext.delete(user)
        try? modelContext.save()
        userToDelete = nil
    }
    
    private func resetPassword(for user: AuthUser) {
        // In a real app, you would send a reset link to the user's email
        print("Sent password reset link to \(user.email)")
        userForPasswordReset = nil
    }
    
    private func enableGPSTracking(for user: AuthUser) {
        // In a real app, you would update the user's settings to enable GPS tracking
        print("Enabled GPS tracking for \(user.fullName ?? user.email)")
        userForGPS = nil
    }
}

// Staff card component for better visual representation
struct StaffCardView: View {
    let user: AuthUser
    let currentAssignment: VehicleAssignment?
    let isEditing: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onResetPassword: () -> Void
    let onToggleGPS: () -> Void
    
    @State private var isGPSEnabled: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with name, role, and actions
            HStack(alignment: .top) {
                // Avatar/Icon
                ZStack {
                    Circle()
                        .fill(roleColor.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Text(initials)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(roleColor)
                }
                
                // Name and details
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.fullName ?? "Unnamed User")
                        .font(.headline)
                    
                    Text(user.email)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    
                    Text(roleTitle)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(roleColor.opacity(0.2))
                        .foregroundColor(roleColor)
                        .cornerRadius(4)
                    
                    if user.isDeactivated {
                        Text("Deactivated")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                // Edit button
                if !isEditing {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .foregroundColor(.blue)
                            .padding(8)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Circle())
                    }
                } else {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .padding(8)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            
            // Vehicle assignment info
            if let assignment = currentAssignment, let vehicle = assignment.vehicle {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Assigned Vehicle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: "car.fill")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text(vehicle.displayName)
                                .font(.subheadline)
                            
                            if let plate = vehicle.licensePlate, !plate.isEmpty {
                                Text(plate)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Text("Since \(assignment.startDate.formatted(.dateTime.month().day().year()))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 12)
            } else if user.userRole == .technician {
                HStack {
                    Image(systemName: "car.fill")
                        .foregroundColor(.gray)
                    
                    Text("No vehicle assigned")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    NavigationLink(destination: StaffDetailView(staffMember: user)) {
                        Text("Assign")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 12)
            }
            
            // Actions
            if !isEditing {
                HStack(spacing: 12) {
                    Divider()
                        .frame(height: 24)
                    
                    Spacer()
                    
                    Button(action: onResetPassword) {
                        HStack {
                            Image(systemName: "key.fill")
                            Text("Reset Password")
                        }
                        .font(.caption)
                    }
                    
                    Divider()
                        .frame(height: 24)
                    
                    // Only show GPS toggle for technicians
                    if user.userRole == .technician {
                        Button(action: onToggleGPS) {
                            HStack {
                                Image(systemName: isGPSEnabled ? "location.fill" : "location.slash.fill")
                                Text(isGPSEnabled ? "GPS Enabled" : "GPS Disabled")
                            }
                            .font(.caption)
                            .foregroundColor(isGPSEnabled ? .green : .orange)
                        }
                    }
                    
                    Spacer()
                    
                    Divider()
                        .frame(height: 24)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
            }
        }
        .onAppear {
            // In a real app, fetch the GPS status from the user model
            isGPSEnabled = Bool.random() // Placeholder for demo
        }
    }
    
    private var initials: String {
        if let name = user.fullName, !name.isEmpty {
            let components = name.components(separatedBy: " ")
            if components.count > 1, let first = components.first?.prefix(1), let last = components.last?.prefix(1) {
                return "\(first)\(last)".uppercased()
            } else if let first = components.first?.prefix(1) {
                return "\(first)".uppercased()
            }
        }
        return "?"
    }
    
    private var roleColor: Color {
        switch user.userRole {
        case .admin: return .purple
        case .dealer: return .blue
        case .technician: return .green
        default: return .gray
        }
    }
    
    private var roleTitle: String {
        switch user.userRole {
        case .admin: return "Administrator"
        case .dealer: return "Inventory Manager"
        case .technician: return "Technician"
        default: return user.userRole.rawValue.capitalized
        }
    }
}

// SMS Invite logic using MessageUI
struct InviteStaffView: View {
    var onInvite: () -> Void
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var storeKitManager: StoreKitManager
    @EnvironmentObject var authService: AppAuthService
    
    @State private var email: String = ""
    @State private var fullName: String = ""
    @State private var phoneNumber: String = ""
    @State private var role: UserRole = .technician
    @State private var isInviting = false
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showRoleLimitWarning = false
    
    // Query to count roles for quota enforcement
    @Query private var allUsers: [AuthUser]
    
    // Calculate role counts for quota management
    private var adminCount: Int {
        allUsers.filter { $0.userRole == .admin }.count
    }
    
    private var dealerCount: Int {
        allUsers.filter { $0.userRole == .dealer }.count
    }
    
    // Check if role change exceeds quota
    private func willExceedQuota(_ newRole: UserRole) -> Bool {
        switch newRole {
        case .admin:
            // Only 1 admin allowed
            return adminCount >= 1
        case .dealer:
            // Only 2 inventory managers (dealers) allowed
            return dealerCount >= 2
        default:
            // No limit on technicians beyond subscription
            return false
        }
    }
    
    // Get role description for UI
    private func roleDescription(_ role: UserRole) -> String {
        switch role {
        case .admin: 
            return "Full access to all features and user management"
        case .dealer: 
            return "Can manage inventory, warehouses, and transfer items"
        case .technician: 
            return "Can view inventory and use assigned items"
        default: 
            return ""
        }
    }
    
    // Get remaining slots for a role
    private func remainingSlotsForRole(_ role: UserRole) -> Int {
        switch role {
        case .admin: return max(0, 1 - adminCount)
        case .dealer: return max(0, 2 - dealerCount)
        case .technician: return max(0, storeKitManager.staffLimit - storeKitManager.currentStaffCount)
        default: return 0
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("New Staff Member")) {
                    TextField("Full Name", text: $fullName)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                }
                
                Section(header: Text("Role Assignment")) {
                    Picker("Role", selection: $role) {
                        if authService.currentUser?.userRole == .admin {
                            Text("Admin (\(adminCount)/1)").tag(UserRole.admin)
                                .disabled(willExceedQuota(.admin))
                            
                            Text("Inventory Manager (\(dealerCount)/2)").tag(UserRole.dealer)
                                .disabled(willExceedQuota(.dealer))
                        }
                        
                        Text("Technician").tag(UserRole.technician)
                    }
                    .onChange(of: role) { oldValue, newValue in
                        if willExceedQuota(newValue) {
                            role = oldValue
                            showRoleLimitWarning = true
                        }
                    }
                    
                    Text(roleDescription(role))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                    if role == .technician {
                        HStack {
                            Text("Remaining technician slots:")
                            Spacer()
                            Text("\(storeKitManager.staffRemaining)")
                                .foregroundColor(storeKitManager.staffRemaining > 0 ? .green : .red)
                        }
                        .font(.caption)
                    }
                }
                
                Section {
                    Button(action: sendInvite) {
                        HStack {
                            Spacer()
                            if isInviting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Text("Send Invitation")
                            }
                            Spacer()
                        }
                    }
                    .disabled(fullName.isEmpty || email.isEmpty || phoneNumber.isEmpty || isInviting || willExceedQuota(role))
                }
            }
            .navigationTitle("Invite Staff")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Success", isPresented: $showSuccess) {
                Button("OK", role: .cancel) { dismiss() }
            } message: {
                Text("Invitation sent to \(fullName).")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Role Limit Reached", isPresented: $showRoleLimitWarning) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("You've reached the maximum number of users for this role. Your subscription allows for 1 Admin and 2 Inventory Managers.")
            }
        }
    }
    
    private func sendInvite() {
        isInviting = true
        
        // Check role quotas
        if willExceedQuota(role) {
            isInviting = false
            showRoleLimitWarning = true
            return
        }
        
        // Here you would implement your actual invitation logic
        // This would typically involve:
        // 1. Creating a pending invitation in your database
        // 2. Sending an email/SMS with a special link
        
        // For this sample, we'll just simulate a successful invitation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // Update the StoreKit manager's count
            if role == .technician {
                storeKitManager.currentStaffCount += 1
            }
            
            // Show success and call the completion handler
            isInviting = false
            showSuccess = true
            onInvite()
        }
    }
}

// Staff profile editing sheet
struct EditStaffProfileView: View {
    var user: AuthUser
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authService: AppAuthService
    @EnvironmentObject var storeKitManager: StoreKitManager
    @State private var fullName: String = ""
    @State private var email: String = ""
    @State private var role: UserRole = .technician
    @State private var isDeactivated: Bool = false
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showRoleLimitWarning = false
    @State private var enableGPSTracking: Bool = false
    
    // Query to count roles for quota enforcement
    @Query private var allUsers: [AuthUser]
    
    // Calculate role counts for quota management
    private var adminCount: Int {
        allUsers.filter { $0.userRole == .admin && $0.id != user.id }.count
    }
    
    private var dealerCount: Int {
        allUsers.filter { $0.userRole == .dealer && $0.id != user.id }.count
    }
    
    // Check if role change exceeds quota
    private func willExceedQuota(_ newRole: UserRole) -> Bool {
        // Role hasn't changed
        if user.userRole == newRole { return false }
        
        switch newRole {
        case .admin:
            // Only 1 admin allowed
            return adminCount >= 1
        case .dealer:
            // Only 2 inventory managers (dealers) allowed
            return dealerCount >= 2
        default:
            // No limit on technicians or other roles
            return false
        }
    }
    
    // Get descriptive role name for UI
    private func roleDisplayName(_ role: UserRole) -> String {
        switch role {
        case .admin: return "Admin"
        case .dealer: return "Inventory Manager"
        case .technician: return "Technician"
        default: return role.rawValue.capitalized
        }
    }
    
    // Get role description for UI
    private func roleDescription(_ role: UserRole) -> String {
        switch role {
        case .admin: 
            return "Full access to all features and user management"
        case .dealer: 
            return "Can manage inventory, warehouses, and transfer items"
        case .technician: 
            return "Can view inventory and use assigned items"
        default: 
            return ""
        }
    }
    
    // Get remaining slots for a role
    private func remainingSlotsForRole(_ role: UserRole) -> Int {
        switch role {
        case .admin: return max(0, 1 - adminCount)
        case .dealer: return max(0, 2 - dealerCount)
        case .technician: return max(0, storeKitManager.staffLimit - storeKitManager.currentStaffCount)
        default: return 0
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Profile")) {
                    TextField("Full Name", text: $fullName)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    if authService.currentUser?.userRole == .admin {
                        Section(header: Text("Role Management")) {
                            Picker("Role", selection: $role) {
                                Text("Admin (\(adminCount)/1)").tag(UserRole.admin)
                                    .disabled(willExceedQuota(.admin) && user.userRole != .admin)
                                
                                Text("Inventory Manager (\(dealerCount)/2)").tag(UserRole.dealer)
                                    .disabled(willExceedQuota(.dealer) && user.userRole != .dealer)
                                
                                Text("Technician").tag(UserRole.technician)
                            }
                            .onChange(of: role) { oldValue, newValue in
                                if willExceedQuota(newValue) {
                                    role = oldValue
                                    showRoleLimitWarning = true
                                }
                            }
                            
                            Text(roleDescription(role))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        HStack {
                            Text("Role")
                            Spacer()
                            Text(roleDisplayName(role))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Toggle("Deactivated", isOn: $isDeactivated)
                        .tint(.red)
                }
                
                if role == .technician {
                    Section(header: Text("Location Tracking"), footer: Text("Enabling GPS tracking will allow managers to see the location of this staff member's device even when the app is not running.")) {
                        Toggle("Enable GPS Tracking", isOn: $enableGPSTracking)
                            .tint(.green)
                        
                        if enableGPSTracking {
                            Text("IMPORTANT: Ensure you have informed the staff member about GPS tracking and have their consent in accordance with your company policy and local laws.")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                Section {
                    Button("Save Changes") { save() }
                        .disabled(fullName.isEmpty || email.isEmpty)
                }
            }
            .navigationTitle("Edit Staff")
            .navigationBarItems(trailing: Button("Done") { dismiss() })
            .onAppear {
                fullName = user.fullName ?? ""
                email = user.email
                role = user.userRole
                isDeactivated = user.isDeactivated
                // In a real app, you would load the GPS tracking status from the user model
                enableGPSTracking = Bool.random() // Placeholder for demo
            }
            .alert("Success", isPresented: $showSuccess) {
                Button("OK", role: .cancel) { dismiss() }
            } message: {
                Text("Profile updated.")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Role Limit Reached", isPresented: $showRoleLimitWarning) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("You've reached the maximum number of users for this role. Your subscription allows for 1 Admin and 2 Inventory Managers.")
            }
        }
    }
    
    private func save() {
        // Update user properties
        user.fullName = fullName
        user.email = email
        
        // Update role if admin and role quota isn't exceeded
        if authService.currentUser?.userRole == .admin && !willExceedQuota(role) {
            user.userRole = role
        }
        
        // Update activation status
        user.isDeactivated = isDeactivated
        
        // In a real app, you would also save the GPS tracking status
        // user.enableGPSTracking = enableGPSTracking
        
        // Complete and show success
        showSuccess = true
    }
}

#Preview {
    StaffListView()
        .environmentObject(AppAuthService())
        .environmentObject(StoreKitManager())
} 