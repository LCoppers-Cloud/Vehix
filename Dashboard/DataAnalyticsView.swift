import SwiftUI
import SwiftData
import Charts

struct DataAnalyticsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authService: AppAuthService
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    // Data queries
    @Query(sort: [SortDescriptor(\Vehix.InventoryItem.name)]) private var allInventoryItems: [AppInventoryItem]
    @Query(sort: [SortDescriptor(\StockLocationItem.createdAt, order: .reverse)]) private var stockLocations: [StockLocationItem]
    @Query(sort: [SortDescriptor(\AppWarehouse.name)]) private var warehouses: [AppWarehouse]
    @Query(sort: [SortDescriptor(\Vehix.Vehicle.licensePlate)]) private var vehicles: [AppVehicle]
    @Query(sort: [SortDescriptor(\Vehix.ServiceRecord.startTime, order: .reverse)]) private var serviceRecords: [AppServiceRecord]
    @Query(sort: [SortDescriptor(\PurchaseOrder.createdAt, order: .reverse)]) private var purchaseOrders: [PurchaseOrder]
    @Query(sort: [SortDescriptor(\AppTask.dueDate)]) private var tasks: [AppTask]
    @Query(sort: [SortDescriptor(\AuthUser.fullName)]) private var staff: [AuthUser]
    @Query(sort: [SortDescriptor(\VehicleAssignment.startDate, order: .reverse)]) private var vehicleAssignments: [VehicleAssignment]
    
    // State
    @State private var selectedTimeframe: Timeframe = .month
    @State private var selectedMetricCategory: MetricCategory = .overview
    @State private var showingExportOptions = false
    
    enum Timeframe: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case quarter = "Quarter"
        case year = "Year"
    }
    
    enum MetricCategory: String, CaseIterable {
        case overview = "Overview"
        case inventory = "Inventory"
        case vehicles = "Vehicles"
        case financial = "Financial"
        case productivity = "Productivity"
    }
    
    // Device detection
    private var isIPad: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }
    
    // Computed properties
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
    
    private var warehouseInventoryValue: Double {
        stockLocations
            .filter { $0.warehouse != nil }
            .reduce(0.0) { total, stock in
                let itemValue = stock.inventoryItem?.pricePerUnit ?? 0.0
                return total + (itemValue * Double(stock.quantity))
            }
    }
    
    private var lowStockCount: Int {
        inventoryStatuses.filter { $0.status == .lowStock || $0.status == .outOfStock }.count
    }
    
    private var activeJobsCount: Int {
        serviceRecords.filter { $0.status == "In Progress" }.count
    }
    
    private var completedJobsCount: Int {
        serviceRecords.filter { $0.status == "Completed" }.count
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
    
    private var averageJobCompletionTime: Double {
        let completedJobs = serviceRecords.filter { $0.status == "Completed" && $0.endTime != nil }
        guard !completedJobs.isEmpty else { return 0 }
        
        let totalHours = completedJobs.reduce(0.0) { total, job in
            guard let endTime = job.endTime else { return total }
            let duration = endTime.timeIntervalSince(job.startTime) / 3600 // Convert to hours
            return total + duration
        }
        
        return totalHours / Double(completedJobs.count)
    }
    
    private var vehicleUtilizationRate: Double {
        let assignedVehicles = vehicleAssignments.filter { $0.endDate == nil }.count
        guard vehicles.count > 0 else { return 0 }
        return Double(assignedVehicles) / Double(vehicles.count) * 100
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: isIPad ? 24 : 16) {
                    // Header with timeframe picker
                    headerSection
                    
                    // Metric category picker
                    categoryPickerSection
                    
                    // Content based on selected category
                    switch selectedMetricCategory {
                    case .overview:
                        overviewSection
                    case .inventory:
                        inventorySection
                    case .vehicles:
                        vehiclesSection
                    case .financial:
                        financialSection
                    case .productivity:
                        productivitySection
                    }
                }
                .padding(isIPad ? 24 : 16)
            }
            .navigationTitle("Data & Analytics")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingExportOptions = true }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(isPresented: $showingExportOptions) {
            DataExportView()
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Business Intelligence")
                        .font(isIPad ? .title : .title2)
                        .fontWeight(.bold)
                    
                    Text("Data-driven insights for your business")
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
    
    // MARK: - Category Picker Section
    private var categoryPickerSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(MetricCategory.allCases, id: \.self) { category in
                    Button(action: { selectedMetricCategory = category }) {
                        Text(category.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                selectedMetricCategory == category 
                                ? Color.blue 
                                : Color(.systemGray6)
                            )
                            .foregroundColor(
                                selectedMetricCategory == category 
                                ? .white 
                                : .primary
                            )
                            .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Overview Section
    private var overviewSection: some View {
        VStack(spacing: isIPad ? 20 : 16) {
            // Key metrics grid
            LazyVGrid(columns: gridColumns, spacing: isIPad ? 20 : 12) {
                DataMetricCard(
                    title: "Total Inventory Value",
                    value: formatCurrency(totalInventoryValue),
                    subtitle: "\(allInventoryItems.count) items",
                    icon: "cube.box.fill",
                    color: .green,
                    trend: .up,
                    trendValue: "+5.2%"
                )
                
                DataMetricCard(
                    title: "Fleet Size",
                    value: "\(vehicles.count)",
                    subtitle: "\(Int(vehicleUtilizationRate))% utilized",
                    icon: "car.2.fill",
                    color: .blue,
                    trend: vehicleUtilizationRate > 80 ? .up : .neutral,
                    trendValue: "\(Int(vehicleUtilizationRate))%"
                )
                
                DataMetricCard(
                    title: "Active Jobs",
                    value: "\(activeJobsCount)",
                    subtitle: "\(completedJobsCount) completed",
                    icon: "wrench.and.screwdriver.fill",
                    color: .orange,
                    trend: .neutral,
                    trendValue: nil
                )
                
                DataMetricCard(
                    title: "Team Members",
                    value: "\(staff.count)",
                    subtitle: "Active staff",
                    icon: "person.2.fill",
                    color: .purple,
                    trend: .neutral,
                    trendValue: nil
                )
            }
            
            // Quick insights
            quickInsightsSection
        }
    }
    
    // MARK: - Inventory Section
    private var inventorySection: some View {
        VStack(spacing: isIPad ? 20 : 16) {
            // Inventory metrics
            LazyVGrid(columns: gridColumns, spacing: isIPad ? 20 : 12) {
                DataMetricCard(
                    title: "Vehicle Inventory",
                    value: formatCurrency(vehicleInventoryValue),
                    subtitle: "On vehicles",
                    icon: "car.fill",
                    color: .blue,
                    trend: .neutral,
                    trendValue: nil
                )
                
                DataMetricCard(
                    title: "Warehouse Inventory",
                    value: formatCurrency(warehouseInventoryValue),
                    subtitle: "In warehouses",
                    icon: "building.2.fill",
                    color: .green,
                    trend: .neutral,
                    trendValue: nil
                )
                
                DataMetricCard(
                    title: "Low Stock Items",
                    value: "\(lowStockCount)",
                    subtitle: "Need attention",
                    icon: "exclamationmark.triangle.fill",
                    color: lowStockCount > 0 ? .red : .green,
                    trend: lowStockCount > 0 ? .down : .up,
                    trendValue: nil
                )
                
                DataMetricCard(
                    title: "Categories",
                    value: "\(Set(allInventoryItems.map(\.category)).count)",
                    subtitle: "Item types",
                    icon: "tag.fill",
                    color: .indigo,
                    trend: .neutral,
                    trendValue: nil
                )
            }
            
            // Inventory charts
            inventoryChartsSection
        }
    }
    
    // MARK: - Vehicles Section
    private var vehiclesSection: some View {
        VStack(spacing: isIPad ? 20 : 16) {
            // Vehicle metrics
            LazyVGrid(columns: gridColumns, spacing: isIPad ? 20 : 12) {
                DataMetricCard(
                    title: "Utilization Rate",
                    value: "\(Int(vehicleUtilizationRate))%",
                    subtitle: "Vehicles assigned",
                    icon: "gauge.high",
                    color: vehicleUtilizationRate > 80 ? .green : .orange,
                    trend: vehicleUtilizationRate > 80 ? .up : .neutral,
                    trendValue: nil
                )
                
                DataMetricCard(
                    title: "Avg Mileage",
                    value: "\(Int(vehicles.map(\.mileage).reduce(0, +) / vehicles.count))",
                    subtitle: "Miles per vehicle",
                    icon: "speedometer",
                    color: .blue,
                    trend: .neutral,
                    trendValue: nil
                )
                
                DataMetricCard(
                    title: "Active Assignments",
                    value: "\(vehicleAssignments.filter { $0.endDate == nil }.count)",
                    subtitle: "Current assignments",
                    icon: "person.crop.circle.badge.checkmark",
                    color: .green,
                    trend: .neutral,
                    trendValue: nil
                )
                
                DataMetricCard(
                    title: "Service Records",
                    value: "\(serviceRecords.count)",
                    subtitle: "Total records",
                    icon: "wrench.and.screwdriver",
                    color: .orange,
                    trend: .neutral,
                    trendValue: nil
                )
            }
            
            // Vehicle charts
            vehicleChartsSection
        }
    }
    
    // MARK: - Financial Section
    private var financialSection: some View {
        VStack(spacing: isIPad ? 20 : 16) {
            // Financial metrics
            LazyVGrid(columns: gridColumns, spacing: isIPad ? 20 : 12) {
                DataMetricCard(
                    title: "Monthly PO Spending",
                    value: formatCurrency(monthlyPOSpending),
                    subtitle: "This month",
                    icon: "doc.text.fill",
                    color: .orange,
                    trend: .neutral,
                    trendValue: nil
                )
                
                DataMetricCard(
                    title: "Quarterly Spending",
                    value: formatCurrency(quarterlyPOSpending),
                    subtitle: "This quarter",
                    icon: "chart.bar.fill",
                    color: .purple,
                    trend: .neutral,
                    trendValue: nil
                )
                
                DataMetricCard(
                    title: "Avg Job Value",
                    value: formatCurrency(averageJobValue),
                    subtitle: "Per service",
                    icon: "dollarsign.circle.fill",
                    color: .green,
                    trend: .neutral,
                    trendValue: nil
                )
                
                DataMetricCard(
                    title: "Cost per Vehicle",
                    value: formatCurrency(costPerVehicle),
                    subtitle: "Monthly average",
                    icon: "car.circle.fill",
                    color: .blue,
                    trend: .neutral,
                    trendValue: nil
                )
            }
            
            // Financial charts
            financialChartsSection
        }
    }
    
    // MARK: - Productivity Section
    private var productivitySection: some View {
        VStack(spacing: isIPad ? 20 : 16) {
            // Productivity metrics
            LazyVGrid(columns: gridColumns, spacing: isIPad ? 20 : 12) {
                DataMetricCard(
                    title: "Avg Completion Time",
                    value: "\(String(format: "%.1f", averageJobCompletionTime))h",
                    subtitle: "Per job",
                    icon: "clock.fill",
                    color: .blue,
                    trend: .neutral,
                    trendValue: nil
                )
                
                DataMetricCard(
                    title: "Task Completion Rate",
                    value: "\(Int(taskCompletionRate))%",
                    subtitle: "On-time tasks",
                    icon: "checkmark.circle.fill",
                    color: taskCompletionRate > 80 ? .green : .orange,
                    trend: taskCompletionRate > 80 ? .up : .down,
                    trendValue: nil
                )
                
                DataMetricCard(
                    title: "Overdue Tasks",
                    value: "\(overdueTasksCount)",
                    subtitle: "Past due",
                    icon: "exclamationmark.triangle.fill",
                    color: overdueTasksCount > 0 ? .red : .green,
                    trend: overdueTasksCount > 0 ? .down : .up,
                    trendValue: nil
                )
                
                DataMetricCard(
                    title: "Jobs per Technician",
                    value: "\(String(format: "%.1f", jobsPerTechnician))",
                    subtitle: "Average workload",
                    icon: "person.fill.checkmark",
                    color: .purple,
                    trend: .neutral,
                    trendValue: nil
                )
            }
            
            // Productivity charts
            productivityChartsSection
        }
    }
    
    // MARK: - Supporting Sections
    private var quickInsightsSection: some View {
        ChartCard(title: "Quick Insights") {
            VStack(alignment: .leading, spacing: 12) {
                InsightRow(
                    icon: "lightbulb.fill",
                    title: "Inventory Optimization",
                    description: lowStockCount > 0 ? 
                        "\(lowStockCount) items need restocking" : 
                        "All inventory levels are healthy",
                    color: lowStockCount > 0 ? .orange : .green
                )
                
                InsightRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Fleet Utilization",
                    description: vehicleUtilizationRate > 80 ? 
                        "High utilization - consider expanding fleet" : 
                        "Fleet capacity available for growth",
                    color: vehicleUtilizationRate > 80 ? .blue : .green
                )
                
                InsightRow(
                    icon: "clock.badge.checkmark",
                    title: "Task Management",
                    description: overdueTasksCount > 0 ? 
                        "\(overdueTasksCount) overdue tasks need attention" : 
                        "All tasks are on schedule",
                    color: overdueTasksCount > 0 ? .red : .green
                )
            }
        }
    }
    
    private var inventoryChartsSection: some View {
        VStack(spacing: isIPad ? 20 : 16) {
            ChartCard(title: "Inventory Distribution") {
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
    }
    
    private var vehicleChartsSection: some View {
        VStack(spacing: isIPad ? 20 : 16) {
            ChartCard(title: "Vehicle Age Distribution") {
                Chart {
                    ForEach(vehicleAgeDistribution, id: \.ageRange) { data in
                        BarMark(
                            x: .value("Age Range", data.ageRange),
                            y: .value("Count", data.count)
                        )
                        .foregroundStyle(.blue)
                        .cornerRadius(4)
                    }
                }
                .frame(height: isIPad ? 200 : 150)
            }
        }
    }
    
    private var financialChartsSection: some View {
        VStack(spacing: isIPad ? 20 : 16) {
            ChartCard(title: "Monthly Spending Trend") {
                Chart {
                    ForEach(monthlySpendingData, id: \.month) { data in
                        LineMark(
                            x: .value("Month", data.month),
                            y: .value("Spending", data.spending)
                        )
                        .foregroundStyle(.orange)
                        .lineStyle(StrokeStyle(lineWidth: 3))
                        
                        PointMark(
                            x: .value("Month", data.month),
                            y: .value("Spending", data.spending)
                        )
                        .foregroundStyle(.orange)
                    }
                }
                .frame(height: isIPad ? 200 : 150)
            }
        }
    }
    
    private var productivityChartsSection: some View {
        VStack(spacing: isIPad ? 20 : 16) {
            ChartCard(title: "Task Completion Trends") {
                Chart {
                    ForEach(taskCompletionTrends, id: \.week) { data in
                        BarMark(
                            x: .value("Week", data.week),
                            y: .value("Completed", data.completed)
                        )
                        .foregroundStyle(.green)
                        .cornerRadius(4)
                        
                        BarMark(
                            x: .value("Week", data.week),
                            y: .value("Overdue", data.overdue)
                        )
                        .foregroundStyle(.red)
                        .cornerRadius(4)
                    }
                }
                .frame(height: isIPad ? 200 : 150)
            }
        }
    }
    
    // MARK: - Computed Properties for Charts
    private var inventoryByCategory: [(category: String, value: Double)] {
        let categoryTotals = Dictionary(grouping: inventoryStatuses, by: { $0.item.category })
            .mapValues { items in
                items.reduce(0.0) { $0 + $1.totalValue }
            }
        
        return categoryTotals.map { (category: $0.key, value: $0.value) }
            .sorted { $0.value > $1.value }
    }
    
    private var vehicleAgeDistribution: [(ageRange: String, count: Int)] {
        let currentYear = Calendar.current.component(.year, from: Date())
        let ageGroups = Dictionary(grouping: vehicles) { vehicle in
            let age = currentYear - vehicle.year
            switch age {
            case 0...2: return "0-2 years"
            case 3...5: return "3-5 years"
            case 6...10: return "6-10 years"
            default: return "10+ years"
            }
        }
        
        return ageGroups.map { (ageRange: $0.key, count: $0.value.count) }
            .sorted { $0.ageRange < $1.ageRange }
    }
    
    private var monthlySpendingData: [(month: String, spending: Double)] {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM"
        
        return (0..<6).compactMap { monthOffset in
            guard let date = calendar.date(byAdding: .month, value: -monthOffset, to: Date()) else { return nil }
            
            let monthString = dateFormatter.string(from: date)
            let monthSpending = purchaseOrders
                .filter { calendar.isDate($0.date, equalTo: date, toGranularity: .month) }
                .reduce(0.0) { $0 + $1.total }
            
            return (month: monthString, spending: monthSpending)
        }.reversed()
    }
    
    private var taskCompletionTrends: [(week: String, completed: Int, overdue: Int)] {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM dd"
        
        return (0..<4).compactMap { weekOffset in
            guard let date = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: Date()) else { return nil }
            
            let weekString = dateFormatter.string(from: date)
            let weekTasks = tasks.filter { 
                calendar.isDate($0.dueDate, equalTo: date, toGranularity: .weekOfYear)
            }
            
            let completed = weekTasks.filter { $0.status == TaskStatus.completed.rawValue }.count
            let overdue = weekTasks.filter { 
                $0.status != TaskStatus.completed.rawValue && 
                $0.status != TaskStatus.cancelled.rawValue && 
                $0.dueDate < Date() 
            }.count
            
            return (week: weekString, completed: completed, overdue: overdue)
        }.reversed()
    }
    
    // MARK: - Additional Computed Properties
    private var monthlyPOSpending: Double {
        let calendar = Calendar.current
        let now = Date()
        return purchaseOrders
            .filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
            .reduce(0.0) { $0 + $1.total }
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
    
    private var averageJobValue: Double {
        let completedJobs = serviceRecords.filter { $0.status == "Completed" }
        guard !completedJobs.isEmpty else { return 0 }
        
        let totalValue = completedJobs.reduce(0.0) { $0 + $1.laborCost + $1.partsCost }
        return totalValue / Double(completedJobs.count)
    }
    
    private var costPerVehicle: Double {
        guard vehicles.count > 0 else { return 0 }
        return monthlyPOSpending / Double(vehicles.count)
    }
    
    private var taskCompletionRate: Double {
        let completedTasks = tasks.filter { $0.status == TaskStatus.completed.rawValue }
        guard tasks.count > 0 else { return 0 }
        return Double(completedTasks.count) / Double(tasks.count) * 100
    }
    
    private var jobsPerTechnician: Double {
        let technicians = staff.filter { $0.userRole == .technician }
        guard technicians.count > 0 else { return 0 }
        return Double(serviceRecords.count) / Double(technicians.count)
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
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}

// MARK: - Supporting Views

struct DataMetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    let trend: TrendDirection
    let trendValue: String?
    
    enum TrendDirection {
        case up, down, neutral
        
        var icon: String {
            switch self {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .neutral: return "minus"
            }
        }
        
        var color: Color {
            switch self {
            case .up: return .green
            case .down: return .red
            case .neutral: return .gray
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Spacer()
                
                if let trendValue = trendValue {
                    HStack(spacing: 4) {
                        Image(systemName: trend.icon)
                            .font(.caption)
                        Text(trendValue)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(trend.color)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct InsightRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24)
            
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
        .padding(.vertical, 4)
    }
}

struct DataExportView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("Export Options") {
                    Button("Export All Data") {
                        // TODO: Implement export
                    }
                    
                    Button("Export Inventory Report") {
                        // TODO: Implement export
                    }
                    
                    Button("Export Financial Report") {
                        // TODO: Implement export
                    }
                    
                    Button("Export Vehicle Report") {
                        // TODO: Implement export
                    }
                }
            }
            .navigationTitle("Export Data")
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

#Preview {
    DataAnalyticsView()
        .environmentObject(AppAuthService())
        .modelContainer(for: [Vehix.InventoryItem.self, StockLocationItem.self, AppWarehouse.self, Vehix.Vehicle.self, Vehix.ServiceRecord.self, PurchaseOrder.self, AppTask.self, AuthUser.self, VehicleAssignment.self], inMemory: true)
} 