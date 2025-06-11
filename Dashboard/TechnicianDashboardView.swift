import SwiftUI
import SwiftData
import Charts

public struct TechnicianDashboardView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var authService: AppAuthService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    // Sheet presentation manager
    @StateObject private var sheetManager = SheetPresentationManager()
    
    // Unified data queries
    @Query(sort: [SortDescriptor(\Vehix.Vehicle.licensePlate)]) private var vehicles: [AppVehicle]
    @Query(sort: [SortDescriptor(\AppTask.dueDate)]) private var tasks: [AppTask]
    @Query(sort: [SortDescriptor(\Vehix.ServiceRecord.startTime, order: .reverse)]) private var serviceRecords: [AppServiceRecord]
    @Query(sort: [SortDescriptor(\StockLocationItem.createdAt, order: .reverse)]) private var stockLocations: [StockLocationItem]
    @Query(sort: [SortDescriptor(\VehicleAssignment.startDate, order: .reverse)]) private var assignments: [VehicleAssignment]
    
    // State
    @State private var selectedTab: Tab = .vehicles
    
    enum Tab: String, CaseIterable {
        case vehicles = "Vehicles"
        case services = "Services"
        case transfers = "Transfers"
        
        var icon: String {
            switch self {
            case .vehicles: return "car.fill"
            case .services: return "wrench.and.screwdriver.fill"
            case .transfers: return "arrow.triangle.swap"
            }
        }
    }
    
    // Computed properties
    private var assignedVehicles: [AppVehicle] {
        guard let userId = authService.currentUser?.id else { return [] }
        
        // Get active assignments for this technician
        let activeAssignments = assignments.filter { assignment in
            assignment.userId == userId && assignment.endDate == nil
        }
        
        // Return vehicles that match the assigned vehicle IDs
        return vehicles.filter { vehicle in
            activeAssignments.contains { $0.vehicleId == vehicle.id }
        }
    }
    
    private var myTasks: [AppTask] {
        tasks.filter { task in
            task.assignedTo?.id == authService.currentUser?.id
        }
    }
    
    private var todaysTasks: [AppTask] {
        myTasks.filter { task in
            Calendar.current.isDateInToday(task.dueDate)
        }
    }
    
    private var overdueTasks: [AppTask] {
        myTasks.filter { task in
            task.status != TaskStatus.completed.rawValue &&
            task.status != TaskStatus.cancelled.rawValue &&
            task.dueDate < Date()
        }
    }
    
    private var activeJobs: [AppServiceRecord] {
        serviceRecords.filter { record in
            record.status == "In Progress"
            // TODO: Add technician assignment filtering when model is updated
        }
    }
    
    private var hoursToday: Double {
        return activeJobs
            .filter { Calendar.current.isDateInToday($0.startTime) }
            .reduce(0.0) { total, record in
                let duration = Date().timeIntervalSince(record.startTime) / 3600
                return total + min(duration, 8.0) // Cap at 8 hours per job
            }
    }
    
    private var partsUsedToday: Int {
        return stockLocations
            .filter { 
                Calendar.current.isDateInToday($0.createdAt)
                // TODO: Add technician filtering when model supports it
            }
            .reduce(0) { $0 + $1.quantity }
    }
    
    // Device detection
    private var isIPad: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                headerSection
                
                // Tab selector
                tabSelector
                
                // Main content
                ScrollView {
                    LazyVStack(spacing: isIPad ? 24 : 16) {
                        // Key metrics
                        keyMetricsSection
                        
                        // Main content based on selected tab
                        switch selectedTab {
                        case .vehicles:
                            vehiclesSection
                        case .services:
                            servicesSection
                        case .transfers:
                            transfersSection
                        }
                    }
                    .padding(isIPad ? 24 : 16)
                }
            }
            .navigationBarHidden(true)
        }
        .environmentObject(sheetManager)
        .sheet(isPresented: $sheetManager.isSheetPresented) {
            if let currentSheet = sheetManager.currentSheet {
                CoordinatedSheetView(sheetType: currentSheet)
                    .environmentObject(sheetManager)
                    .environmentObject(authService)
                    .environment(\.modelContext, modelContext)
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                // App branding
                HStack(spacing: 8) {
                    Image(systemName: "car.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                    Text("VEHIX")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                // Profile and settings
                HStack(spacing: 16) {
                    Button(action: { sheetManager.requestPresentation(.settings) }) {
                        Image(systemName: "gear")
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                    
                    Button(action: { sheetManager.requestPresentation(.profile) }) {
                        Image(systemName: "person.crop.circle")
                            .font(.title2)
                            .foregroundColor(.primary)
                    }
                }
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("My Dashboard")
                        .font(isIPad ? .largeTitle : .title2)
                        .fontWeight(.bold)
                    
                    Text("Today: \(formattedDate())")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Tab Selector
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    VStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 18))
                        
                        Text(tab.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundColor(selectedTab == tab ? .blue : .secondary)
                    .background(
                        selectedTab == tab ?
                        Rectangle()
                            .fill(.blue.opacity(0.1))
                            .frame(height: 2)
                            .offset(y: 20)
                        : nil
                    )
                }
            }
        }
        .padding(.horizontal)
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Key Metrics Section
    private var keyMetricsSection: some View {
        LazyVGrid(columns: gridColumns, spacing: isIPad ? 20 : 12) {
            // AI Receipt Processing Quick Action
            Button(action: {
                sheetManager.requestPresentation(.receiptProcessing)
            }) {
                MetricCard(
                    title: "Process Receipt",
                    value: "AI",
                    subtitle: "Scan & Submit",
                    icon: "brain.head.profile",
                    color: .purple,
                    trend: .neutral,
                    isActionCard: true
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            MetricCard(
                title: "Active Jobs",
                value: "\(activeJobs.count)",
                subtitle: "In Progress",
                icon: "wrench.fill",
                color: .green,
                trend: .neutral
            )
            
            MetricCard(
                title: "Hours Today",
                value: String(format: "%.1f", hoursToday),
                subtitle: "Working Time",
                icon: "clock.fill",
                color: .blue,
                trend: .up
            )
            
            MetricCard(
                title: "Parts Used",
                value: "\(partsUsedToday)",
                subtitle: "Today",
                icon: "cube.box.fill",
                color: .orange,
                trend: .neutral
            )
            
            if !overdueTasks.isEmpty {
                MetricCard(
                    title: "Overdue",
                    value: "\(overdueTasks.count)",
                    subtitle: "Tasks",
                    icon: "exclamationmark.triangle.fill",
                    color: .red,
                    trend: .down
                )
            }
        }
    }
    
    // MARK: - Vehicles Section
    private var vehiclesSection: some View {
        VStack(spacing: isIPad ? 20 : 16) {
            SectionCard(title: "My Assigned Vehicles") {
                if assignedVehicles.isEmpty {
                    EmptyStateView(
                        icon: "car.2",
                        title: "No Assigned Vehicles",
                        message: "You don't have any vehicles assigned to you yet."
                    )
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(assignedVehicles, id: \.id) { vehicle in
                            TechnicianVehicleRow(vehicle: vehicle)
                        }
                    }
                }
            }
            
            if !todaysTasks.isEmpty {
                SectionCard(title: "Today's Tasks") {
                    LazyVStack(spacing: 8) {
                        ForEach(todaysTasks.prefix(5), id: \.id) { task in
                            TechnicianTaskRow(task: task)
                        }
                        
                        if todaysTasks.count > 5 {
                            NavigationLink(destination: TaskView().environmentObject(authService)) {
                                Text("View All \(todaysTasks.count) Tasks")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Services Section
    private var servicesSection: some View {
        VStack(spacing: isIPad ? 20 : 16) {
            SectionCard(title: "Active Service Jobs") {
                if activeJobs.isEmpty {
                    EmptyStateView(
                        icon: "wrench.and.screwdriver",
                        title: "No Active Jobs",
                        message: "You don't have any active service jobs at the moment."
                    )
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(activeJobs, id: \.id) { job in
                            ServiceJobRow(job: job)
                        }
                    }
                }
            }
            
            SectionCard(title: "Recent Activity") {
                let recentJobs = serviceRecords
                    .prefix(5)
                
                if recentJobs.isEmpty {
                    EmptyStateView(
                        icon: "clock",
                        title: "No Recent Activity",
                        message: "Your recent service history will appear here."
                    )
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(recentJobs), id: \.id) { job in
                            RecentActivityRow(job: job)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Transfers Section
    private var transfersSection: some View {
        VStack(spacing: isIPad ? 20 : 16) {
            SectionCard(title: "Pending Transfers") {
                PendingTransfersView()
                    .environmentObject(authService)
            }
            
            SectionCard(title: "Transfer History") {
                TransferLogView(
                    targetUser: authService.currentUser,
                    title: "My Recent Transfers",
                    itemLimit: 10
                )
                .environmentObject(authService)
            }
        }
    }
    
    // MARK: - Grid Configuration
    private var gridColumns: [GridItem] {
        if isIPad {
            return Array(repeating: GridItem(.flexible(), spacing: 20), count: 4)
        } else {
            return Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)
        }
    }
    
    // MARK: - Helper Functions
    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: Date())
    }
}

// MARK: - Supporting Views
// (Shared components are now in DashboardComponents.swift)

struct TechnicianVehicleRow: View {
    let vehicle: AppVehicle
    
    var body: some View {
        HStack {
            Image(systemName: "car.fill")
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(vehicle.year) \(vehicle.make) \(vehicle.model)")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("License: \(vehicle.licensePlate ?? "N/A")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Mileage: \(vehicle.mileage) miles")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("Active")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(6)
                
                if let inventoryCount = vehicle.stockItems?.count, inventoryCount > 0 {
                    Text("\(inventoryCount) items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct TechnicianTaskRow: View {
    let task: AppTask
    
    var body: some View {
        HStack {
            Image(systemName: priorityIcon(task.priority))
                .foregroundColor(priorityColor(task.priority))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                if !task.taskDescription.isEmpty {
                    Text(task.taskDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(task.status.capitalized)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(statusColor(task.status))
                
                Text(formatDate(task.dueDate))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func priorityIcon(_ priority: String) -> String {
        switch priority.lowercased() {
        case "high": return "exclamationmark.circle.fill"
        case "medium": return "minus.circle.fill"
        case "low": return "circle.fill"
        default: return "circle"
        }
    }
    
    private func priorityColor(_ priority: String) -> Color {
        switch priority.lowercased() {
        case "high": return .red
        case "medium": return .orange
        case "low": return .green
        default: return .gray
        }
    }
    
    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "completed": return .green
        case "in progress": return .blue
        case "pending": return .orange
        default: return .gray
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

struct ServiceJobRow: View {
    let job: AppServiceRecord
    
    var body: some View {
        HStack {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.title3)
                .foregroundColor(.orange)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Service Job")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let vehicle = job.vehicle {
                    Text("\(vehicle.year) \(vehicle.make) \(vehicle.model)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("Started: \(formatDateTime(job.startTime))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(job.status)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                
                if job.laborCost > 0 || job.partsCost > 0 {
                    Text("$\(String(format: "%.2f", job.laborCost + job.partsCost))")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct RecentActivityRow: View {
    let job: AppServiceRecord
    
    var body: some View {
        HStack {
            Image(systemName: job.status == "Completed" ? "checkmark.circle.fill" : "clock.fill")
                .foregroundColor(job.status == "Completed" ? .green : .orange)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Service Activity")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                if let vehicle = job.vehicle {
                    Text("\(vehicle.make) \(vehicle.model)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(job.status)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(formatDate(job.startTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    TechnicianDashboardView()
        .environmentObject(AppAuthService())
        .modelContainer(for: [Vehix.Vehicle.self, Vehix.ServiceRecord.self, StockLocationItem.self], inMemory: true)
} 