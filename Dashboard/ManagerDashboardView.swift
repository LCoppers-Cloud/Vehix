import SwiftUI
import SwiftData
import Charts

public struct ManagerDashboardView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var authService: AppAuthService
    @EnvironmentObject var storeKitManager: StoreKitManager
    @EnvironmentObject var samsaraService: SamsaraService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    // Sheet presentation manager
    @StateObject private var sheetManager = SheetPresentationManager()
    
    // Unified data queries - same as inventory system
    @Query(sort: [SortDescriptor(\Vehix.InventoryItem.name)]) private var allInventoryItems: [AppInventoryItem]
    @Query(sort: [SortDescriptor(\StockLocationItem.createdAt, order: .reverse)]) private var stockLocations: [StockLocationItem]
    @Query(sort: [SortDescriptor(\AppWarehouse.name)]) private var warehouses: [AppWarehouse]
    @Query(sort: [SortDescriptor(\Vehix.Vehicle.licensePlate)]) private var vehicles: [AppVehicle]
    @Query(sort: [SortDescriptor(\Vehix.ServiceRecord.startTime, order: .reverse)]) private var serviceRecords: [AppServiceRecord]
    @Query(sort: [SortDescriptor(\PurchaseOrder.createdAt, order: .reverse)]) private var purchaseOrders: [PurchaseOrder]
    @Query(sort: [SortDescriptor(\AppTask.dueDate)]) private var tasks: [AppTask]
    @Query(sort: [SortDescriptor(\AuthUser.fullName)]) private var staff: [AuthUser]
    
    // State
    @State private var isRefreshing = false
    @State private var selectedTimeframe: Timeframe = .month
    @State private var financialManager = FinancialTrackingManager()
    @State private var settingsManager = AppSettingsManager()
    
    enum Timeframe: String, CaseIterable {
        case week = "Week"
        case month = "Month" 
        case quarter = "Quarter"
        case year = "Year"
    }
    
    // Computed properties using unified inventory system
    private var inventoryStatuses: [InventoryItemStatus] {
        return allInventoryItems.toInventoryStatuses(with: stockLocations)
    }
    
    private var totalInventoryValue: Double {
        inventoryStatuses.reduce(0.0) { $0 + $1.totalValue }
    }
    
    private var vehicleInventoryValue: Double {
        stockLocations
            .filter { $0.vehicle != nil }
            .reduce(0.0) { total, stock in
                let itemValue = stock.inventoryItem?.pricePerUnit ?? 0.0
                return total + (itemValue * Double(stock.quantity))
            }
    }
    
    private var monthlyPOSpending: Double {
        let calendar = Calendar.current
        let now = Date()
        return purchaseOrders
            .filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
            .reduce(0.0) { $0 + $1.total }
    }
    
    private var lowStockCount: Int {
        inventoryStatuses.filter { $0.status == .lowStock || $0.status == .outOfStock }.count
    }
    
    private var activeJobsCount: Int {
        serviceRecords.filter { $0.status == "In Progress" }.count
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
    
    // Device detection
    private var isIPad: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }
    
    // Financial visibility check
    private var shouldShowFinancialSection: Bool {
        guard let userRole = authService.currentUser?.userRole else { return false }
        
        // Always show for admin/dealer
        if userRole == .admin || userRole == .dealer {
            return settingsManager.settings?.enableExecutiveFinancialSection ?? true
        }
        
        // For premium users (managers), check settings
        return settingsManager.canUserSeeFinancialData(userRole: userRole) &&
               (settingsManager.settings?.enableExecutiveFinancialSection ?? false)
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: isIPad ? 24 : 16) {
                    // Header
                    headerSection
                    
                    // Key metrics
                    keyMetricsSection
                    
                    // Charts section
                    chartsSection
                    
                    // Inventory status
                    inventoryStatusSection
                    
                    // Tasks and alerts
                    tasksAndAlertsSection
                    
                    // Executive financial section (based on settings and role)
                    if shouldShowFinancialSection {
                        executiveFinancialSection
                    }
                    
                    // Quick actions
                    quickActionsSection
                }
                .padding(isIPad ? 24 : 16)
            }
            .navigationBarHidden(true)
            .refreshable {
                await refreshData()
            }
        }
        .environmentObject(sheetManager)
        .sheet(isPresented: $sheetManager.isSheetPresented) {
            if let currentSheet = sheetManager.currentSheet {
                CoordinatedSheetView(sheetType: currentSheet)
                    .environmentObject(sheetManager)
                    .environmentObject(authService)
                    .environmentObject(storeKitManager)
                    .environmentObject(samsaraService)
            }
        }
        .onAppear {
            financialManager.setModelContext(modelContext)
            settingsManager.setModelContext(modelContext)
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
                    // Purchase Order button (for managers and admins only)
                    if authService.currentUser?.userRole == .admin || authService.currentUser?.userRole == .dealer {
                        Button(action: { sheetManager.requestPresentation(.purchaseOrder) }) {
                            Image(systemName: "doc.badge.plus")
                                .font(.title3)
                                .foregroundColor(.purple)
                        }
                    }
                    
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
                    Text("Manager Dashboard")
                        .font(isIPad ? .largeTitle : .title2)
                        .fontWeight(.bold)
                    
                    Text("Today: \(formattedDate())")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Timeframe picker
                Picker("Timeframe", selection: $selectedTimeframe) {
                    ForEach(Timeframe.allCases, id: \.self) { timeframe in
                        Text(timeframe.rawValue).tag(timeframe)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: isIPad ? 300 : 200)
            }
        }
    }
    
    // MARK: - Key Metrics Section
    private var keyMetricsSection: some View {
        LazyVGrid(columns: gridColumns, spacing: isIPad ? 20 : 12) {
            MetricCard(
                title: "Fleet Size",
                value: "\(vehicles.count)",
                subtitle: "Active Vehicles",
                icon: "car.2.fill",
                color: .blue,
                trend: .neutral
            )
            
            MetricCard(
                title: "Total Inventory",
                value: formatCurrency(totalInventoryValue),
                subtitle: "\(allInventoryItems.count) Items",
                icon: "cube.box.fill",
                color: .green,
                trend: .up
            )
            
            MetricCard(
                title: "Vehicle Inventory",
                value: formatCurrency(vehicleInventoryValue),
                subtitle: "On Vehicles",
                icon: "car.2.fill",
                color: .blue,
                trend: .neutral
            )
            
            MetricCard(
                title: "Monthly PO Spending",
                value: formatCurrency(monthlyPOSpending),
                subtitle: "This Month",
                icon: "doc.text.fill",
                color: .orange,
                trend: .neutral
            )
            
            MetricCard(
                title: "Active Jobs",
                value: "\(activeJobsCount)",
                subtitle: "In Progress",
                icon: "wrench.and.screwdriver.fill",
                color: .orange,
                trend: .neutral
            )
            
            MetricCard(
                title: "Staff",
                value: "\(staff.count)",
                subtitle: "Team Members",
                icon: "person.2.fill",
                color: .purple,
                trend: .neutral
            )
            
            if lowStockCount > 0 {
                MetricCard(
                    title: "Low Stock",
                    value: "\(lowStockCount)",
                    subtitle: "Need Attention",
                    icon: "exclamationmark.triangle.fill",
                    color: .red,
                    trend: .down
                )
            }
            
            if overdueTasksCount > 0 {
                MetricCard(
                    title: "Overdue Tasks",
                    value: "\(overdueTasksCount)",
                    subtitle: "Past Due",
                    icon: "clock.badge.exclamationmark.fill",
                    color: .red,
                    trend: .down
                )
            }
        }
    }
    
    // MARK: - Charts Section
    private var chartsSection: some View {
        VStack(spacing: isIPad ? 20 : 16) {
            if isIPad {
                // iPad: Side-by-side charts
                HStack(spacing: 20) {
                    inventoryValueChart
                    monthlyRevenueChart
                }
            } else {
                // iPhone: Stacked charts
                inventoryValueChart
                monthlyRevenueChart
            }
        }
    }
    
    private var inventoryValueChart: some View {
        ChartCard(title: "Inventory by Category") {
            Chart {
                ForEach(inventoryByCategory, id: \.category) { data in
                    SectorMark(
                        angle: .value("Value", data.value),
                        innerRadius: .ratio(0.4),
                        angularInset: 2
                    )
                    .foregroundStyle(by: .value("Category", data.category))
                    .cornerRadius(4)
                }
            }
            .frame(height: isIPad ? 200 : 150)
            .chartLegend(position: .bottom, alignment: .center)
        }
    }
    
    private var monthlyRevenueChart: some View {
        ChartCard(title: "Monthly Performance") {
            Chart {
                ForEach(monthlyPerformanceData, id: \.month) { data in
                    BarMark(
                        x: .value("Month", data.month),
                        y: .value("Revenue", data.revenue)
                    )
                    .foregroundStyle(.blue.gradient)
                    
                    LineMark(
                        x: .value("Month", data.month),
                        y: .value("Costs", data.costs)
                    )
                    .foregroundStyle(.red)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    .symbol(Circle().strokeBorder(lineWidth: 2))
                }
            }
            .frame(height: isIPad ? 200 : 150)
            .chartYAxis {
                AxisMarks(format: .currency(code: "USD"))
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: isIPad ? 6 : 4))
            }
        }
    }
    
    // MARK: - Inventory Status Section
    private var inventoryStatusSection: some View {
        ChartCard(title: "Inventory Status Overview") {
            VStack(spacing: 16) {
                // Status summary
                LazyVGrid(columns: statusGridColumns, spacing: 12) {
                    StatusCard(
                        title: "In Stock",
                        count: inventoryStatuses.filter { $0.status == .inStock }.count,
                        color: .green,
                        icon: "checkmark.circle.fill"
                    )
                    
                    StatusCard(
                        title: "Low Stock",
                        count: inventoryStatuses.filter { $0.status == .lowStock }.count,
                        color: .orange,
                        icon: "exclamationmark.triangle.fill"
                    )
                    
                    StatusCard(
                        title: "Out of Stock",
                        count: inventoryStatuses.filter { $0.status == .outOfStock }.count,
                        color: .red,
                        icon: "xmark.circle.fill"
                    )
                    
                    StatusCard(
                        title: "Overstocked",
                        count: inventoryStatuses.filter { $0.status == .overStock }.count,
                        color: .yellow,
                        icon: "arrow.up.circle.fill"
                    )
                }
                
                // Quick action
                NavigationLink(destination: InventoryView().environmentObject(authService)) {
                    Text("View Full Inventory")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .cornerRadius(12)
                }
            }
        }
    }
    
    // MARK: - Tasks and Alerts Section
    private var tasksAndAlertsSection: some View {
        VStack(spacing: isIPad ? 20 : 16) {
            if isIPad {
                HStack(spacing: 20) {
                    tasksCard
                    alertsCard
                }
            } else {
                tasksCard
                if lowStockCount > 0 || overdueTasksCount > 0 {
                    alertsCard
                }
            }
        }
    }
    
    private var tasksCard: some View {
        ChartCard(title: "Task Summary") {
            VStack(spacing: 12) {
                DashboardTaskRow(
                    title: "Pending",
                    count: pendingTasksCount,
                    icon: "clock.fill",
                    color: .yellow
                )
                
                DashboardTaskRow(
                    title: "In Progress",
                    count: tasks.filter { $0.status == TaskStatus.inProgress.rawValue }.count,
                    icon: "person.fill",
                    color: .blue
                )
                
                DashboardTaskRow(
                    title: "Completed Today",
                    count: tasks.filter { 
                        $0.status == TaskStatus.completed.rawValue &&
                        Calendar.current.isDateInToday($0.completedDate ?? Date.distantPast)
                    }.count,
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                
                if overdueTasksCount > 0 {
                    DashboardTaskRow(
                        title: "Overdue",
                        count: overdueTasksCount,
                        icon: "exclamationmark.circle.fill",
                        color: .red
                    )
                }
                
                NavigationLink(destination: TaskView().environmentObject(authService)) {
                    Text("Manage Tasks")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .cornerRadius(12)
                }
            }
        }
    }
    
    private var alertsCard: some View {
        ChartCard(title: "Alerts & Notifications") {
            VStack(spacing: 12) {
                if lowStockCount > 0 {
                    AlertRow(
                        title: "Low Stock Items",
                        message: "\(lowStockCount) items below minimum",
                        icon: "exclamationmark.triangle.fill",
                        color: .orange
                    )
                }
                
                if overdueTasksCount > 0 {
                    AlertRow(
                        title: "Overdue Tasks",
                        message: "\(overdueTasksCount) tasks past due",
                        icon: "clock.badge.exclamationmark.fill",
                        color: .red
                    )
                }
                
                let pendingPOs = purchaseOrders.filter { $0.status == PurchaseOrderStatus.submitted.rawValue }.count
                if pendingPOs > 0 {
                    AlertRow(
                        title: "Pending Approvals",
                        message: "\(pendingPOs) purchase orders need approval",
                        icon: "doc.badge.clock.fill",
                        color: .blue
                    )
                }
                
                if lowStockCount == 0 && overdueTasksCount == 0 && pendingPOs == 0 {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("All systems running smoothly")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
            }
        }
    }
    
    // MARK: - Executive Financial Section
    private var executiveFinancialSection: some View {
        ChartCard(title: "Executive Financial Overview") {
            VStack(spacing: 16) {
                // Financial summary
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Financial Summary")
                            .font(.headline)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Vehicle Inventory Value")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(formatCurrency(vehicleInventoryValue))
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Monthly PO Spending")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(formatCurrency(monthlyPOSpending))
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Average Vehicle Value")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(formatCurrency(vehicles.isEmpty ? 0.0 : vehicleInventoryValue / Double(vehicles.count)))
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Quarterly Spending")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(formatCurrency(quarterlyPOSpending))
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.purple)
                            }
                        }
                    }
                    
                    Spacer()
                }
                
                Divider()
                
                // Action buttons
                HStack(spacing: 12) {
                    Button(action: { sheetManager.requestPresentation(.reports) }) {
                        HStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                            Text("Full Financial Dashboard")
                        }
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.blue)
                        .cornerRadius(8)
                    }
                    
                    NavigationLink(destination: AdvancedReportsView(inventoryItems: inventoryStatuses).environmentObject(authService)) {
                        HStack {
                            Image(systemName: "doc.text.magnifyingglass")
                            Text("Detailed Reports")
                        }
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.green)
                        .cornerRadius(8)
                    }
                }
            }
        }
    }
    
    private var quarterlyPOSpending: Double {
        let calendar = Calendar.current
        let now = Date()
        return purchaseOrders
            .filter { 
                let monthsAgo = calendar.dateInterval(of: .quarter, for: now)
                return monthsAgo?.contains($0.date) ?? false
            }
            .reduce(0.0) { $0 + $1.total }
    }
    
    // MARK: - Quick Actions Section
    private var quickActionsSection: some View {
        ChartCard(title: "Quick Actions") {
            LazyVGrid(columns: quickActionColumns, spacing: 12) {
                QuickActionButton(
                    title: "Add Vehicle",
                    icon: "plus.circle.fill",
                    color: .blue,
                    destination: AnyView(AddVehicleForm().environmentObject(authService))
                )
                
                QuickActionButton(
                    title: "Vehicle Management",
                    icon: "car.2.fill",
                    color: .blue,
                    destination: AnyView(VehicleManagementView().environmentObject(authService).environmentObject(storeKitManager))
                )
                
                QuickActionButton(
                    title: "Vehicle Locations",
                    icon: "mappin.and.ellipse",
                    color: .green,
                    destination: AnyView(VehicleLocationMapView().environmentObject(authService).environmentObject(samsaraService))
                )
                
                QuickActionButton(
                    title: "Create Task",
                    icon: "plus.square.fill",
                    color: .green,
                    destination: AnyView(TaskView().environmentObject(authService))
                )
                
                QuickActionButton(
                    title: "Purchase Order",
                    icon: "doc.badge.plus",
                    color: .purple,
                    destination: AnyView(PurchaseOrderListView())
                )
                
                QuickActionButton(
                    title: "Add Inventory",
                    icon: "cube.box.fill",
                    color: .orange,
                    destination: AnyView(AddInventoryItemForm().environment(\.modelContext, modelContext))
                )
                
                QuickActionButton(
                    title: "Reports",
                    icon: "chart.bar.fill",
                    color: .indigo,
                    destination: AnyView(AdvancedReportsView(inventoryItems: inventoryStatuses).environmentObject(authService))
                )
                
                QuickActionButton(
                    title: "Staff",
                    icon: "person.2.fill",
                    color: .teal,
                    destination: AnyView(StaffListView().environmentObject(authService).environmentObject(StoreKitManager()))
                )
                
                // Financial Settings (owner/admin only)
                if authService.currentUser?.userRole == .admin || authService.currentUser?.userRole == .dealer {
                    QuickActionButton(
                        title: "Financial Settings",
                        icon: "gear.circle.fill",
                        color: .purple,
                        destination: AnyView(FinancialSettingsView().environmentObject(authService))
                    )
                }
                
                // Export Data
                QuickActionButton(
                    title: "Export Data",
                    icon: "square.and.arrow.up.fill",
                    color: .indigo,
                    destination: AnyView(ExportView().environmentObject(authService))
                )
            }
        }
    }
    
    // MARK: - Grid Configurations
    private var gridColumns: [GridItem] {
        if isIPad {
            return Array(repeating: GridItem(.flexible(), spacing: 20), count: 4)
        } else {
            return Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)
        }
    }
    
    private var statusGridColumns: [GridItem] {
        if isIPad {
            return Array(repeating: GridItem(.flexible(), spacing: 16), count: 4)
        } else {
            return Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)
        }
    }
    
    private var quickActionColumns: [GridItem] {
        if isIPad {
            return Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)
        } else {
            return Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)
        }
    }
    
    // MARK: - Data Computation
    private var inventoryByCategory: [(category: String, value: Double)] {
        let categoryTotals = Dictionary(grouping: inventoryStatuses, by: { $0.item.category })
            .mapValues { items in
                items.reduce(0.0) { $0 + $1.totalValue }
            }
        
        return categoryTotals.map { (category: $0.key, value: $0.value) }
            .sorted { $0.value > $1.value }
    }
    
    private var monthlyPerformanceData: [(month: String, revenue: Double, costs: Double)] {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM"
        
        return (0..<6).compactMap { monthOffset in
            guard let date = calendar.date(byAdding: .month, value: -monthOffset, to: Date()) else { return nil }
            
            let monthString = dateFormatter.string(from: date)
            
            // Calculate revenue from completed service records
            let monthRevenue = serviceRecords
                .filter { 
                    $0.status == "Completed" && 
                    calendar.isDate($0.startTime, equalTo: date, toGranularity: .month)
                }
                .reduce(0.0) { $0 + $1.laborCost + $1.partsCost }
            
            // Calculate costs from purchase orders
            let monthCosts = purchaseOrders
                .filter {
                    ($0.status == PurchaseOrderStatus.approved.rawValue || 
                     $0.status == PurchaseOrderStatus.received.rawValue) &&
                    calendar.isDate($0.date, equalTo: date, toGranularity: .month)
                }
                .reduce(0.0) { $0 + $1.total }
            
            return (month: monthString, revenue: monthRevenue, costs: monthCosts)
        }.reversed()
    }
    
    // MARK: - Helper Functions
    private func refreshData() async {
        isRefreshing = true
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        isRefreshing = false
    }
    
    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: Date())
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}

// MARK: - Supporting Views
// (Shared components are now in DashboardComponents.swift)

#Preview {
    ManagerDashboardView()
        .environmentObject(AppAuthService())
        .environmentObject(SamsaraService())
        .modelContainer(for: [Vehix.InventoryItem.self, StockLocationItem.self, AppWarehouse.self, Vehix.Vehicle.self, Vehix.ServiceRecord.self, PurchaseOrder.self], inMemory: true)
} 