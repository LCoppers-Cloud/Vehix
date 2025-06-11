import SwiftUI

struct EmptyTechnicianStateView: View {
    @Binding var showingTechnicianInvite: Bool
    @State private var showingInfo = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: "person.2.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(Color.vehixBlue)
                .padding(.top, 20)
            
            // Title and Description
            VStack(spacing: 12) {
                Text("No Technicians Yet")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Start building your team by adding technicians. They'll be able to manage vehicle inventory and complete service tasks.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            // Benefits List
            VStack(alignment: .leading, spacing: 16) {
                FeatureBenefit(
                    icon: "car.fill",
                    title: "Vehicle Assignment",
                    description: "Assign specific vehicles to technicians for inventory management"
                )
                
                FeatureBenefit(
                    icon: "cube.box.fill",
                    title: "Inventory Control",
                    description: "Track parts and supplies on each vehicle in real-time"
                )
                
                FeatureBenefit(
                    icon: "wrench.and.screwdriver.fill",
                    title: "Service Tracking",
                    description: "Monitor completed jobs and maintenance records"
                )
                
                FeatureBenefit(
                    icon: "bell.fill",
                    title: "Team Communication",
                    description: "Send tasks and receive status updates from the field"
                )
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            // Action Buttons
            VStack(spacing: 12) {
                // Primary Action
                Button(action: {
                    showingTechnicianInvite = true
                }) {
                    HStack {
                        Image(systemName: "person.badge.plus")
                        Text("Add First Technician")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.vehixBlue)
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Secondary Action
                Button(action: {
                    showingInfo = true
                }) {
                    HStack {
                        Image(systemName: "info.circle")
                        Text("Learn More About Team Management")
                    }
                    .font(.subheadline)
                    .foregroundColor(Color.vehixBlue)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showingInfo) {
            TechnicianInfoSheetView()
        }
    }
}

// MARK: - Supporting Views

struct FeatureBenefit: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(Color.vehixBlue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct TechnicianInfoSheetView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Team Management Guide")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Everything you need to know about adding and managing technicians in Vehix.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Getting Started Section
                    TechnicianInfoSection(
                        title: "Getting Started",
                        items: [
                            TechnicianInfoItem(
                                icon: "1.circle.fill",
                                title: "Add Technicians",
                                description: "Invite team members by email. They'll receive setup instructions."
                            ),
                            TechnicianInfoItem(
                                icon: "2.circle.fill",
                                title: "Create Vehicles",
                                description: "Add your company vehicles that will carry inventory."
                            ),
                            TechnicianInfoItem(
                                icon: "3.circle.fill",
                                title: "Assign Vehicles",
                                description: "Connect technicians to their assigned vehicles for inventory tracking."
                            )
                        ]
                    )
                    
                    // Technician Capabilities Section
                    TechnicianInfoSection(
                        title: "What Technicians Can Do",
                        items: [
                            TechnicianInfoItem(
                                icon: "cube.box",
                                title: "Manage Vehicle Inventory",
                                description: "View and update parts on their assigned vehicles"
                            ),
                            TechnicianInfoItem(
                                icon: "clipboard.fill",
                                title: "Complete Service Records",
                                description: "Track maintenance and repairs with detailed records"
                            ),
                            TechnicianInfoItem(
                                icon: "camera.fill",
                                title: "Scan Receipts",
                                description: "Use AI-powered receipt scanning for purchase orders"
                            ),
                            TechnicianInfoItem(
                                icon: "location.fill",
                                title: "GPS Tracking",
                                description: "Optional location tracking for job completion verification"
                            )
                        ]
                    )
                    
                    // Best Practices Section
                    TechnicianInfoSection(
                        title: "Best Practices",
                        items: [
                            TechnicianInfoItem(
                                icon: "checkmark.circle",
                                title: "Clear Vehicle Assignment",
                                description: "Each technician should have clearly assigned vehicles"
                            ),
                            TechnicianInfoItem(
                                icon: "arrow.clockwise",
                                title: "Regular Inventory Updates",
                                description: "Encourage daily inventory level updates"
                            ),
                            TechnicianInfoItem(
                                icon: "bell",
                                title: "Enable Notifications",
                                description: "Stay informed about low stock and completed jobs"
                            )
                        ]
                    )
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Team Management")
            .navigationBarTitleDisplayMode(.inline)
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

struct TechnicianInfoSection: View {
    let title: String
    let items: [TechnicianInfoItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(Color.vehixBlue)
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(items.indices, id: \.self) { index in
                    items[index]
                }
            }
        }
    }
}

struct TechnicianInfoItem: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(Color.vehixBlue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    EmptyTechnicianStateView(showingTechnicianInvite: .constant(false))
} 