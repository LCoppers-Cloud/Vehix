import SwiftUI
import SwiftData
import Charts
import UniformTypeIdentifiers

struct AdvancedReportsView: View {
    let inventoryItems: [InventoryItemStatus]
    @EnvironmentObject var authService: AppAuthService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // Unified data queries - same as other inventory views
    @Query(sort: [SortDescriptor(\StockLocationItem.createdAt, order: .reverse)]) private var stockLocations: [StockLocationItem]
    @Query(sort: [SortDescriptor(\AppWarehouse.name)]) private var warehouses: [AppWarehouse]
    @Query(sort: [SortDescriptor(\AppVehicle.licensePlate)]) private var vehicles: [AppVehicle]
    
    @State private var selectedReportType: ReportType = .monthlyUsage
    @State private var selectedPeriod: ReportPeriod = .monthly
    @State private var selectedStartDate = Calendar.current.date(byAdding: .month, value: -12, to: Date()) ?? Date()
    @State private var selectedEndDate = Date()
    @State private var showingExportOptions = false
    @State private var isGeneratingReport = false
    
    enum ReportType: String, CaseIterable {
        case monthlyUsage = "Monthly Usage"
        case vehicleInventory = "Vehicle Inventory"
        case warehouseCosts = "Warehouse Costs"
        case costAnalysis = "Cost Analysis"
        case lowStockAnalysis = "Low Stock Analysis"
        case utilizationRates = "Utilization Rates"
        case expenseReports = "Expense Reports"
        
        var icon: String {
            switch self {
            case .monthlyUsage: return "calendar"
            case .vehicleInventory: return "car.fill"
            case .warehouseCosts: return "building.2.fill"
            case .costAnalysis: return "dollarsign.circle"
            case .lowStockAnalysis: return "exclamationmark.triangle"
            case .utilizationRates: return "chart.bar.fill"
            case .expenseReports: return "doc.text.fill"
            }
        }
    }
    
    enum ReportPeriod: String, CaseIterable {
        case monthly = "Monthly"
        case quarterly = "Quarterly"
        case yearly = "Yearly"
        case custom = "Custom Range"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Report controls
                reportControlsView
                
                // Main report content
                ScrollView {
                    LazyVStack(spacing: 20) {
                        switch selectedReportType {
                        case .monthlyUsage:
                            monthlyUsageReport
                        case .vehicleInventory:
                            vehicleInventoryReport
                        case .warehouseCosts:
                            warehouseCostsReport
                        case .costAnalysis:
                            costAnalysisReport
                        case .lowStockAnalysis:
                            lowStockAnalysisReport
                        case .utilizationRates:
                            utilizationRatesReport
                        case .expenseReports:
                            expenseReportsView
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Advanced Reports")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: { showingExportOptions = true }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingExportOptions) {
                ReportExportView(
                    reportType: selectedReportType,
                    period: selectedPeriod,
                    startDate: selectedStartDate,
                    endDate: selectedEndDate,
                    inventoryItems: inventoryItems
                )
            }
        }
    }
    
    // MARK: - Report Controls
    private var reportControlsView: some View {
        VStack(spacing: 12) {
            // Report type selector
            Picker("Report Type", selection: $selectedReportType) {
                ForEach(ReportType.allCases, id: \.self) { type in
                    Label(type.rawValue, systemImage: type.icon).tag(type)
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal)
            
            // Period selector
            HStack {
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(ReportPeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                
                if selectedPeriod == .custom {
                    DatePicker("", selection: $selectedStartDate, displayedComponents: .date)
                        .labelsHidden()
                    
                    Text("to")
                        .foregroundColor(.secondary)
                    
                    DatePicker("", selection: $selectedEndDate, displayedComponents: .date)
                        .labelsHidden()
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color(.systemGray6))
    }
    
    // MARK: - Monthly Usage Report
    private var monthlyUsageReport: some View {
        VStack(spacing: 16) {
            ReportSectionHeader(
                title: "Monthly Inventory Usage",
                subtitle: "Track inventory consumption patterns over time"
            )
            
            // Usage chart
            monthlyUsageChart
            
            // Top consumed items
            topConsumedItemsSection
            
            // Usage by category
            usageByCategorySection
        }
    }
    
    private var monthlyUsageChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Usage Trends")
                .font(.headline)
            
            Chart {
                ForEach(monthlyUsageData, id: \.month) { data in
                    LineMark(
                        x: .value("Month", data.month),
                        y: .value("Usage", data.totalUsage)
                    )
                    .foregroundStyle(Color.blue.gradient)
                    .symbol(Circle())
                    
                    AreaMark(
                        x: .value("Month", data.month),
                        y: .value("Usage", data.totalUsage)
                    )
                    .foregroundStyle(Color.blue.opacity(0.2))
                }
            }
            .frame(height: 200)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                    AxisValueLabel(orientation: .vertical)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2)
    }
    
    private var topConsumedItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Consumed Items")
                .font(.headline)
            
            LazyVStack(spacing: 8) {
                ForEach(topConsumedItems, id: \.item.id) { data in
                    TopConsumedItemRow(
                        item: data.item,
                        totalUsed: data.totalUsed,
                        cost: data.totalCost
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2)
    }
    
    private var usageByCategorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Usage by Category")
                .font(.headline)
            
            Chart {
                ForEach(usageByCategory, id: \.category) { data in
                    SectorMark(
                        angle: .value("Usage", data.totalUsage),
                        innerRadius: .ratio(0.4),
                        angularInset: 2
                    )
                    .foregroundStyle(by: .value("Category", data.category))
                    .cornerRadius(4)
                }
            }
            .frame(height: 200)
            .chartLegend(position: .bottom, alignment: .leading)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2)
    }
    
    // MARK: - Vehicle Inventory Report
    private var vehicleInventoryReport: some View {
        VStack(spacing: 16) {
            ReportSectionHeader(
                title: "Vehicle Inventory Analysis",
                subtitle: "Detailed breakdown of inventory on vehicles"
            )
            
            // Vehicle inventory distribution
            vehicleInventoryChart
            
            // Vehicle inventory table
            vehicleInventoryTable
            
            // Vehicle utilization metrics
            vehicleUtilizationMetrics
        }
    }
    
    private var vehicleInventoryChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Inventory Value by Vehicle")
                .font(.headline)
            
            // Simplified chart to avoid compiler crash
            if !vehicleInventoryData.isEmpty {
                Chart(vehicleInventoryData, id: \.vehicle.id) { data in
                    BarMark(
                        x: .value("Vehicle", data.vehicle.displayName),
                        y: .value("Value", data.totalValue)
                    )
                    .foregroundStyle(vehicleInventoryColor(for: data.totalValue))
                            }
            .frame(height: 250)
            .chartYAxis {
                AxisMarks(format: .currency(code: "USD"), position: .leading)
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel(orientation: .vertical)
                }
            }
            } else {
                Text("No vehicle inventory data available")
                    .foregroundColor(.secondary)
                    .frame(height: 250)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2)
    }
    
    private var vehicleInventoryTable: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Vehicle Inventory Details")
                .font(.headline)
            
            LazyVStack(spacing: 1) {
                // Header
                VehicleInventoryTableHeader()
                
                // Data rows
                ForEach(vehicleInventoryData, id: \.vehicle.id) { data in
                    VehicleInventoryTableRow(data: data)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2)
    }
    
    private var vehicleUtilizationMetrics: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Utilization Metrics")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                MetricCard(
                    title: "Avg Inventory Value",
                    value: "$\(String(format: "%.2f", averageVehicleInventoryValue))",
                    subtitle: "Per Vehicle",
                    icon: "chart.bar.fill",
                    color: .blue,
                    trend: .neutral
                )
                
                MetricCard(
                    title: "Highest Value Vehicle",
                    value: "$\(String(format: "%.2f", highestVehicleInventoryValue))",
                    subtitle: "Maximum Value",
                    icon: "car.fill",
                    color: .green,
                    trend: .up
                )
                
                MetricCard(
                    title: "Total Vehicle Inventory",
                    value: "$\(String(format: "%.2f", totalVehicleInventoryValue))",
                    subtitle: "All Vehicles",
                    icon: "sum",
                    color: .purple,
                    trend: .neutral
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2)
    }
    
    // MARK: - Warehouse Costs Report
    private var warehouseCostsReport: some View {
        VStack(spacing: 16) {
            ReportSectionHeader(
                title: "Warehouse Cost Analysis",
                subtitle: "Comprehensive warehouse cost breakdown and trends"
            )
            
            // Cost trends chart
            warehouseCostTrendsChart
            
            // Cost by warehouse
            costByWarehouseSection
            
            // Storage efficiency metrics
            storageEfficiencyMetrics
        }
    }
    
    private var warehouseCostTrendsChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Warehouse Cost Trends")
                .font(.headline)
            
            // Simplified chart structure to avoid compiler crash
            if !warehouseCostData.isEmpty {
                Chart {
                    ForEach(warehouseCostData, id: \.month) { data in
                        ForEach(data.warehouseCosts, id: \.warehouse.id) { warehouseCost in
                            LineMark(
                                x: .value("Month", data.month),
                                y: .value("Cost", warehouseCost.totalCost)
                            )
                            .foregroundStyle(by: .value("Warehouse", warehouseCost.warehouse.name))
                            .symbol(Circle())
                        }
                    }
                }
                .frame(height: 200)
                .chartYAxis {
                    AxisMarks(format: .currency(code: "USD"), position: .leading)
                }
                .chartLegend(position: .bottom)
            } else {
                Text("No warehouse cost data available")
                    .foregroundColor(.secondary)
                    .frame(height: 200)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2)
    }
    
    private var costByWarehouseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cost by Warehouse")
                .font(.headline)
            
            LazyVStack(spacing: 8) {
                ForEach(warehouses, id: \.id) { warehouse in
                    WarehouseCostRow(
                        warehouse: warehouse,
                        totalValue: warehouseTotalValue(warehouse),
                        utilizationRate: warehouseUtilizationRate(warehouse)
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2)
    }
    
    private var storageEfficiencyMetrics: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Storage Efficiency")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                EfficiencyCard(
                    title: "Total Storage Value",
                    value: "$\(String(format: "%.2f", totalWarehouseValue))",
                    subtitle: "across all warehouses",
                    color: .green
                )
                
                EfficiencyCard(
                    title: "Average Utilization",
                    value: "\(String(format: "%.1f", averageWarehouseUtilization))%",
                    subtitle: "storage efficiency",
                    color: .blue
                )
                
                EfficiencyCard(
                    title: "Cost per Unit",
                    value: "$\(String(format: "%.2f", averageCostPerUnit))",
                    subtitle: "average storage cost",
                    color: .orange
                )
                
                EfficiencyCard(
                    title: "Turnover Rate",
                    value: "\(String(format: "%.1f", inventoryTurnoverRate))x",
                    subtitle: "annual turnover",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2)
    }
    
    // MARK: - Cost Analysis Report
    private var costAnalysisReport: some View {
        VStack(spacing: 16) {
            ReportSectionHeader(
                title: "Comprehensive Cost Analysis",
                subtitle: "Deep dive into inventory costs and financial metrics"
            )
            
            // Cost breakdown chart
            costBreakdownChart
            
            // Financial metrics
            financialMetricsSection
            
            // Cost trends
            costTrendsSection
        }
    }
    
    private var costBreakdownChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cost Breakdown")
                .font(.headline)
            
            Chart {
                ForEach(costBreakdownData, id: \.category) { data in
                    SectorMark(
                        angle: .value("Cost", data.totalCost),
                        innerRadius: .ratio(0.3),
                        angularInset: 1
                    )
                    .foregroundStyle(by: .value("Category", data.category))
                    .cornerRadius(2)
                }
            }
            .frame(height: 250)
            .chartLegend(position: .trailing)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2)
    }
    
    private var financialMetricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Financial Metrics")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                FinancialMetricCard(
                    title: "Total Inventory Value",
                    value: totalInventoryValue,
                    subtitle: "All Locations",
                    icon: "cube.box.fill",
                    color: .blue,
                    format: .currency
                )
                
                FinancialMetricCard(
                    title: "Monthly Consumption",
                    value: monthlyConsumptionValue,
                    subtitle: "Parts Used",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .green,
                    format: .currency
                )
                
                FinancialMetricCard(
                    title: "Average Item Cost",
                    value: averageItemCost,
                    subtitle: "Per Unit",
                    icon: "dollarsign.circle",
                    color: .orange,
                    format: .currency
                )
                
                FinancialMetricCard(
                    title: "Low Stock Value",
                    value: lowStockValue,
                    subtitle: "At Risk",
                    icon: "exclamationmark.triangle",
                    color: .red,
                    format: .currency
                )
                
                FinancialMetricCard(
                    title: "Turnover Rate",
                    value: inventoryTurnoverRate,
                    subtitle: "Times per Year",
                    icon: "arrow.clockwise",
                    color: .purple,
                    format: .decimal
                )
                
                FinancialMetricCard(
                    title: "Days of Supply",
                    value: daysOfSupply,
                    subtitle: "Days Remaining",
                    icon: "calendar",
                    color: .indigo,
                    format: .decimal
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2)
    }
    
    private var costTrendsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cost Trends Over Time")
                .font(.headline)
            
            Chart {
                ForEach(monthlyCostData, id: \.month) { data in
                    LineMark(
                        x: .value("Month", data.month),
                        y: .value("Total Cost", data.totalCost)
                    )
                    .foregroundStyle(Color.blue.gradient)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    .symbol(Circle().strokeBorder(lineWidth: 2))
                    
                    AreaMark(
                        x: .value("Month", data.month),
                        y: .value("Total Cost", data.totalCost)
                    )
                    .foregroundStyle(Color.blue.opacity(0.15))
                }
            }
            .frame(height: 200)
            .chartYAxis {
                AxisMarks(format: .currency(code: "USD"), position: .leading)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2)
    }
    
    // MARK: - Low Stock Analysis Report
    private var lowStockAnalysisReport: some View {
        VStack(spacing: 16) {
            ReportSectionHeader(
                title: "Low Stock Analysis",
                subtitle: "Critical inventory levels and reorder recommendations"
            )
            
            // Low stock overview
            lowStockOverview
            
            // Critical items list
            criticalItemsList
            
            // Reorder recommendations
            reorderRecommendationsSection
        }
    }
    
    private var lowStockOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Low Stock Overview")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                AlertCard(
                    title: "Critical Items",
                    count: criticalStockItems.count,
                    message: "need immediate attention",
                    color: .red,
                    icon: "exclamationmark.triangle.fill"
                )
                
                AlertCard(
                    title: "Low Stock Items",
                    count: lowStockItems.count,
                    message: "below minimum levels",
                    color: .orange,
                    icon: "exclamationmark.circle.fill"
                )
                
                AlertCard(
                    title: "Total Value at Risk",
                    count: Int(lowStockValue),
                    message: "potential stockout cost",
                    color: .yellow,
                    icon: "dollarsign.circle.fill"
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2)
    }
    
    private var criticalItemsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Critical Items")
                .font(.headline)
            
            LazyVStack(spacing: 8) {
                ForEach(criticalStockItems, id: \.id) { stockItem in
                    CriticalItemRow(stockItem: stockItem)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2)
    }
    
    private var reorderRecommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reorder Recommendations")
                .font(.headline)
            
            LazyVStack(spacing: 8) {
                ForEach(reorderRecommendations, id: \.stockItem.id) { recommendation in
                    ReorderRecommendationRow(recommendation: recommendation)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2)
    }
    
    // MARK: - Utilization Rates Report
    private var utilizationRatesReport: some View {
        VStack(spacing: 16) {
            ReportSectionHeader(
                title: "Inventory Utilization Rates",
                subtitle: "Efficiency metrics and optimization opportunities"
            )
            
            // Utilization overview
            utilizationOverview
            
            // Category utilization
            categoryUtilizationChart
            
            // Location efficiency
            locationEfficiencySection
        }
    }
    
    private var utilizationOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Utilization Overview")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                UtilizationCard(
                    title: "Overall Utilization",
                    value: overallUtilizationRate,
                    unit: "%",
                    color: utilizationColor(overallUtilizationRate)
                )
                
                UtilizationCard(
                    title: "Warehouse Efficiency",
                    value: warehouseEfficiencyRate,
                    unit: "%",
                    color: utilizationColor(warehouseEfficiencyRate)
                )
                
                UtilizationCard(
                    title: "Vehicle Efficiency",
                    value: vehicleEfficiencyRate,
                    unit: "%",
                    color: utilizationColor(vehicleEfficiencyRate)
                )
                
                UtilizationCard(
                    title: "Inventory Turnover",
                    value: inventoryTurnoverRate,
                    unit: "x/year",
                    color: .blue
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2)
    }
    
    private var categoryUtilizationChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Utilization by Category")
                .font(.headline)
            
            Chart {
                ForEach(categoryUtilizationData, id: \.category) { data in
                    BarMark(
                        x: .value("Category", data.category),
                        y: .value("Utilization", data.utilizationRate)
                    )
                    .foregroundStyle(utilizationColor(data.utilizationRate))
                }
            }
            .frame(height: 200)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text("\(Int(doubleValue * 100))%")
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2)
    }
    
    private var locationEfficiencySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Location Efficiency")
                .font(.headline)
            
            LazyVStack(spacing: 8) {
                ForEach(locationEfficiencyData, id: \.location) { data in
                    LocationEfficiencyRow(data: data)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2)
    }
    
    // MARK: - Expense Reports
    private var expenseReportsView: some View {
        VStack(spacing: 16) {
            ReportSectionHeader(
                title: "Executive Expense Reports",
                subtitle: "Comprehensive financial reporting for corporate management"
            )
            
            // Executive summary
            executiveSummary
            
            // Monthly expense breakdown
            monthlyExpenseBreakdown
            
            // Year-over-year comparison
            yearOverYearComparison
            
            // Budget variance analysis
            budgetVarianceAnalysis
        }
    }
    
    private var executiveSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Executive Summary")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ExecutiveSummaryCard(
                    title: "Total Inventory Investment",
                    value: totalInventoryValue,
                    change: monthlyInventoryChange,
                    changeType: monthlyInventoryChange >= 0 ? .increase : .decrease
                )
                
                ExecutiveSummaryCard(
                    title: "Monthly Operating Cost",
                    value: monthlyOperatingCost,
                    change: monthlyOperatingCostChange,
                    changeType: monthlyOperatingCostChange >= 0 ? .increase : .decrease
                )
                
                ExecutiveSummaryCard(
                    title: "ROI on Inventory",
                    value: inventoryROI,
                    change: roiChange,
                    changeType: roiChange >= 0 ? .increase : .decrease
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2)
    }
    
    private var monthlyExpenseBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Expense Breakdown")
                .font(.headline)
            
            Chart {
                ForEach(monthlyExpenseData, id: \.month) { data in
                    AreaMark(
                        x: .value("Month", data.month),
                        yStart: .value("Storage", 0),
                        yEnd: .value("Storage", data.storageCost)
                    )
                    .foregroundStyle(.blue)
                    
                    AreaMark(
                        x: .value("Month", data.month),
                        yStart: .value("Storage", data.storageCost),
                        yEnd: .value("Labor", data.storageCost + data.laborCost)
                    )
                    .foregroundStyle(.green)
                    
                    AreaMark(
                        x: .value("Month", data.month),
                        yStart: .value("Labor", data.storageCost + data.laborCost),
                        yEnd: .value("Equipment", data.storageCost + data.laborCost + data.equipmentCost)
                    )
                    .foregroundStyle(.orange)
                    
                    AreaMark(
                        x: .value("Month", data.month),
                        yStart: .value("Equipment", data.storageCost + data.laborCost + data.equipmentCost),
                        yEnd: .value("Other", data.totalCost)
                    )
                    .foregroundStyle(.purple)
                }
            }
            .frame(height: 250)
            .chartYAxis {
                AxisMarks(format: .currency(code: "USD"), position: .leading)
            }
            .chartLegend(position: .bottom)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2)
    }
    
    private var yearOverYearComparison: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Year-over-Year Comparison")
                .font(.headline)
            
            Chart {
                ForEach(yearOverYearData, id: \.month) { data in
                    LineMark(
                        x: .value("Month", data.month),
                        y: .value("This Year", data.currentYear)
                    )
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    
                    LineMark(
                        x: .value("Month", data.month),
                        y: .value("Last Year", data.previousYear)
                    )
                    .foregroundStyle(.gray)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
                }
            }
            .frame(height: 200)
            .chartYAxis {
                AxisMarks(format: .currency(code: "USD"), position: .leading)
            }
            .chartLegend(position: .bottom)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2)
    }
    
    private var budgetVarianceAnalysis: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Budget Variance Analysis")
                .font(.headline)
            
            LazyVStack(spacing: 8) {
                ForEach(budgetVarianceData, id: \.category) { variance in
                    BudgetVarianceRow(variance: variance)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2)
    }
    
    // MARK: - Computed Properties and Data Generation
    
    // PRODUCTION MODE: Real data from database (no more sample data)
    private var monthlyUsageData: [MonthlyUsageData] {
        // TODO: Implement real monthly usage data from database
        // For now, return empty array - will be populated as usage data is recorded
        return []
    }
    
    private var topConsumedItems: [ConsumedItemData] {
        // TODO: Calculate real consumption data from usage records
        // For now, return empty array - will be populated as items are used
        return []
    }
    
    private var usageByCategory: [CategoryUsageData] {
        // TODO: Calculate real usage by category from usage records
        // For now, return categories with zero usage
        let categories = Set(inventoryItems.map { $0.item.category })
        return categories.map { category in
            CategoryUsageData(
                category: category,
                totalUsage: 0.0 // Will be calculated from real usage data
            )
        }
    }
    
    private var vehicleInventoryData: [VehicleInventoryData] {
        vehicles.map { vehicle in
            let vehicleStockItems = stockLocations.filter { $0.vehicle?.id == vehicle.id }
            let totalValue = vehicleStockItems.reduce(0.0) { sum, stockItem in
                sum + (Double(stockItem.quantity) * (stockItem.inventoryItem?.pricePerUnit ?? 0.0))
            }
            return VehicleInventoryData(
                vehicle: vehicle,
                itemCount: vehicleStockItems.count,
                totalValue: totalValue,
                utilizationRate: 0.0 // TODO: Calculate from real usage data
            )
        }
    }
    
    private var warehouseCostData: [MonthlyWarehouseCostData] {
        // TODO: Calculate real warehouse costs from purchase data
        // For now, return empty array - will be populated from real purchase records
        return []
    }
    
    private var costBreakdownData: [CostBreakdownData] {
        // Calculate real cost breakdown from inventory categories
        let categories = Set(inventoryItems.map { $0.item.category })
        return categories.map { category in
            let categoryValue = stockLocations
                .filter { $0.inventoryItem?.category == category }
                .reduce(0.0) { sum, stockItem in
                    sum + (Double(stockItem.quantity) * (stockItem.inventoryItem?.pricePerUnit ?? 0.0))
                }
            return CostBreakdownData(category: category, totalCost: categoryValue)
        }
    }
    
    private var monthlyCostData: [MonthlyCostData] {
        // TODO: Calculate real monthly costs from purchase orders
        // For now, return empty array - will be populated from real purchase data
        return []
    }
    
    private var criticalStockItems: [StockLocationItem] {
        stockLocations.filter { 
            $0.quantity <= $0.minimumStockLevel / 2 
        }
    }
    
    private var lowStockItems: [StockLocationItem] {
        stockLocations.filter { $0.isBelowMinimumStock }
    }
    
    private var reorderRecommendations: [ReorderRecommendation] {
        lowStockItems.map { stockItem in
            let recommendedQuantity = (stockItem.maxStockLevel ?? stockItem.minimumStockLevel * 2) - stockItem.quantity
            return ReorderRecommendation(
                stockItem: stockItem,
                recommendedQuantity: max(recommendedQuantity, 0),
                estimatedCost: Double(recommendedQuantity) * (stockItem.inventoryItem?.pricePerUnit ?? 0.0),
                priority: stockItem.quantity <= stockItem.minimumStockLevel / 2 ? .critical : .normal
            )
        }
    }
    
    private var categoryUtilizationData: [CategoryUtilizationData] {
        // TODO: Calculate real utilization from usage records
        let categories = Set(inventoryItems.map { $0.item.category })
        return categories.map { category in
            CategoryUtilizationData(
                category: category,
                utilizationRate: 0.0 // Will be calculated from real usage data
            )
        }
    }
    
    private var locationEfficiencyData: [LocationEfficiencyData] {
        var data: [LocationEfficiencyData] = []
        
        // Add warehouse data (real calculations)
        for warehouse in warehouses {
            data.append(LocationEfficiencyData(
                location: warehouse.name,
                type: .warehouse,
                efficiency: 0.0, // TODO: Calculate from real usage data
                totalValue: warehouseTotalValue(warehouse),
                utilizationRate: warehouseUtilizationRate(warehouse)
            ))
        }
        
        // Add vehicle data (real calculations)
        for vehicle in vehicles {
            let vehicleStockItems = stockLocations.filter { $0.vehicle?.id == vehicle.id }
            let totalValue = vehicleStockItems.reduce(0.0) { sum, stockItem in
                sum + (Double(stockItem.quantity) * (stockItem.inventoryItem?.pricePerUnit ?? 0.0))
            }
            data.append(LocationEfficiencyData(
                location: vehicle.displayName,
                type: .vehicle,
                efficiency: 0.0, // TODO: Calculate from real usage data
                totalValue: totalValue,
                utilizationRate: 0.0 // TODO: Calculate from real usage data
            ))
        }
        
        return data
    }
    
    private var monthlyExpenseData: [MonthlyExpenseData] {
        // TODO: Calculate real monthly expenses from purchase orders and cost records
        // For now, return empty array - will be populated from real financial data
        return []
    }
    
    private var yearOverYearData: [YearOverYearData] {
        // TODO: Calculate real year-over-year data from historical records
        // For now, return empty array - will be populated as historical data accumulates
        return []
    }
    
    private var budgetVarianceData: [BudgetVariance] {
        // TODO: Calculate real budget variance from budgets and actual spending
        // For now, return empty array - will be populated when budgets are set
        return []
    }
    
    // Helper computed properties
    private var totalInventoryValue: Double {
        stockLocations.reduce(0.0) { sum, stockItem in
            sum + (Double(stockItem.quantity) * (stockItem.inventoryItem?.pricePerUnit ?? 0.0))
        }
    }
    
    private var monthlyConsumptionValue: Double {
        // TODO: Calculate real monthly consumption from usage records
        // For now, return 0 until usage data is available
        return 0.0
    }
    
    private var averageItemCost: Double {
        let totalCost = inventoryItems.reduce(0.0) { sum, itemStatus in
            sum + (itemStatus.item.pricePerUnit)
        }
        return inventoryItems.isEmpty ? 0 : totalCost / Double(inventoryItems.count)
    }
    
    private var lowStockValue: Double {
        lowStockItems.reduce(0.0) { sum, stockItem in
            sum + (Double(stockItem.quantity) * (stockItem.inventoryItem?.pricePerUnit ?? 0.0))
        }
    }
    
    private var inventoryTurnoverRate: Double {
        // Simplified calculation - in real implementation, use actual consumption data
        monthlyConsumptionValue * 12 / totalInventoryValue
    }
    
    private var daysOfSupply: Double {
        // Simplified calculation
        totalInventoryValue / (monthlyConsumptionValue / 30)
    }
    
    private var averageVehicleInventoryValue: Double {
        let vehicleValues = vehicleInventoryData.map { $0.totalValue }
        return vehicleValues.isEmpty ? 0 : vehicleValues.reduce(0, +) / Double(vehicleValues.count)
    }
    
    private var highestVehicleInventoryValue: Double {
        vehicleInventoryData.map { $0.totalValue }.max() ?? 0
    }
    
    private var totalVehicleInventoryValue: Double {
        vehicleInventoryData.reduce(0) { $0 + $1.totalValue }
    }
    
    private var totalWarehouseValue: Double {
        warehouses.reduce(0.0) { sum, warehouse in
            sum + warehouseTotalValue(warehouse)
        }
    }
    
    private var averageWarehouseUtilization: Double {
        let utilizations = warehouses.map { warehouseUtilizationRate($0) }
        return utilizations.isEmpty ? 0 : utilizations.reduce(0, +) / Double(utilizations.count)
    }
    
    private var averageCostPerUnit: Double {
        averageItemCost
    }
    
    private var overallUtilizationRate: Double {
        // TODO: Calculate real utilization from usage data
        // For now, return 0 until usage tracking is implemented
        return 0.0
    }
    
    private var warehouseEfficiencyRate: Double {
        averageWarehouseUtilization * 100
    }
    
    private var vehicleEfficiencyRate: Double {
        let vehicleUtilizations = vehicleInventoryData.map { $0.utilizationRate }
        let average = vehicleUtilizations.isEmpty ? 0 : vehicleUtilizations.reduce(0, +) / Double(vehicleUtilizations.count)
        return average * 100
    }
    
    private var monthlyInventoryChange: Double {
        // TODO: Calculate real inventory change from historical data
        // For now, return 0 until historical tracking is implemented
        return 0.0
    }
    
    private var monthlyOperatingCost: Double {
        monthlyExpenseData.last?.totalCost ?? 0.0 // Changed from hardcoded 25000 to 0
    }
    
    private var monthlyOperatingCostChange: Double {
        // TODO: Calculate real cost change from historical data  
        // For now, return 0 until historical cost tracking is implemented
        return 0.0
    }
    
    private var inventoryROI: Double {
        guard totalInventoryValue > 0 else { return 0.0 }
        return (monthlyConsumptionValue * 12 - totalInventoryValue) / totalInventoryValue * 100
    }
    
    private var roiChange: Double {
        // TODO: Calculate real ROI change from historical data
        // For now, return 0 until historical ROI tracking is implemented
        return 0.0
    }
    
    // Helper methods
    private func warehouseTotalValue(_ warehouse: AppWarehouse) -> Double {
        stockLocations
            .filter { $0.warehouse?.id == warehouse.id }
            .reduce(0.0) { sum, stockItem in
                sum + (Double(stockItem.quantity) * (stockItem.inventoryItem?.pricePerUnit ?? 0.0))
            }
    }
    
    private func warehouseUtilizationRate(_ warehouse: AppWarehouse) -> Double {
        // TODO: Calculate real utilization based on capacity and usage
        // For now, return 0 until capacity tracking is implemented
        return 0.0
    }
    
    private func vehicleInventoryColor(for value: Double) -> Color {
        if value > 10000 { return .green }
        else if value > 5000 { return .blue }
        else if value > 2000 { return .orange }
        else { return .red }
    }
    
    private func utilizationColor(_ rate: Double) -> Color {
        if rate > 0.8 { return .green }
        else if rate > 0.6 { return .blue }
        else if rate > 0.4 { return .orange }
        else { return .red }
    }
}

// MARK: - Data Structures

struct MonthlyUsageData {
    let month: String
    let totalUsage: Double
}

struct ConsumedItemData {
    let item: AppInventoryItem
    let totalUsed: Int
    let totalCost: Double
}

struct CategoryUsageData {
    let category: String
    let totalUsage: Double
}

struct VehicleInventoryData {
    let vehicle: AppVehicle
    let itemCount: Int
    let totalValue: Double
    let utilizationRate: Double
}

struct MonthlyWarehouseCostData {
    let month: String
    let warehouseCosts: [WarehouseCostData]
}

struct WarehouseCostData {
    let warehouse: AppWarehouse
    let totalCost: Double
}

struct CostBreakdownData {
    let category: String
    let totalCost: Double
}

struct MonthlyCostData {
    let month: String
    let totalCost: Double
}

struct ReorderRecommendation {
    let stockItem: StockLocationItem
    let recommendedQuantity: Int
    let estimatedCost: Double
    let priority: Priority
    
    enum Priority {
        case critical, normal
    }
}

struct CategoryUtilizationData {
    let category: String
    let utilizationRate: Double
}

struct LocationEfficiencyData {
    let location: String
    let type: LocationType
    let efficiency: Double
    let totalValue: Double
    let utilizationRate: Double
    
    enum LocationType {
        case warehouse, vehicle
    }
}

struct MonthlyExpenseData {
    let month: String
    let storageCost: Double
    let laborCost: Double
    let equipmentCost: Double
    let otherCost: Double
    let totalCost: Double
}

struct YearOverYearData {
    let month: String
    let currentYear: Double
    let previousYear: Double
}

struct BudgetVariance {
    let category: String
    let budgeted: Double
    let actual: Double
    
    var variance: Double {
        actual - budgeted
    }
    
    var variancePercentage: Double {
        (variance / budgeted) * 100
    }
}

// MARK: - Supporting Views

struct ReportSectionHeader: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }
}

struct TopConsumedItemRow: View {
    let item: AppInventoryItem
    let totalUsed: Int
    let cost: Double
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                
                Text("Part: \(item.partNumber)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(totalUsed) used")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("$\(String(format: "%.2f", cost))")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
    }
}

struct VehicleInventoryTableHeader: View {
    var body: some View {
        HStack {
            Text("Vehicle")
                .font(.caption)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("Items")
                .font(.caption)
                .fontWeight(.bold)
                .frame(width: 60, alignment: .center)
            
            Text("Value")
                .font(.caption)
                .fontWeight(.bold)
                .frame(width: 80, alignment: .trailing)
            
            Text("Util %")
                .font(.caption)
                .fontWeight(.bold)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray5))
    }
}

struct VehicleInventoryTableRow: View {
    let data: VehicleInventoryData
    
    var body: some View {
        HStack {
            Text(data.vehicle.displayName)
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("\(data.itemCount)")
                .font(.caption)
                .frame(width: 60, alignment: .center)
            
            Text("$\(String(format: "%.0f", data.totalValue))")
                .font(.caption)
                .frame(width: 80, alignment: .trailing)
            
            Text("\(String(format: "%.0f", data.utilizationRate * 100))%")
                .font(.caption)
                .foregroundColor(utilizationColor(data.utilizationRate))
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color(.systemBackground))
    }
    
    private func utilizationColor(_ rate: Double) -> Color {
        if rate > 0.8 { return .green }
        else if rate > 0.6 { return .blue }
        else if rate > 0.4 { return .orange }
        else { return .red }
    }
}

struct WarehouseCostRow: View {
    let warehouse: AppWarehouse
    let totalValue: Double
    let utilizationRate: Double
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(warehouse.name)
                    .font(.headline)
                
                Text(warehouse.location)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(String(format: "%.2f", totalValue))")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.green)
                
                Text("\(String(format: "%.1f", utilizationRate * 100))% utilized")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct EfficiencyCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct CriticalItemRow: View {
    let stockItem: StockLocationItem
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(stockItem.inventoryItem?.name ?? "Unknown Item")
                    .font(.headline)
                
                Text("Location: \(stockItem.locationName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Current: \(stockItem.quantity) | Min: \(stockItem.minimumStockLevel)")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("CRITICAL")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red)
                    .cornerRadius(6)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ReorderRecommendationRow: View {
    let recommendation: ReorderRecommendation
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation.stockItem.inventoryItem?.name ?? "Unknown Item")
                    .font(.headline)
                
                Text("Reorder: \(recommendation.recommendedQuantity) units")
                    .font(.subheadline)
                    .foregroundColor(.blue)
                
                Text("Estimated cost: $\(String(format: "%.2f", recommendation.estimatedCost))")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(recommendation.priority == .critical ? "URGENT" : "NORMAL")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(recommendation.priority == .critical ? Color.red : Color.orange)
                    .cornerRadius(6)
            }
        }
        .padding(.vertical, 4)
    }
}

struct UtilizationCard: View {
    let title: String
    let value: Double
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(alignment: .bottom, spacing: 4) {
                Text(String(format: "%.1f", value))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

struct LocationEfficiencyRow: View {
    let data: LocationEfficiencyData
    
    var body: some View {
        HStack {
            Image(systemName: data.type == .warehouse ? "building.2.fill" : "car.fill")
                .foregroundColor(data.type == .warehouse ? .purple : .blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(data.location)
                    .font(.headline)
                
                Text("Efficiency: \(String(format: "%.1f", data.efficiency * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(String(format: "%.2f", data.totalValue))")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.green)
                
                Text("\(String(format: "%.1f", data.utilizationRate * 100))% util")
                    .font(.caption)
                    .foregroundColor(utilizationColor(data.utilizationRate))
            }
        }
        .padding(.vertical, 4)
    }
    
    private func utilizationColor(_ rate: Double) -> Color {
        if rate > 0.8 { return .green }
        else if rate > 0.6 { return .blue }
        else if rate > 0.4 { return .orange }
        else { return .red }
    }
}

struct ExecutiveSummaryCard: View {
    let title: String
    let value: Double
    let change: Double
    let changeType: ChangeType
    
    enum ChangeType {
        case increase, decrease
        
        var color: Color {
            switch self {
            case .increase: return .green
            case .decrease: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .increase: return "arrow.up"
            case .decrease: return "arrow.down"
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .fontWeight(.bold)
            
            Text("$\(String(format: "%.2f", value))")
                .font(.title3)
                .fontWeight(.bold)
            
            HStack(spacing: 4) {
                Image(systemName: changeType.icon)
                    .font(.caption)
                    .foregroundColor(changeType.color)
                
                Text("$\(String(format: "%.2f", abs(change)))")
                    .font(.caption)
                    .foregroundColor(changeType.color)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
}

struct BudgetVarianceRow: View {
    let variance: BudgetVariance
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(variance.category)
                    .font(.headline)
                
                Text("Budgeted: $\(String(format: "%.2f", variance.budgeted))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(String(format: "%.2f", variance.actual))")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 4) {
                    Text("\(variance.variance >= 0 ? "+" : "")$\(String(format: "%.2f", variance.variance))")
                        .font(.caption)
                        .foregroundColor(variance.variance >= 0 ? .red : .green)
                    
                    Text("(\(variance.variance >= 0 ? "+" : "")\(String(format: "%.1f", variance.variancePercentage))%)")
                        .font(.caption)
                        .foregroundColor(variance.variance >= 0 ? .red : .green)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct ReportCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let monthYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yy"
        return formatter
    }()
} 