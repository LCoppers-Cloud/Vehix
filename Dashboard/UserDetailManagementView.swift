import SwiftUI

struct UserDetailManagementView: View {
    @EnvironmentObject var authService: AppAuthService
    @Environment(\.dismiss) private var dismiss
    
    let userAccount: UserAccount
    let onUserUpdated: () -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // User Header
                    VStack(spacing: 16) {
                        Image(systemName: userAccount.accountType.systemImage)
                            .font(.system(size: 60))
                            .foregroundColor(Color.vehixBlue)
                        
                        VStack(spacing: 8) {
                            Text(userAccount.fullName)
                                .font(.title2.bold())
                                .foregroundColor(Color.vehixText)
                            
                            Text(userAccount.email)
                                .font(.subheadline)
                                .foregroundColor(Color.vehixSecondaryText)
                            
                            Text(userAccount.accountType.rawValue)
                                .font(.caption)
                                .foregroundColor(Color.vehixBlue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Color.vehixUIBlue.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    
                    // Status Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Account Status")
                            .font(.headline)
                            .foregroundColor(Color.vehixText)
                        
                        HStack {
                            Circle()
                                .fill(userAccount.isActive ? Color.vehixGreen : Color.vehixSecondaryText)
                                .frame(width: 12, height: 12)
                            
                            Text(userAccount.isActive ? "Active" : "Inactive")
                                .font(.subheadline)
                                .foregroundColor(Color.vehixText)
                            
                            Spacer()
                            
                            if let lastLogin = userAccount.lastLoginAt {
                                Text("Last login: \(lastLogin, style: .relative)")
                                    .font(.caption)
                                    .foregroundColor(Color.vehixSecondaryText)
                            }
                        }
                    }
                    .padding()
                    .background(Color.vehixSecondaryBackground)
                    .cornerRadius(12)
                    
                    // Permissions Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Permissions")
                            .font(.headline)
                            .foregroundColor(Color.vehixText)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            ForEach(userAccount.permissions, id: \.self) { permission in
                                HStack {
                                    Image(systemName: "checkmark")
                                        .font(.caption)
                                        .foregroundColor(Color.vehixGreen)
                                    
                                    Text(permission.displayName)
                                        .font(.caption)
                                        .foregroundColor(Color.vehixText)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.vehixBackground)
                                .cornerRadius(6)
                            }
                        }
                    }
                    .padding()
                    .background(Color.vehixSecondaryBackground)
                    .cornerRadius(12)
                    
                    // Department Access (if applicable)
                    if !userAccount.departmentAccess.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Department Access")
                                .font(.headline)
                                .foregroundColor(Color.vehixText)
                            
                            ForEach(userAccount.departmentAccess, id: \.self) { department in
                                HStack {
                                    Image(systemName: "building.columns")
                                        .font(.caption)
                                        .foregroundColor(Color.vehixBlue)
                                    
                                    Text(department)
                                        .font(.subheadline)
                                        .foregroundColor(Color.vehixText)
                                    
                                    Spacer()
                                }
                            }
                        }
                        .padding()
                        .background(Color.vehixSecondaryBackground)
                        .cornerRadius(12)
                    }
                    
                    // Actions (Placeholder for future implementation)
                    VStack(spacing: 12) {
                        Button("Edit Permissions") {
                            // TODO: Implement permission editing
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(true) // Disabled for now
                        
                        if userAccount.isActive {
                            Button("Deactivate Account") {
                                // TODO: Implement account deactivation
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(Color.vehixOrange)
                            .disabled(true) // Disabled for now
                        } else {
                            Button("Reactivate Account") {
                                // TODO: Implement account reactivation
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(true) // Disabled for now
                        }
                    }
                    .padding()
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("User Details")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    UserDetailManagementView(
        userAccount: UserAccount(
            fullName: "Preview User",
            email: "preview@icloud.com",
            passwordHash: "hash",
            accountType: .manager,
            permissions: [.viewVehicles, .editVehicles, .manageInventory],
            departmentAccess: ["Service", "Parts"]
        ),
        onUserUpdated: {}
    )
    .environmentObject(AppAuthService())
} 