import SwiftUI
import SwiftData
import Charts

public struct TechnicianDashboardView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var authService: AppAuthService
    @Environment(\.modelContext) private var modelContext
    
    // Dashboard tabs
    enum Tab: Hashable {
        case vehicles
        case services
        case transfers
    }
    
    @State private var selectedTab: Tab = .vehicles
    @State private var searchText = ""
    
    // Sample data (will be replaced with real data from database)
    @State private var activeJobs = 4
    @State private var hoursToday = 6.5
    @State private var partsUsed = 12
    
    // State for presenting sheets
    @State private var showingProfileView = false
    @State private var showingSettingsView = false
    
    // Colors
    var accentColor: Color {
        colorScheme == .dark ? Color(red: 0.2, green: 0.5, blue: 0.9) : Color(red: 0.2, green: 0.5, blue: 0.9)
    }
    
    var secondaryColor: Color {
        colorScheme == .dark ? Color(red: 0.9, green: 0.2, blue: 0.3) : Color(red: 0.9, green: 0.2, blue: 0.3)
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Top bar with search and profile
                topBar
                
                // Tab Bar
                tabBar
                
                // Main Content Area
                ScrollView {
                    VStack(spacing: 20) {
                        switch selectedTab {
                        case .vehicles:
                            assignedVehiclesView
                        case .services:
                            inventoryView
                        case .transfers:
                            VStack(spacing: 20) {
                                PendingTransfersView()
                                    .environmentObject(authService)
                                
                                Divider()
                                
                                TransferLogView(
                                    targetUser: authService.currentUser,
                                    title: "My Transfer History",
                                    itemLimit: 10
                                )
                                .environmentObject(authService)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingProfileView) {
            VehixUserProfileView()
                .environment(\.modelContext, modelContext)
        }
        .sheet(isPresented: $showingSettingsView) {
            SettingsView()
                .environmentObject(authService) // Ensure SettingsView has authService
                // Pass other necessary environment objects if needed
        }
    }
    
    // Top Bar with Search and Profile
    private var topBar: some View {
        HStack {
            // App name/logo
            Text("VEHIX")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(accentColor)
            
            Spacer()
            
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search vehicles...", text: $searchText)
                    .foregroundColor(.primary)
            }
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .frame(width: 200)
            
            Spacer()
            
            // Profile and Logout
            Menu {
                Button(action: {
                    showingProfileView = true
                }) {
                    Label("View Profile", systemImage: "person")
                }
                
                Button(action: {
                    showingSettingsView = true
                }) {
                    Label("Settings", systemImage: "gear")
                }
                
                Divider()
                
                Button(action: {
                    authService.signOut()
                }) {
                    Label("Sign Out", systemImage: "arrow.right.square")
                }
            } label: {
                Image(systemName: "person.circle")
                    .font(.system(size: 24))
                    .foregroundColor(accentColor)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // Tab Bar
    private var tabBar: some View {
        TabView(selection: $selectedTab) {
            // Vehicles Tab
            assignedVehiclesView
                .tabItem {
                    Label("Vehicles", systemImage: "car.2")
                }
                .tag(Tab.vehicles)
            
            // Services Tab (Placeholder)
            inventoryView
                .tabItem {
                    Label("Services", systemImage: "wrench.and.screwdriver")
                }
                .tag(Tab.services)
            
            // Pending Transfers Tab - Content now handled by the main ScrollView's switch case
            // This TabView is primarily for tab selection, content is in the ScrollView
            // We can put a simple container here or the direct content if ScrollView is removed from top level.
            // For consistency with how .vehicles and .services are handled, 
            // the VStack with PendingTransfersView and TransferLogView will be shown by the main switch.
            // So this specific tag will just select the tab.
            VStack {
                PendingTransfersView()
                    .environmentObject(authService)
                TransferLogView(targetUser: authService.currentUser, title: "My Transfer History", itemLimit: 10)
                    .environmentObject(authService)
            }
                .tabItem {
                    Label("Transfers", systemImage: "arrow.triangle.transfer")
                }
                .tag(Tab.transfers)
        }
    }
    
    // Assigned Vehicles View
    private var assignedVehiclesView: some View {
        VStack(spacing: 20) {
            // Dashboard title
            HStack {
                Text("My Assigned Vehicles")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
                Text("Today: \(formattedDate())")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            // Stats Cards
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                statCard(title: "Active Jobs", value: "\(activeJobs)", icon: "wrench.fill", color: .green)
                statCard(title: "Hours Today", value: "\(hoursToday)", icon: "clock.fill", color: accentColor)
                statCard(title: "Parts Used", value: "\(partsUsed)", icon: "shippingbox.fill", color: secondaryColor)
            }
            // Assigned Vehicles List
            VStack(alignment: .leading, spacing: 12) {
                Text("Current Assignments")
                    .font(.headline)
                    .padding(.top, 8)
                ForEach(currentAssignedVehicles(), id: \.id) { vehicle in
                    vehicleCard(make: vehicle.make, model: vehicle.model, year: vehicle.year, plate: vehicle.licensePlate ?? "", status: "", priority: "")
                }
            }
            .padding()
        }
    }
    
    // Helper to get assigned vehicles
    private func currentAssignedVehicles() -> [AppVehicle] {
        guard let userId = authService.currentUser?.id else { return [] }
        let now = Date()
        do {
            let assignmentDescriptor = FetchDescriptor<VehicleAssignment>(
                predicate: #Predicate<VehicleAssignment> { assignment in
                    assignment.userId == userId && (assignment.endDate == nil || assignment.endDate! > now)
                }
            )
            let assignments = try modelContext.fetch(assignmentDescriptor)
            return assignments.compactMap { $0.vehicle }
        } catch {
            return []
        }
    }
    
    // Vehicle Card
    private func vehicleCard(make: String, model: String, year: Int, plate: String, status: String, priority: String) -> some View {
        VStack {
            HStack(alignment: .top) {
                // Vehicle Icon
                Image(systemName: "car.fill")
                    .font(.system(size: 36))
                    .foregroundColor(accentColor)
                    .frame(width: 50)
                
                VStack(alignment: .leading, spacing: 4) {
                    // Vehicle Info
                    Text("\(year) \(make) \(model)")
                        .font(.headline)
                    
                    Text("Plate: \(plate)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Status
                    HStack {
                        Text("Status:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(status)
                            .font(.caption)
                            .bold()
                    }
                    
                    // Priority badge
                    HStack {
                        Text("Priority:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(priority)
                            .font(.caption)
                            .bold()
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(priorityColor(priority).opacity(0.2))
                            .foregroundColor(priorityColor(priority))
                            .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 8) {
                    Button(action: {
                        // View details action
                    }) {
                        Text("Details")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                    }
                    
                    Button(action: {
                        // Update status action
                    }) {
                        Text("Update")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.primary)
                            .cornerRadius(6)
                    }
                }
            }
            
            Divider()
                .padding(.top, 8)
        }
        .padding(.vertical, 8)
    }
    
    // Inventory View
    private var inventoryView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Parts Inventory")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.primary)
            
            // Search bar for inventory
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search parts...", text: $searchText)
                    .foregroundColor(.primary)
            }
            .padding(12)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            // Inventory categories
            VStack(alignment: .leading, spacing: 10) {
                Text("Categories")
                    .font(.headline)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        categoryButton(title: "All", icon: "shippingbox.fill")
                        categoryButton(title: "Filters", icon: "allergens")
                        categoryButton(title: "Brakes", icon: "brake.signal")
                        categoryButton(title: "Engine", icon: "engine.combustion")
                        categoryButton(title: "Fluids", icon: "drop.fill")
                        categoryButton(title: "Electrical", icon: "bolt.fill")
                    }
                }
            }
            
            // Parts list
            VStack(alignment: .leading, spacing: 12) {
                Text("Available Parts")
                    .font(.headline)
                
                // Sample inventory items - would be replaced with actual data
                inventoryItem(name: "Oil Filter", partNumber: "OF-12345", quantity: 23, price: 12.99)
                inventoryItem(name: "Brake Pads (Front)", partNumber: "BP-54321", quantity: 8, price: 48.95)
                inventoryItem(name: "Air Filter", partNumber: "AF-98765", quantity: 15, price: 19.99)
                inventoryItem(name: "Spark Plugs", partNumber: "SP-45678", quantity: 32, price: 7.99)
                inventoryItem(name: "Wiper Blades", partNumber: "WB-24680", quantity: 10, price: 24.99)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
    
    // Category Button
    private func categoryButton(title: String, icon: String) -> some View {
        VStack {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(accentColor)
                .cornerRadius(10)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.primary)
        }
    }
    
    // Inventory Item
    private func inventoryItem(name: String, partNumber: String, quantity: Int, price: Double) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.headline)
                
                Text("Part #: \(partNumber)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .center, spacing: 4) {
                Text("\(quantity)")
                    .font(.headline)
                
                Text("In Stock")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 80)
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(String(format: "%.2f", price))")
                    .font(.headline)
                
                Text("Per Unit")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 80)
            
            Button(action: {
                // Use part action
            }) {
                Text("Use")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(6)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
    
    // Stat Card
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                
                Spacer()
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 2)
    }
    
    // Helper function to get current formatted date
    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: Date())
    }
    
    // Helper function to get color for priority
    private func priorityColor(_ priority: String) -> Color {
        switch priority {
        case "High":
            return .red
        case "Medium":
            return .orange
        case "Low":
            return .green
        default:
            return .gray
        }
    }
}

#Preview {
    TechnicianDashboardView()
        .environmentObject(AppAuthService())
} 