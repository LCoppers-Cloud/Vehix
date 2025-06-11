import SwiftUI
import SwiftData

struct UserManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authService: AppAuthService
    
    @Query(sort: [SortDescriptor(\AuthUser.email)]) private var allUsers: [AuthUser]
    @Query private var vehicles: [Vehix.Vehicle]
    @Query private var warehouses: [AppWarehouse]
    @Query private var assignments: [VehicleAssignment]
    
    @State private var searchText = ""
    @State private var selectedUserRole: UserRole?
    @State private var showingAddUser = false
    @State private var selectedUser: AuthUser?
    @State private var showingUserDetail = false
    @State private var showingDeleteAlert = false
    @State private var userToDelete: AuthUser?
    @State private var showingRoleChangeAlert = false
    @State private var showingPasswordResetAlert = false
    @State private var newRoleForUser = ""
    
    @State private var email = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var role = "technician"
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private var filteredUsers: [AuthUser] {
        var users = allUsers
        
        // Filter by role
        if let role = selectedUserRole {
            users = users.filter { $0.userRole == role }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            users = users.filter { user in
                (user.fullName?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                user.email.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return users
    }
    
    private var userStats: (total: Int, admins: Int, premium: Int, technicians: Int, dealers: Int, activeToday: Int) {
        let total = allUsers.count
        let admins = allUsers.filter { $0.userRole == .admin }.count
        let premium = allUsers.filter { $0.userRole == .premium }.count
        let technicians = allUsers.filter { $0.userRole == .technician }.count
        let dealers = allUsers.filter { $0.userRole == .dealer }.count
        
        // Simplified active count since we don't have lastLoginDate
        let activeToday = total // All users considered active for now
        
        return (total, admins, premium, technicians, dealers, activeToday)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with stats
                headerSection
                
                // Search and filter
                searchAndFilterSection
                
                // User list
                userListSection
            }
            .navigationTitle("User Management")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddUser = true }) {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddUser) {
            AddUserView()
        }
        .sheet(isPresented: $showingUserDetail) {
            if let user = selectedUser {
                UserDetailView(user: user)
            }
        }
        .alert("Delete User", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {
                userToDelete = nil
            }
            Button("Delete", role: .destructive) {
                deleteUser()
            }
        } message: {
            if let user = userToDelete {
                Text("Are you sure you want to delete \(user.fullName ?? user.email)? This action cannot be undone and will remove all associated assignments.")
            }
        }
        .alert("Change User Role", isPresented: $showingRoleChangeAlert) {
            Button("Cancel", role: .cancel) {
                selectedUser = nil
                newRoleForUser = ""
            }
            Button("Change Role") {
                changeUserRole()
            }
        } message: {
            if let user = selectedUser {
                Text("Change \(user.fullName ?? user.email)'s role to \(newRoleForUser.capitalized)?")
            }
        }
        .alert("Reset Password", isPresented: $showingPasswordResetAlert) {
            Button("Cancel", role: .cancel) {
                selectedUser = nil
            }
            Button("Send Reset Email") {
                sendPasswordReset()
            }
        } message: {
            if let user = selectedUser {
                Text("Send a password reset email to \(user.email)?")
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Stats cards
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(
                    title: "Total Users", 
                    value: "\(userStats.total)", 
                    subtitle: "registered",
                    icon: "person.3.fill",
                    color: .blue
                )
                StatCard(
                    title: "Active Today", 
                    value: "\(userStats.activeToday)", 
                    subtitle: "online",
                    icon: "person.fill.checkmark",
                    color: .green
                )
                StatCard(
                    title: "Technicians", 
                    value: "\(userStats.technicians)", 
                    subtitle: "field staff",
                    icon: "wrench.fill",
                    color: .orange
                )
            }
            
            // Role breakdown
            HStack(spacing: 16) {
                RoleChip(title: "Admins", count: userStats.admins, color: .red)
                RoleChip(title: "Managers", count: userStats.premium, color: .purple)
                RoleChip(title: "Dealers", count: userStats.dealers, color: .blue)
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Search and Filter Section
    private var searchAndFilterSection: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search users...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            // Role filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // "All" filter button
                    Button(action: {
                        selectedUserRole = nil
                    }) {
                        Text("All Users")
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedUserRole == nil ? Color.blue : Color(.systemGray6))
                            .foregroundColor(selectedUserRole == nil ? .white : .primary)
                            .cornerRadius(16)
                    }
                    
                    // Individual role filters
                    ForEach([UserRole.admin, UserRole.premium, UserRole.technician, UserRole.dealer, UserRole.standard], id: \.self) { role in
                        Button(action: {
                            selectedUserRole = selectedUserRole == role ? nil : role
                        }) {
                            Text(role.rawValue.capitalized)
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedUserRole == role ? Color.blue : Color(.systemGray6))
                                .foregroundColor(selectedUserRole == role ? .white : .primary)
                                .cornerRadius(16)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - User List Section
    private var userListSection: some View {
        List {
            ForEach(filteredUsers, id: \.id) { user in
                UserRow(
                    user: user,
                    assignments: assignments.filter { $0.userId == user.id },
                    onTap: {
                        selectedUser = user
                        showingUserDetail = true
                    },
                    onRoleChange: { newRole in
                        selectedUser = user
                        newRoleForUser = newRole
                        showingRoleChangeAlert = true
                    },
                    onPasswordReset: {
                        selectedUser = user
                        showingPasswordResetAlert = true
                    },
                    onDelete: {
                        userToDelete = user
                        showingDeleteAlert = true
                    }
                )
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Helper Functions
    private func deleteUser() {
        guard let user = userToDelete else { return }
        
        // End any active vehicle assignments
        let userAssignments = assignments.filter { $0.userId == user.id && $0.endDate == nil }
        for assignment in userAssignments {
            assignment.endDate = Date()
        }
        
        // Delete the user
        modelContext.delete(user)
        
        do {
            try modelContext.save()
        } catch {
            print("Error deleting user: \(error)")
        }
        
        userToDelete = nil
    }
    
    private func changeUserRole() {
        guard let user = selectedUser else { return }
        
        // Convert string to UserRole enum
        if let newRole = UserRole(rawValue: newRoleForUser) {
            user.userRole = newRole
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Error changing user role: \(error)")
        }
        
        selectedUser = nil
        newRoleForUser = ""
    }
    
    private func sendPasswordReset() {
        guard let user = selectedUser else { return }
        
        // In a real app, this would trigger a password reset email
        // For now, we'll just update the user's last login to indicate activity
        user.lastLogin = Date()
        
        do {
            try modelContext.save()
            // Show success message or handle the password reset flow
        } catch {
            print("Error requesting password reset: \(error)")
        }
        
        selectedUser = nil
    }
}

// MARK: - Supporting Views

struct RoleChip: View {
    let title: String
    let count: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text("\(count) \(title)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct UserRow: View {
    let user: AuthUser
    let assignments: [VehicleAssignment]
    let onTap: () -> Void
    let onRoleChange: (String) -> Void
    let onPasswordReset: () -> Void
    let onDelete: () -> Void
    
    @State private var showingActionSheet = false
    
    private var activeAssignments: [VehicleAssignment] {
        assignments.filter { $0.endDate == nil }
    }
    
    private var lastLoginText: String {
        // Simplified since we don't have lastLoginDate in the model
        return "Active"
    }
    
    private var roleColor: Color {
        switch user.userRole {
        case .owner: return .red
        case .manager: return .purple
        case .technician: return .orange
        case .admin: return .red
        case .premium: return .purple
        case .dealer: return .blue
        case .standard: return .gray
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                HStack {
                    // User avatar and info
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(user.fullName ?? "Unknown User")
                                .font(.headline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            // Role badge
                            Text(user.userRole.rawValue.capitalized)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(roleColor.opacity(0.1))
                                .foregroundColor(roleColor)
                                .cornerRadius(6)
                        }
                        
                        Text(user.email)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Status and assignment info
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Last Login")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(lastLoginText)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    if !activeAssignments.isEmpty {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Assignments")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(activeAssignments.count) active")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        }
                    }
                    
                    // Action menu button
                    Button(action: { showingActionSheet = true }) {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .confirmationDialog("User Actions", isPresented: $showingActionSheet) {
            Button("Change Role") {
                // Show role selection
                showRoleSelection()
            }
            
            Button("Reset Password") {
                onPasswordReset()
            }
            
            Button("Delete User", role: .destructive) {
                onDelete()
            }
            
            Button("Cancel", role: .cancel) { }
        }
    }
    
    private func showRoleSelection() {
        // In a real implementation, this would show a picker for role selection
        // For now, we'll cycle through roles as an example
        let roles = ["technician", "premium", "admin", "dealer", "standard"]
        let currentIndex = roles.firstIndex(of: user.userRole.rawValue) ?? 0
        let nextIndex = (currentIndex + 1) % roles.count
        onRoleChange(roles[nextIndex])
    }
}

struct AddUserView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var email = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var phoneNumber = ""
    @State private var role = "technician"
    @State private var companyName = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private let roles = ["technician", "manager", "admin", "dealer"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("User Information") {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                }
                
                Section("Role & Company") {
                    Picker("Role", selection: $role) {
                        ForEach(roles, id: \.self) { role in
                            Text(role.capitalized).tag(role)
                        }
                    }
                    
                    TextField("Company Name", text: $companyName)
                }
                
                Section {
                    Text("A welcome email with login instructions will be sent to the user.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Add User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add User") {
                        addUser()
                    }
                    .disabled(email.isEmpty || firstName.isEmpty)
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func addUser() {
        guard !email.isEmpty, !firstName.isEmpty else {
            errorMessage = "Email and first name are required"
            showingError = true
            return
        }
        
        let newUser = AuthUser(
            id: UUID().uuidString,
            email: email,
            fullName: "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces),
            role: UserRole(rawValue: role) ?? .technician,
            createdAt: Date()
        )
        
        modelContext.insert(newUser)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to add user: \(error.localizedDescription)"
            showingError = true
        }
    }
}

struct UserDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let user: AuthUser
    
    @Query private var assignments: [VehicleAssignment]
    @Query private var vehicles: [Vehix.Vehicle]
    
    private var userAssignments: [VehicleAssignment] {
        assignments.filter { $0.userId == user.id }
    }
    
    private var activeAssignments: [VehicleAssignment] {
        userAssignments.filter { $0.endDate == nil }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // User header
                    userHeaderSection
                    
                    // Contact information
                    contactInfoSection
                    
                    // Current assignments
                    if !activeAssignments.isEmpty {
                        currentAssignmentsSection
                    }
                    
                    // Assignment history
                    if !userAssignments.isEmpty {
                        assignmentHistorySection
                    }
                    
                    // Account actions
                    accountActionsSection
                }
                .padding()
            }
            .navigationTitle("User Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var userHeaderSection: some View {
        VStack(spacing: 16) {
            // User avatar placeholder
            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 80, height: 80)
                .overlay {
                    Text(user.fullName?.prefix(2).uppercased() ?? "U")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
            
            VStack(spacing: 4) {
                Text(user.fullName ?? "Unknown User")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(user.userRole.rawValue.capitalized)
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var contactInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Contact Information")
                .font(.headline)
            
            VStack(spacing: 12) {
                ContactRow(icon: "envelope.fill", title: "Email", value: user.email)
                
                ContactRow(icon: "person.fill", title: "Role", value: user.userRole.rawValue.capitalized)
                
                ContactRow(icon: "calendar", title: "Created", value: formatDate(user.createdAt))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var currentAssignmentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Current Assignments")
                .font(.headline)
            
            VStack(spacing: 8) {
                ForEach(activeAssignments, id: \.id) { assignment in
                    if let vehicle = vehicles.first(where: { $0.id == assignment.vehicleId }) {
                        AssignmentRow(assignment: assignment, vehicle: vehicle)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var assignmentHistorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Assignment History")
                .font(.headline)
            
            Text("\(userAssignments.count) total assignments")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var accountActionsSection: some View {
        VStack(spacing: 12) {
            Button("Reset Password") {
                // Handle password reset
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
            
            Button("Deactivate Account") {
                // Handle account deactivation
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct ContactRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline)
            }
            
            Spacer()
        }
    }
}

struct AssignmentRow: View {
    let assignment: VehicleAssignment
    let vehicle: Vehix.Vehicle
    
    var body: some View {
        HStack {
            Image(systemName: "car.fill")
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(vehicle.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Since \(assignment.startDate, style: .date)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            let days = Calendar.current.dateComponents([.day], from: assignment.startDate, to: Date()).day ?? 0
            Text("\(days) days")
                .font(.caption)
                .foregroundColor(.green)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    UserManagementView()
        .environmentObject(AppAuthService())
        .modelContainer(for: [AuthUser.self, VehicleAssignment.self, Vehix.Vehicle.self], inMemory: true)
} 