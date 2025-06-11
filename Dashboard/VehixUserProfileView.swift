import SwiftUI
import SwiftData

struct VehixUserProfileView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authService: AppAuthService
    
    // Data queries
    @Query private var allVehicles: [AppVehicle]
    @Query private var assignments: [VehicleAssignment]
    @Query private var businessAccounts: [BusinessAccount]
    @Query private var userAccounts: [UserAccount]
    
    @State private var showingEditProfile = false
    @State private var showingAccountSettings = false
    
    // Current user information
    private var currentUser: AppUser? {
        authService.currentUser
    }
    
    private var currentBusinessAccount: BusinessAccount? {
        businessAccounts.first
    }
    
    private var currentUserAccount: UserAccount? {
        guard let userId = currentUser?.id else { return nil }
        return userAccounts.first { $0.userID.uuidString == userId }
    }
    
    // Get assigned vehicles for technicians
    private var assignedVehicles: [AppVehicle] {
        guard let userId = currentUser?.id else { return [] }
        
        let activeAssignments = assignments.filter { assignment in
            assignment.userId == userId && assignment.endDate == nil
        }
        
        return allVehicles.filter { vehicle in
            activeAssignments.contains { $0.vehicleId == vehicle.id }
        }
    }
    
    private var accountTypeInfo: (String, String, Color) {
        if let userAccount = currentUserAccount {
            switch userAccount.accountType {
            case .owner:
                        return ("Owner", "Full access to all business functions", Color.vehixBlue)
    case .manager:
        return ("Manager", "Manage assigned departments and technicians", Color.vehixGreen)
    case .technician:
        return ("Technician", "Access to assigned vehicles and tasks", Color.vehixOrange)
            }
        } else if let user = currentUser {
            // Fallback to legacy user roles
            switch user.userRole {
            case .admin:
                return ("Administrator", "Full system access and management", .red)
            case .dealer:
                return ("Dealer", "Manage inventory and vehicles", .blue)
            case .premium:
                return ("Premium", "Advanced features and analytics", .purple)
            case .technician:
                return ("Technician", "Access to assigned vehicles and tasks", .orange)
            case .standard:
                return ("Standard", "Basic access to assigned tasks", .gray)
            case .owner:
                return ("Owner", "Full business access and management", .blue)
            case .manager:
                return ("Manager", "Manage assigned departments and technicians", .green)
            }
        } else {
            return ("Unknown", "Role not determined", .gray)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    profileHeaderSection
                    
                    // Account Information
                    accountInfoSection
                    
                    // Role & Permissions
                    rolePermissionsSection
                    
                    // For technicians: Assigned Vehicles
                    if accountTypeInfo.0 == "Technician" || currentUser?.userRole == .technician {
                        assignedVehiclesSection
                    }
                    
                    // Business Information (if applicable)
                    if let business = currentBusinessAccount {
                        businessInfoSection(business)
                    }
                    
                    // Account Actions
                    accountActionsSection
                }
                .padding()
            }
            .background(Color.vehixSecondaryBackground.ignoresSafeArea())
            .navigationTitle("My Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        showingEditProfile = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditProfile) {
            EditProfileView()
                .environmentObject(authService)
        }
        .sheet(isPresented: $showingAccountSettings) {
            AccountSettingsView()
                .environmentObject(authService)
        }
    }
    
    // MARK: - Profile Header Section
    
    private var profileHeaderSection: some View {
        VStack(spacing: 16) {
            // Profile Photo
            profilePhotoView
            
            // Name and Basic Info
            VStack(spacing: 8) {
                Text(currentUser?.fullName ?? "Unknown User")
                    .font(.title2.bold())
                    .foregroundColor(Color.vehixText)
                
                Text(currentUser?.email ?? "No email")
                    .font(.subheadline)
                    .foregroundColor(Color.vehixSecondaryText)
                
                // Account Type Badge
                accountTypeBadge
            }
        }
        .padding()
        .background(Color.vehixBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var profilePhotoView: some View {
        ZStack {
            Circle()
                .fill(accountTypeInfo.2.opacity(0.2))
                .frame(width: 100, height: 100)
            
                        if false { // TODO: Add profile photo support
                // Placeholder for future profile photo implementation
                EmptyView()
            } else {
                // Default initials
                Text(userInitials)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(accountTypeInfo.2)
            }
        }
    }
    
    private var userInitials: String {
        let name = currentUser?.fullName ?? currentUser?.email ?? "U"
        let components = name.components(separatedBy: .whitespacesAndNewlines)
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        } else {
            return String(name.prefix(2)).uppercased()
        }
    }
    
    private var accountTypeBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(accountTypeInfo.2)
                .frame(width: 8, height: 8)
            
            Text(accountTypeInfo.0)
                .font(.subheadline.bold())
                .foregroundColor(accountTypeInfo.2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(accountTypeInfo.2.opacity(0.1))
        .cornerRadius(20)
    }
    
    // MARK: - Account Information Section
    
    private var accountInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Account Information")
                .font(.headline.bold())
                .foregroundColor(Color.vehixText)
            
            VStack(spacing: 12) {
                InfoRow(
                    icon: "envelope.fill",
                    title: "Email",
                    value: currentUser?.email ?? "Not set"
                )
                
                InfoRow(
                    icon: "person.fill",
                    title: "Full Name",
                    value: currentUser?.fullName ?? "Not set"
                )
                
                InfoRow(
                                            icon: "calendar",
                    title: "Member Since",
                    value: formatDate(currentUser?.createdAt ?? Date())
                )
                
                InfoRow(
                    icon: "clock.fill",
                    title: "Last Login",
                    value: formatRelativeDate(currentUser?.lastLogin ?? Date())
                )
                
                InfoRow(
                    icon: "checkmark.shield.fill",
                    title: "Account Status",
                    value: currentUser?.isVerified == true ? "Verified" : "Pending Verification",
                    valueColor: currentUser?.isVerified == true ? Color.vehixGreen : Color.vehixOrange
                )
            }
        }
        .padding()
        .background(Color.vehixBackground)
        .cornerRadius(16)
    }
    
    // MARK: - Role & Permissions Section
    
    private var rolePermissionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Role & Permissions")
                .font(.headline.bold())
                .foregroundColor(Color.vehixText)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: roleIcon)
                        .font(.title2)
                        .foregroundColor(accountTypeInfo.2)
                        .frame(width: 32)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(accountTypeInfo.0)
                            .font(.subheadline.bold())
                            .foregroundColor(Color.vehixText)
                        
                        Text(accountTypeInfo.1)
                            .font(.caption)
                            .foregroundColor(Color.vehixSecondaryText)
                    }
                    
                    Spacer()
                }
                
                // Permissions preview
                if let userAccount = currentUserAccount {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Key Permissions:")
                            .font(.caption.bold())
                            .foregroundColor(Color.vehixSecondaryText)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 4) {
                            ForEach(userAccount.permissions.prefix(6), id: \.self) { permission in
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark")
                                        .font(.caption)
                                        .foregroundColor(Color.vehixGreen)
                                    
                                    Text(permission.displayName)
                                        .font(.caption)
                                        .foregroundColor(Color.vehixText)
                                    
                                    Spacer()
                                }
                            }
                        }
                        
                        if userAccount.permissions.count > 6 {
                            Text("...and \(userAccount.permissions.count - 6) more")
                                .font(.caption)
                                .foregroundColor(Color.vehixSecondaryText)
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
        .padding()
        .background(Color.vehixBackground)
        .cornerRadius(16)
    }
    
    private var roleIcon: String {
        if let userAccount = currentUserAccount {
            switch userAccount.accountType {
            case .owner: return "crown.fill"
            case .manager: return "person.2.fill"
            case .technician: return "wrench.and.screwdriver.fill"
            }
        } else if let user = currentUser {
            switch user.userRole {
            case .admin: return "shield.fill"
            case .dealer: return "building.2.fill"
            case .premium: return "star.fill"
            case .technician: return "wrench.and.screwdriver.fill"
            case .standard: return "person.fill"
            case .owner: return "crown.fill"
            case .manager: return "person.2.fill"
            }
        }
        return "person.fill"
    }
    
    // MARK: - Assigned Vehicles Section (for Technicians)
    
    private var assignedVehiclesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Assigned Vehicles")
                    .font(.headline.bold())
                    .foregroundColor(Color.vehixText)
                
                Spacer()
                
                Text("\(assignedVehicles.count)")
                    .font(.caption.bold())
                    .foregroundColor(Color.vehixBlue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.vehixUIBlue.opacity(0.1))
                    .cornerRadius(12)
            }
            
            if assignedVehicles.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "car.slash")
                        .font(.title)
                        .foregroundColor(Color.vehixSecondaryText)
                    
                    Text("No Vehicles Assigned")
                        .font(.subheadline.bold())
                        .foregroundColor(Color.vehixSecondaryText)
                    
                    Text("Contact your manager to get vehicles assigned to you")
                        .font(.caption)
                        .foregroundColor(Color.vehixSecondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                VStack(spacing: 12) {
                    ForEach(assignedVehicles, id: \.id) { vehicle in
                        AssignedVehicleRow(vehicle: vehicle)
                    }
                }
            }
        }
        .padding()
        .background(Color.vehixBackground)
        .cornerRadius(16)
    }
    
    // MARK: - Business Information Section
    
    private func businessInfoSection(_ business: BusinessAccount) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Business Information")
                .font(.headline.bold())
                .foregroundColor(Color.vehixText)
            
            VStack(spacing: 12) {
                InfoRow(
                    icon: "building.2.fill",
                    title: "Business Name",
                    value: business.businessName
                )
                
                InfoRow(
                    icon: "briefcase.fill",
                    title: "Business Type",
                    value: business.businessType
                )
                
                InfoRow(
                    icon: "car.2.fill",
                    title: "Fleet Size",
                    value: business.fleetSize
                )
                
                InfoRow(
                    icon: "creditcard.fill",
                    title: "Subscription Plan",
                    value: business.subscriptionPlan
                )
            }
        }
        .padding()
        .background(Color.vehixBackground)
        .cornerRadius(16)
    }
    
    // MARK: - Account Actions Section
    
    private var accountActionsSection: some View {
        VStack(spacing: 12) {
            Button(action: { showingAccountSettings = true }) {
                HStack {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(Color.vehixBlue)
                    
                    Text("Account Settings")
                        .font(.subheadline.bold())
                        .foregroundColor(Color.vehixText)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(Color.vehixSecondaryText)
                }
                .padding()
                .background(Color.vehixBackground)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            
            Button(action: { authService.signOut() }) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(.red)
                    
                    Text("Sign Out")
                        .font(.subheadline.bold())
                        .foregroundColor(.red)
                    
                    Spacer()
                }
                .padding()
                .background(Color.vehixBackground)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Helper Functions
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Supporting Views

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    let valueColor: Color?
    
    init(icon: String, title: String, value: String, valueColor: Color? = nil) {
        self.icon = icon
        self.title = title
        self.value = value
        self.valueColor = valueColor
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(Color.vehixBlue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(Color.vehixSecondaryText)
                
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(valueColor ?? Color.vehixText)
            }
            
            Spacer()
        }
    }
}

struct AssignedVehicleRow: View {
    let vehicle: AppVehicle
    
    var body: some View {
        HStack(spacing: 12) {
            // Vehicle icon
            ZStack {
                Circle()
                    .fill(Color.vehixUIBlue.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "car.fill")
                    .font(.subheadline)
                    .foregroundColor(Color.vehixBlue)
            }
            
            // Vehicle info
            VStack(alignment: .leading, spacing: 4) {
                Text("\(vehicle.year) \(vehicle.make) \(vehicle.model)")
                    .font(.subheadline.bold())
                    .foregroundColor(Color.vehixText)
                
                if let licensePlate = vehicle.licensePlate, !licensePlate.isEmpty {
                    Text("Plate: \(licensePlate)")
                        .font(.caption)
                        .foregroundColor(Color.vehixSecondaryText)
                } else {
                    Text("VIN: \(String(vehicle.vin.suffix(6)))")
                        .font(.caption)
                        .foregroundColor(Color.vehixSecondaryText)
                }
            }
            
            Spacer()
            
            // Inventory count (if any)
            if let stockItems = vehicle.stockItems, !stockItems.isEmpty {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(stockItems.count)")
                        .font(.caption.bold())
                        .foregroundColor(Color.vehixGreen)
                    
                    Text("items")
                        .font(.caption2)
                        .foregroundColor(Color.vehixSecondaryText)
                }
            }
        }
        .padding()
        .background(Color.vehixSecondaryBackground)
        .cornerRadius(12)
    }
}

// MARK: - Placeholder Views

struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AppAuthService
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Edit Profile")
                    .font(.title)
                    .padding()
                
                Text("Profile editing functionality coming soon")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { dismiss() }
                }
            }
        }
    }
}

struct AccountSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AppAuthService
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Account Settings")
                    .font(.title)
                    .padding()
                
                Text("Account settings functionality coming soon")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .navigationTitle("Account Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    VehixUserProfileView()
        .environmentObject(AppAuthService())
} 