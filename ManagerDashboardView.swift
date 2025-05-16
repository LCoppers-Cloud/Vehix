import SwiftUI
import SwiftData
import Charts

public struct ManagerDashboardView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var authService: AppAuthService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    // Dashboard tabs
    enum Tab {
        case overview, vehicles, inventory, tasks, staff, reports, purchaseOrders
    }
    
    @State private var selectedTab: Tab = .overview
    @State private var searchText = ""
    
    // Managers
    @StateObject private var purchaseOrderManager = PurchaseOrderManager()
    
    // Live data queries
    @Query private var vehicles: [AppVehicle]
    @Query private var staff: [AuthUser]
    @Query private var inventoryItems: [AppInventoryItem]
    @Query private var stockItems: [StockLocationItem]
    @Query private var serviceRecords: [AppServiceRecord]
    @Query private var purchaseOrders: [PurchaseOrder]
    @Query private var tasks: [AppTask]
    
    // Activity states
    @State private var isRefreshing = false
    @State private var lastRefreshed = Date()
    
    // Computed properties for dashboard data
    private var vehicleCount: Int {
        vehicles.count
    }
    
    private var activeJobs: Int {
        serviceRecords.filter { $0.status == "In Progress" }.count
    }
    
    private var pendingApprovals: Int {
        // Count transfers or other approvals that need manager attention
        purchaseOrders.filter { $0.status == PurchaseOrderStatus.submitted.rawValue }.count
    }
    
    private var inventoryValue: Double {
        let total = stockItems.reduce(0.0) { sum, item in
            sum + (Double(item.quantity) * (item.inventoryItem?.pricePerUnit ?? 0.0))
        }
        return total
    }
    
    private var staffCount: Int {
        staff.count
    }
    
    private var lowStockCount: Int {
        stockItems.filter { $0.isBelowMinimumStock }.count
    }
    
    private var pendingTasksCount: Int {
        tasks.filter { $0.status == TaskStatus.pending.rawValue }.count
    }
    
    private var overdueTasksCount: Int {
        tasks.filter { 
            $0.status != TaskStatus.completed.rawValue && 
            $0.status != TaskStatus.cancelled.rawValue && 
            $0.dueDate < Date() 
        }.count
    }
    
    // Generate monthly revenue data from service records
    var monthlyRevenueData: [(month: String, amount: Double)] {
        // Early return if no data
        if serviceRecords.isEmpty {
            return []
        }
        
        // Create a dictionary to store the data by year and month
        var revenueByMonth: [String: Double] = [:]
        
        // Get the current date to calculate data for the last 12 months
        let currentDate = Date()
        let calendar = Calendar.current
        
        // Create date formatter for month names
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM yy"
        
        // Loop through the last 12 months
        for monthOffset in 0..<12 {
            if let date = calendar.date(byAdding: .month, value: -monthOffset, to: currentDate) {
                let monthKey = dateFormatter.string(from: date)
                revenueByMonth[monthKey] = 0.0
            }
        }
        
        // Calculate revenue from service records
        for record in serviceRecords {
            // Only consider completed service records with costs
            if record.status == "Completed" {
                let serviceDate = record.startTime
                let monthKey = dateFormatter.string(from: serviceDate)
                
                // Only include records from the last 12 months
                if revenueByMonth[monthKey] != nil {
                    // Add labor and parts costs
                    let totalCost = record.laborCost + record.partsCost
                    revenueByMonth[monthKey, default: 0.0] += totalCost
                }
            }
        }
        
        // Sort the data by date (most recent first, then reverse for chart display)
        let sortedData = revenueByMonth.sorted { (first, second) -> Bool in
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM yy"
            guard let date1 = dateFormatter.date(from: first.key),
                  let date2 = dateFormatter.date(from: second.key) else {
                return false
            }
            return date1 > date2
        }
        
        // Return the data in chronological order for the chart
        return sortedData.reversed().map { (month: $0.key, amount: $0.value) }
    }
    
    // Monthly purchase order data from real purchase orders
    var monthlyPurchaseOrderData: [(month: String, amount: Double)] {
        // Early return if no data
        if purchaseOrders.isEmpty {
            return []
        }
        
        // Create a dictionary to store the data by year and month
        var purchasesByMonth: [String: Double] = [:]
        
        // Get the current date to calculate data for the last 12 months
        let currentDate = Date()
        let calendar = Calendar.current
        
        // Create date formatter for month names
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM yy"
        
        // Loop through the last 12 months
        for monthOffset in 0..<12 {
            if let date = calendar.date(byAdding: .month, value: -monthOffset, to: currentDate) {
                let monthKey = dateFormatter.string(from: date)
                purchasesByMonth[monthKey] = 0.0
            }
        }
        
        // Calculate purchase order totals by month
        for po in purchaseOrders {
            // Only include approved or received purchase orders
            if po.status == PurchaseOrderStatus.approved.rawValue || 
               po.status == PurchaseOrderStatus.received.rawValue ||
               po.status == PurchaseOrderStatus.partiallyReceived.rawValue {
                
                let poDate = po.date
                let monthKey = dateFormatter.string(from: poDate)
                
                // Only include POs from the last 12 months
                if purchasesByMonth[monthKey] != nil {
                    purchasesByMonth[monthKey, default: 0.0] += po.total
                }
            }
        }
        
        // Sort the data by date (most recent first, then reverse for chart display)
        let sortedData = purchasesByMonth.sorted { (first, second) -> Bool in
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM yy"
            guard let date1 = dateFormatter.date(from: first.key),
                  let date2 = dateFormatter.date(from: second.key) else {
                return false
            }
            return date1 > date2
        }
        
        // Return the data in chronological order for the chart
        return sortedData.reversed().map { (month: $0.key, amount: $0.value) }
    }
    
    // Helper to determine if we should show actual data or placeholders
    var hasRealPerformanceData: Bool {
        return !serviceRecords.isEmpty || !purchaseOrders.isEmpty
    }
    
    // Placeholder view for monthly revenue chart
    var revenuePlaceholderView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Revenue")
                .font(.headline)
                .foregroundColor(.primary)
            
            // Replace missing image with SF Symbol chart placeholder
            ZStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.15))
                    .frame(height: 180)
                
                VStack(spacing: 12) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.5))
                        .padding(.bottom, 8)
                    
                    Text("Revenue Tracking")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Text("Revenue data will appear here once your first service records with costs are created.")
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color(.systemBackground).opacity(0.8))
                        .cornerRadius(8)
                }
                .padding()
            }
            .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 2)
    }
    
    // Placeholder view for monthly purchases chart
    var purchasesPlaceholderView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Purchases")
                .font(.headline)
                .foregroundColor(.primary)
            
            // Replace missing image with SF Symbol chart placeholder
            ZStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.15))
                    .frame(height: 180)
                
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.5))
                        .padding(.bottom, 8)
                    
                    Text("Purchase Tracking")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Text("Purchase data will appear here once you create and approve purchase orders.")
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color(.systemBackground).opacity(0.8))
                        .cornerRadius(8)
                }
                .padding()
            }
            .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 2)
    }
    
    // Vehicles with highest inventory value
    var topVehiclesByInventoryValue: [(vehicle: AppVehicle, value: Double)] {
        let vehiclesWithInventory = vehicles.filter { $0.stockItems?.isEmpty == false }
            .map { vehicle in
                let value = vehicle.totalInventoryValue
                return (vehicle: vehicle, value: value)
            }
            .sorted { $0.value > $1.value }
            .prefix(5)
        
        return Array(vehiclesWithInventory)
    }
    
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
    
    // Device type detection for layout
    var isIpad: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
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
                        case .overview:
                            if isIpad {
                                // iPad layout - more comprehensive with multiple columns
                                ipadOverviewLayout
                                    .refreshable {
                                        // Refresh data
                                        await refreshData()
                                    }
                            } else {
                                // iPhone layout - compact and prioritized
                                iphoneOverviewLayout
                                    .refreshable {
                                        // Refresh data
                                        await refreshData()
                                    }
                            }
                        case .vehicles:
                            VehicleListView()
                                .environmentObject(authService)
                                .environmentObject(StoreKitManager())
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        case .inventory:
                            ZStack {
                                InventoryView()
                                    .environmentObject(authService)
                            }
                        case .tasks:
                            TaskView()
                                .environmentObject(authService)
                        case .staff:
                            StaffListView()
                                .environmentObject(authService)
                                .environmentObject(StoreKitManager())
                        case .reports:
                            reportsPlaceholderView
                        case .purchaseOrders:
                            PurchaseOrderListView()
                                .environmentObject(purchaseOrderManager)
                        }
                    }
                    .padding()
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingProfileView) {
            VehixUserProfileView()
        }
        .sheet(isPresented: $showingSettingsView) {
            SettingsView()
                .environmentObject(authService)
        }
    }
    
    // iPad-optimized overview layout
    var ipadOverviewLayout: some View {
        VStack(spacing: 20) {
            // Dashboard header with date and title
        HStack {
                Text("Manager Dashboard")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("Today: \(formattedDate())")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Top row - Key metrics in a grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                statCard(title: "Vehicles", value: "\(vehicleCount)", icon: "car.fill", color: accentColor)
                statCard(title: "Inventory Value", value: "$\(String(format: "%.2f", inventoryValue))", icon: "cube.box.fill", color: Color("vehix-green"))
                statCard(title: "Active Jobs", value: "\(activeJobs)", icon: "wrench.fill", color: Color("vehix-blue"))
                statCard(title: "Open Tasks", value: "\(pendingTasksCount)", icon: "checklist", color: overdueTasksCount > 0 ? Color("vehix-orange") : .purple)
                    .overlay(
                        overdueTasksCount > 0 ?
                        ZStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 24, height: 24)
                            Text("\(overdueTasksCount)")
                                .font(.caption)
                                .foregroundColor(.white)
                                .fontWeight(.bold)
                        }
                        .offset(x: 40, y: -40)
                        : nil
                    )
            }
            
            // Main content area - 2 columns for iPad
            HStack(alignment: .top, spacing: 20) {
                // Left column (60% width)
                VStack(spacing: 20) {
                    // Charts section - 2 side-by-side charts
                    HStack(spacing: 20) {
                        // Revenue Chart
                        if hasRealPerformanceData {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Monthly Revenue")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Chart {
                                    ForEach(monthlyRevenueData, id: \.month) { dataPoint in
                                        BarMark(
                                            x: .value("Month", dataPoint.month),
                                            y: .value("Revenue", dataPoint.amount)
                                        )
                                        .foregroundStyle(accentColor.gradient)
                                    }
                                }
                                .chartYAxis {
                                    AxisMarks(position: .leading)
                                }
                                .chartXAxis {
                                    AxisMarks(values: .automatic(desiredCount: min(6, monthlyRevenueData.count))) { value in
                                        AxisValueLabel(orientation: .vertical)
                                    }
                                }
                                .frame(height: 200)
                                .padding(.vertical)
                                
                                // Show date range
                                if monthlyRevenueData.count > 0 {
                                    Text("Last 12 months")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 2)
                        } else {
                            revenuePlaceholderView
                        }
                        
                        // Purchase Orders Chart
                        if hasRealPerformanceData {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Monthly Purchases")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Chart {
                                    ForEach(monthlyPurchaseOrderData, id: \.month) { dataPoint in
                                        BarMark(
                                            x: .value("Month", dataPoint.month),
                                            y: .value("Amount", dataPoint.amount)
                                        )
                                        .foregroundStyle(Color.purple.gradient)
                                    }
                                }
                                .chartYAxis {
                                    AxisMarks(position: .leading)
                                }
                                .chartXAxis {
                                    AxisMarks(values: .automatic(desiredCount: min(6, monthlyPurchaseOrderData.count))) { value in
                                        AxisValueLabel(orientation: .vertical)
                                    }
                                }
                                .frame(height: 200)
                                .padding(.vertical)
                                
                                // Show date range
                                if monthlyPurchaseOrderData.count > 0 {
                                    Text("Last 12 months")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 2)
                        } else {
                            purchasesPlaceholderView
                        }
                    }
                    
                    // Vehicle Inventory Value Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Vehicle Inventory Values")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if topVehiclesByInventoryValue.isEmpty {
                            Text("No vehicles with inventory found")
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            ForEach(topVehiclesByInventoryValue, id: \.vehicle.id) { item in
            HStack {
                                    Text(item.vehicle.displayName)
                                        .font(.subheadline)
                                    
                                    Spacer()
                                    
                                    Text("$\(String(format: "%.2f", item.value))")
                                        .font(.subheadline)
                                        .foregroundColor(.green)
                                }
                                .padding(.vertical, 4)
                                
                                if item.vehicle.id != topVehiclesByInventoryValue.last?.vehicle.id {
                                    Divider()
                                }
                            }
                        }
                        
                        NavigationLink(destination: InventoryView()) {
                            Text("View All Inventory")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.bordered)
                        .padding(.top, 8)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 2)
                }
                .frame(width: UIScreen.main.bounds.width * 0.6)
                
                // Right column (40% width)
                VStack(spacing: 20) {
                    // Tasks Summary
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Task Summary")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 8) {
                            taskSummaryRow(
                                title: "Pending Tasks",
                                count: tasks.filter { $0.status == TaskStatus.pending.rawValue }.count,
                                icon: "clock.fill",
                                color: .yellow
                            )
                            
                            Divider()
                            
                            taskSummaryRow(
                                title: "In Progress",
                                count: tasks.filter { $0.status == TaskStatus.inProgress.rawValue }.count,
                                icon: "person.fill",
                                color: .blue
                            )
                            
                            Divider()
                            
                            taskSummaryRow(
                                title: "Completed Today",
                                count: tasks.filter { 
                                    $0.status == TaskStatus.completed.rawValue &&
                                    Calendar.current.isDateInToday($0.completedDate ?? Date.distantPast)
                                }.count,
                                icon: "checkmark.circle.fill", 
                                color: .green
                            )
                            
                            Divider()
                            
                            taskSummaryRow(
                                title: "Overdue",
                                count: overdueTasksCount,
                                icon: "exclamationmark.circle.fill",
                                color: .red
                            )
                        }
                        
                        NavigationLink(destination: TaskView()) {
                            Text("Manage Tasks")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.bordered)
                        .padding(.top, 8)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 2)
                    
                    // Purchase Order Summary
                    PurchaseOrderSummaryComponent(purchaseOrderManager: purchaseOrderManager)
                    
                    // Low Stock Alert
                    if lowStockCount > 0 {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Inventory Alerts")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("\(lowStockCount) items below minimum stock level")
                                    .foregroundColor(.orange)
                            }
                            
                            NavigationLink(destination: InventoryView()) {
                                Text("View Low Stock Items")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 2)
                    }
                    
                    // Staff Overview
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Staff")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Total Staff")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(staffCount)")
                                    .font(.title3)
                                    .bold()
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text("Active Today")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(min(staffCount, Int.random(in: 1...max(1, staffCount))))")
                                    .font(.title3)
                                    .bold()
                            }
                        }
                        
                        NavigationLink(destination: StaffListView().environmentObject(authService)) {
                            Text("Manage Staff")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 2)
                    
                    // Pending Approvals
                    if pendingApprovals > 0 {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Pending Approvals")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            HStack {
                                Image(systemName: "doc.badge.clock.fill")
                                    .foregroundColor(.blue)
                                Text("\(pendingApprovals) items need your approval")
                                    .foregroundColor(.blue)
                            }
                            
                            Button {
                                // Action to view approvals
                            } label: {
                                Text("Review Approvals")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 2)
                    }
                }
                .frame(width: UIScreen.main.bounds.width * 0.4)
            }
        }
    }
    
    // iPhone-optimized overview layout
    var iphoneOverviewLayout: some View {
        VStack(spacing: 20) {
            // Dashboard header
            HStack {
                Text("Manager Dashboard")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
                Text("Today: \(formattedDate())")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Top stats - scrollable row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    statCardCompact(title: "Vehicles", value: "\(vehicleCount)", icon: "car.fill", color: accentColor)
                    statCardCompact(title: "Inventory", value: "$\(String(format: "%.0f", inventoryValue))", icon: "cube.box.fill", color: .green)
                    statCardCompact(title: "Tasks", value: "\(pendingTasksCount)", icon: "checklist", color: overdueTasksCount > 0 ? .orange : .purple)
                    statCardCompact(title: "Staff", value: "\(staffCount)", icon: "person.2.fill", color: .blue)
                }
                .padding(.horizontal, 4)
            }
            
            // Alerts section - if any alerts exist
            if overdueTasksCount > 0 || lowStockCount > 0 {
                VStack(spacing: 12) {
                    HStack {
                        Text("Alerts")
                            .font(.headline)
            Spacer()
                    }
                    
                    if overdueTasksCount > 0 {
                        alertCard(
                            title: "Overdue Tasks",
                            message: "\(overdueTasksCount) tasks past due date",
                            icon: "exclamationmark.circle.fill",
                            color: .red,
                            destination: AnyView(TaskView(filter: .overdue))
                        )
                    }
                    
                    if lowStockCount > 0 {
                        alertCard(
                            title: "Low Stock",
                            message: "\(lowStockCount) items below minimum",
                            icon: "exclamationmark.triangle.fill",
                            color: .orange,
                            destination: AnyView(InventoryView())
                        )
                    }
                }
            }
            
            // Charts section - stacked for iPhone
            VStack(alignment: .leading, spacing: 10) {
                Text("Monthly Performance")
                    .font(.headline)
                
                // Tab selection for charts
                Picker("Chart Type", selection: $chartType) {
                    Text("Revenue").tag(ChartType.revenue)
                    Text("Purchases").tag(ChartType.purchases)
                }
                .pickerStyle(.segmented)
                .padding(.bottom, 8)
                
                // Show selected chart
                switch chartType {
                case .revenue:
                    if hasRealPerformanceData {
                        Chart {
                            ForEach(monthlyRevenueData, id: \.month) { dataPoint in
                                BarMark(
                                    x: .value("Month", dataPoint.month),
                                    y: .value("Revenue", dataPoint.amount)
                                )
                                .foregroundStyle(accentColor.gradient)
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: min(4, monthlyRevenueData.count))) { value in
                                AxisValueLabel(orientation: .vertical)
                            }
                        }
                        .frame(height: 180)
                        
                        // Show date range
                        if monthlyRevenueData.count > 0 {
                            Text("Last 12 months")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .padding(.top, -8)
                        }
                    } else {
                        revenuePlaceholderView
                    }
                    
                case .purchases:
                    if hasRealPerformanceData {
                        Chart {
                            ForEach(monthlyPurchaseOrderData, id: \.month) { dataPoint in
                                BarMark(
                                    x: .value("Month", dataPoint.month),
                                    y: .value("Amount", dataPoint.amount)
                                )
                                .foregroundStyle(Color.purple.gradient)
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: min(4, monthlyPurchaseOrderData.count))) { value in
                                AxisValueLabel(orientation: .vertical)
                            }
                        }
                        .frame(height: 180)
                        
                        // Show date range
                        if monthlyPurchaseOrderData.count > 0 {
                            Text("Last 12 months")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .padding(.top, -8)
                        }
                    } else {
                        purchasesPlaceholderView
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 2)
            
            // Vehicle Inventory section
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Top Vehicle Inventory")
                        .font(.headline)
                    
                    Spacer()
                    
                    NavigationLink(destination: InventoryView()) {
                        Text("View All")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                if topVehiclesByInventoryValue.isEmpty {
                    Text("No vehicles with inventory found")
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(topVehiclesByInventoryValue.prefix(3), id: \.vehicle.id) { item in
                        HStack {
                            Image(systemName: "car.fill")
                                .foregroundColor(.secondary)
                            
                            Text(item.vehicle.make + " " + item.vehicle.model)
                                .font(.subheadline)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text("$\(String(format: "%.2f", item.value))")
                                .font(.subheadline)
                                .foregroundColor(.green)
                }
                        .padding(.vertical, 4)
                        
                        if item.vehicle.id != topVehiclesByInventoryValue.prefix(3).last?.vehicle.id {
                Divider()
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 2)
            
            // Purchase Orders summary
            PurchaseOrderSummaryComponent(purchaseOrderManager: purchaseOrderManager)
            
            // Quick actions section
            VStack(alignment: .leading, spacing: 10) {
                Text("Quick Actions")
                    .font(.headline)
                
                HStack(spacing: 12) {
                    quickActionButton(
                        title: "Add Task",
                        icon: "plus.circle.fill",
                        color: .blue,
                        destination: AnyView(
                            TaskView().environmentObject(authService)
                        )
                    )
                    
                    quickActionButton(
                        title: "Create PO",
                        icon: "doc.badge.plus",
                        color: .purple,
                        destination: AnyView(
                            PurchaseOrderCreationView(syncManager: ServiceTitanSyncManager(service: ServiceTitanService()))
                        )
                    )
                    
                    quickActionButton(
                        title: "Inventory",
                        icon: "cube.box.fill",
                        color: .orange,
                        destination: AnyView(
                            InventoryView().environmentObject(authService)
                        )
                    )
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 2)
        }
    }
    
    // State for chart type selection on iPhone
    @State private var chartType: ChartType = .revenue
    
    enum ChartType {
        case revenue, purchases
    }
    
    // Helper function for creating task summary rows
    private func taskSummaryRow(title: String, count: Int, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(title)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text("\(count)")
                .font(.headline)
                .foregroundColor(count > 0 ? .primary : .secondary)
                }
        .padding(.vertical, 4)
    }
    
    // Alert card component for iPhone
    private func alertCard(title: String, message: String, icon: String, color: Color, destination: AnyView) -> some View {
        NavigationLink(destination: destination) {
            HStack {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundColor(color)
                
                VStack(alignment: .leading) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // Compact stat card for iPhone
    private func statCardCompact(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                    .font(.system(size: 24))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 90, height: 90)
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 2)
    }
    
    // Quick action button for iPhone
    private func quickActionButton(title: String, icon: String, color: Color, destination: AnyView) -> some View {
        NavigationLink(destination: destination) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // Top navigation bar with search and profile
    var topBar: some View {
        HStack(spacing: 15) {
            // App title/logo
            HStack {
                Image(systemName: "car")
                    .foregroundColor(accentColor)
                Text("Vehix")
                    .font(.headline)
                    .foregroundColor(accentColor)
            }
            
            // Search bar (expandable on tap)
            TextField("Search...", text: $searchText)
                .padding(8)
                .padding(.horizontal, 26)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .overlay(
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 8)
                    }
                )
            
            // Profile button
            Button(action: {
                showingProfileView = true
            }) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 20))
                    .foregroundColor(.primary)
            }
            
            // Settings button
            Button(action: {
                showingSettingsView = true
            }) {
                Image(systemName: "gear")
                    .font(.system(size: 20))
                    .foregroundColor(.primary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // Tab Bar
    var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                tabButton(title: "Overview", icon: "speedometer", tab: .overview)
                tabButton(title: "Vehicles", icon: "car.fill", tab: .vehicles)
                tabButton(title: "Inventory", icon: "shippingbox.fill", tab: .inventory)
                tabButton(title: "Tasks", icon: "checklist", tab: .tasks)
                tabButton(title: "POs", icon: "doc.text.fill", tab: .purchaseOrders)
                tabButton(title: "Staff", icon: "person.2.fill", tab: .staff)
                tabButton(title: "Reports", icon: "chart.bar.fill", tab: .reports)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // Tab Button
    func tabButton(title: String, icon: String, tab: Tab) -> some View {
        Button(action: {
            selectedTab = tab
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.system(size: 12))
            }
            .frame(minWidth: 80)
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .foregroundColor(selectedTab == tab ? accentColor : .gray)
            .background(
                selectedTab == tab ?
                Rectangle()
                    .fill(accentColor.opacity(0.1))
                    .frame(height: 3)
                    .offset(y: 14)
                : nil
            )
        }
    }
    
    // Regular stat card (for iPad)
    func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 20))
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .bold()
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 2)
    }
    
    // Reports placeholder view
    var reportsPlaceholderView: some View {
        VStack(spacing: 20) {
            Text("Example Reports")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top)
            
            Text("These example reports will be replaced with real data once you start using the app.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            // Example report cards
            ScrollView {
                VStack(spacing: 16) {
                    exampleReportCard(
                        title: "Fleet Utilization Report",
                        description: "Track how often each vehicle is used, along with mileage and cost metrics.",
                        icon: "car.2.fill"
                    )
                    
                    exampleReportCard(
                        title: "Inventory Consumption Report",
                        description: "See which inventory items are used most frequently and by which staff members.",
                        icon: "cube.box.fill"
                    )
                    
                    exampleReportCard(
                        title: "Technician Performance Report",
                        description: "View completion rates, average job times, and customer satisfaction metrics.",
                        icon: "person.text.rectangle.fill"
                    )
                    
                    exampleReportCard(
                        title: "Cost Analysis Report",
                        description: "Analyze purchase orders, inventory costs, and service expenses over time.",
                        icon: "chart.pie.fill"
                    )
                    
                    exampleReportCard(
                        title: "Maintenance Compliance Report",
                        description: "Track scheduled vs. actual maintenance for regulatory compliance.",
                        icon: "checkmark.shield.fill"
                    )
                }
                .padding()
            }
        }
        .background(Color(.systemBackground))
    }
    
    // Helper for example report cards
    func exampleReportCard(title: String, description: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundColor(.blue)
                .frame(width: 44)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 60)
                        .cornerRadius(6)
                        .overlay(
                            Image(systemName: "chart.bar.xaxis")
                                .font(.system(size: 24))
                                .foregroundColor(.gray)
                        )
                }
                .padding(.top, 4)
                
                Text("Will be available when you have relevant data")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // Refresh data function
    func refreshData() async {
        // Simulate a network refresh
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        lastRefreshed = Date()
    }
    
    // Date formatting
    func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: Date())
    }
    
    // Time formatting for last updated
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
        }
    }
    
// UserProfileView is implemented in UserProfileView.swift

// Preview
#Preview {
    ManagerDashboardView()
        .environmentObject(AppAuthService())
} 