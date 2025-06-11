import SwiftUI
import SwiftData
import Charts

// MARK: - Financial Data Models

struct FinancialSummary {
    let totalInventoryValue: Double
    let vehicleInventoryValue: Double
    let warehouseInventoryValue: Double
    let monthlyPOSpending: Double
    let quarterlyPOSpending: Double
    let yearlyPOSpending: Double
    let averageVehicleValue: Double
    let inventoryTurnoverRate: Double
    let monthlyBurnRate: Double
}

struct VehicleFinancialData {
    let vehicle: AppVehicle
    let inventoryValue: Double
    let itemCount: Int
    let lastUpdated: Date
    let utilizationRate: Double
}

struct PurchaseOrderFinancialData {
    let month: String
    let totalSpent: Double
    let orderCount: Int
    let averageOrderValue: Double
    let topVendor: String
    let topVendorSpending: Double
}

struct FinancialPeriodData {
    let period: String
    let revenue: Double
    let costs: Double
    let profit: Double
    let profitMargin: Double
}

// MARK: - Financial Manager

@Observable
class FinancialTrackingManager {
    private var modelContext: ModelContext?
    
    var isLoading = false
    var errorMessage: String?
    var financialSummary: FinancialSummary?
    var vehicleFinancialData: [VehicleFinancialData] = []
    var purchaseOrderData: [PurchaseOrderFinancialData] = []
    var periodData: [FinancialPeriodData] = []
    
    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        Task {
            await refreshFinancialData()
        }
    }
    
    @MainActor
    func refreshFinancialData() async {
        guard let modelContext = modelContext else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch all necessary data
            let inventoryItems = try modelContext.fetch(FetchDescriptor<AppInventoryItem>())
            let stockLocations = try modelContext.fetch(FetchDescriptor<StockLocationItem>())
            let vehicles = try modelContext.fetch(FetchDescriptor<AppVehicle>())
            let purchaseOrders = try modelContext.fetch(FetchDescriptor<PurchaseOrder>())
            let serviceRecords = try modelContext.fetch(FetchDescriptor<AppServiceRecord>())
            
            // Calculate financial summary
            financialSummary = calculateFinancialSummary(
                inventoryItems: inventoryItems,
                stockLocations: stockLocations,
                vehicles: vehicles,
                purchaseOrders: purchaseOrders
            )
            
            // Calculate vehicle financial data
            vehicleFinancialData = calculateVehicleFinancialData(
                vehicles: vehicles,
                stockLocations: stockLocations
            )
            
            // Calculate purchase order data
            purchaseOrderData = calculatePurchaseOrderData(purchaseOrders: purchaseOrders)
            
            // Calculate period data
            periodData = calculatePeriodData(
                purchaseOrders: purchaseOrders,
                serviceRecords: serviceRecords
            )
            
            isLoading = false
        } catch {
            errorMessage = "Failed to load financial data: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    private func calculateFinancialSummary(
        inventoryItems: [AppInventoryItem],
        stockLocations: [StockLocationItem],
        vehicles: [AppVehicle],
        purchaseOrders: [PurchaseOrder]
    ) -> FinancialSummary {
        
        // Total inventory value
        let totalInventoryValue = stockLocations.reduce(0.0) { total, stock in
            let itemValue = stock.inventoryItem?.pricePerUnit ?? 0.0
            return total + (itemValue * Double(stock.quantity))
        }
        
        // Vehicle inventory value
        let vehicleInventoryValue = stockLocations
            .filter { $0.vehicle != nil }
            .reduce(0.0) { total, stock in
                let itemValue = stock.inventoryItem?.pricePerUnit ?? 0.0
                return total + (itemValue * Double(stock.quantity))
            }
        
        // Warehouse inventory value
        let warehouseInventoryValue = totalInventoryValue - vehicleInventoryValue
        
        // Average vehicle value
        let averageVehicleValue = vehicles.isEmpty ? 0.0 : vehicleInventoryValue / Double(vehicles.count)
        
        // Purchase order spending calculations
        let calendar = Calendar.current
        let now = Date()
        
        let monthlyPOSpending = purchaseOrders
            .filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
            .reduce(0.0) { $0 + $1.total }
        
        let quarterlyPOSpending = purchaseOrders
            .filter { 
                let monthsAgo = calendar.dateInterval(of: .quarter, for: now)
                return monthsAgo?.contains($0.date) ?? false
            }
            .reduce(0.0) { $0 + $1.total }
        
        let yearlyPOSpending = purchaseOrders
            .filter { calendar.isDate($0.date, equalTo: now, toGranularity: .year) }
            .reduce(0.0) { $0 + $1.total }
        
        // Calculate inventory turnover rate (simplified)
        let inventoryTurnoverRate = yearlyPOSpending > 0 ? totalInventoryValue / yearlyPOSpending : 0.0
        
        // Monthly burn rate
        let monthlyBurnRate = monthlyPOSpending
        
        return FinancialSummary(
            totalInventoryValue: totalInventoryValue,
            vehicleInventoryValue: vehicleInventoryValue,
            warehouseInventoryValue: warehouseInventoryValue,
            monthlyPOSpending: monthlyPOSpending,
            quarterlyPOSpending: quarterlyPOSpending,
            yearlyPOSpending: yearlyPOSpending,
            averageVehicleValue: averageVehicleValue,
            inventoryTurnoverRate: inventoryTurnoverRate,
            monthlyBurnRate: monthlyBurnRate
        )
    }
    
    private func calculateVehicleFinancialData(
        vehicles: [AppVehicle],
        stockLocations: [StockLocationItem]
    ) -> [VehicleFinancialData] {
        
        return vehicles.map { vehicle in
            let vehicleStockLocations = stockLocations.filter { $0.vehicle?.id == vehicle.id }
            
            let inventoryValue = vehicleStockLocations.reduce(0.0) { total, stock in
                let itemValue = stock.inventoryItem?.pricePerUnit ?? 0.0
                return total + (itemValue * Double(stock.quantity))
            }
            
            let itemCount = vehicleStockLocations.reduce(0) { $0 + $1.quantity }
            
            let lastUpdated = vehicleStockLocations
                .compactMap { $0.createdAt }
                .max() ?? Date.distantPast
            
            // Calculate utilization rate (simplified - based on stock levels vs capacity)
            let utilizationRate = vehicleStockLocations.isEmpty ? 0.0 : 
                Double(vehicleStockLocations.filter { $0.quantity > 0 }.count) / 
                Double(max(1, vehicleStockLocations.count))
            
            return VehicleFinancialData(
                vehicle: vehicle,
                inventoryValue: inventoryValue,
                itemCount: itemCount,
                lastUpdated: lastUpdated,
                utilizationRate: utilizationRate
            )
        }
        .sorted { $0.inventoryValue > $1.inventoryValue }
    }
    
    private func calculatePurchaseOrderData(purchaseOrders: [PurchaseOrder]) -> [PurchaseOrderFinancialData] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM yyyy"
        
        // Group by month
        let monthlyGroups = Dictionary(grouping: purchaseOrders) { po in
            dateFormatter.string(from: po.date)
        }
        
        return monthlyGroups.map { (month, orders) in
            let totalSpent = orders.reduce(0.0) { $0 + $1.total }
            let orderCount = orders.count
            let averageOrderValue = orderCount > 0 ? totalSpent / Double(orderCount) : 0.0
            
            // Find top vendor for this month
            let vendorSpending = Dictionary(grouping: orders, by: { $0.vendorName })
                .mapValues { $0.reduce(0.0) { $0 + $1.total } }
            
            let topVendorEntry = vendorSpending.max { $0.value < $1.value }
            let topVendor = topVendorEntry?.key ?? "N/A"
            let topVendorSpending = topVendorEntry?.value ?? 0.0
            
            return PurchaseOrderFinancialData(
                month: month,
                totalSpent: totalSpent,
                orderCount: orderCount,
                averageOrderValue: averageOrderValue,
                topVendor: topVendor,
                topVendorSpending: topVendorSpending
            )
        }
        .sorted { $0.month > $1.month }
        .prefix(12)
        .map { $0 }
    }
    
    private func calculatePeriodData(
        purchaseOrders: [PurchaseOrder],
        serviceRecords: [AppServiceRecord]
    ) -> [FinancialPeriodData] {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM yyyy"
        
        return (0..<12).map { monthOffset in
            let date = calendar.date(byAdding: .month, value: -monthOffset, to: Date()) ?? Date()
            
            let period = dateFormatter.string(from: date)
            
            // Calculate costs (purchase orders)
            let costs = purchaseOrders
                .filter { calendar.isDate($0.date, equalTo: date, toGranularity: .month) }
                .reduce(0.0) { $0 + $1.total }
            
            // Calculate revenue (completed service records)
            let revenue = serviceRecords
                .filter { 
                    $0.status == "Completed" && 
                    calendar.isDate($0.startTime, equalTo: date, toGranularity: .month)
                }
                .reduce(0.0) { total, record in total + record.laborCost + record.partsCost }
            
            let profit = revenue - costs
            let profitMargin = revenue > 0 ? (profit / revenue) * 100 : 0.0
            
            return FinancialPeriodData(
                period: period,
                revenue: revenue,
                costs: costs,
                profit: profit,
                profitMargin: profitMargin
            )
        }
        .reversed()
    }
}

// MARK: - Financial Dashboard Components

struct ExecutiveFinancialDashboard: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authService: AppAuthService
    @State private var financialManager = FinancialTrackingManager()
    @State private var selectedPeriod: FinancialPeriod = .monthly
    @State private var showingDetailedReport = false
    
    enum FinancialPeriod: String, CaseIterable {
        case monthly = "Monthly"
        case quarterly = "Quarterly"
        case yearly = "Yearly"
    }
    
    // Check if user has executive access
    private var hasExecutiveAccess: Bool {
        authService.currentUser?.userRole == .admin || 
        authService.currentUser?.userRole == .dealer
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if hasExecutiveAccess {
                executiveContent
            } else {
                accessDeniedView
            }
        }
        .onAppear {
            financialManager.setModelContext(modelContext)
        }
        .refreshable {
            await financialManager.refreshFinancialData()
        }
    }
    
    private var executiveContent: some View {
        VStack(spacing: 20) {
            // Header with period selector
            HStack {
                Text("Executive Financial Dashboard")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(FinancialPeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            
            if financialManager.isLoading {
                ProgressView("Loading financial data...")
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else if let summary = financialManager.financialSummary {
                // Financial summary cards
                financialSummaryCards(summary: summary)
                
                // Charts section
                financialChartsSection
                
                // Vehicle inventory breakdown
                vehicleInventorySection
                
                // Purchase order analysis
                purchaseOrderSection
                
                // Detailed report button
                Button(action: { showingDetailedReport = true }) {
                    Text("View Detailed Financial Report")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .cornerRadius(12)
                }
            } else if let error = financialManager.errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, minHeight: 200)
            }
        }
        .sheet(isPresented: $showingDetailedReport) {
            DetailedFinancialReportView(financialManager: financialManager)
        }
    }
    
    private var accessDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("Executive Access Required")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("This financial dashboard is restricted to owners and administrators only.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    private func financialSummaryCards(summary: FinancialSummary) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            FinancialMetricCard(
                title: "Total Inventory Value",
                value: summary.totalInventoryValue,
                subtitle: "All Locations",
                icon: "cube.box.fill",
                color: .blue,
                format: .currency
            )
            
            FinancialMetricCard(
                title: "Vehicle Inventory",
                value: summary.vehicleInventoryValue,
                subtitle: "On Vehicles",
                icon: "car.fill",
                color: .green,
                format: .currency
            )
            
            FinancialMetricCard(
                title: periodSpending(summary: summary),
                value: periodSpendingValue(summary: summary),
                subtitle: "Purchase Orders",
                icon: "doc.text.fill",
                color: .orange,
                format: .currency
            )
            
            FinancialMetricCard(
                title: "Average Vehicle Value",
                value: summary.averageVehicleValue,
                subtitle: "Per Vehicle",
                icon: "chart.bar.fill",
                color: .purple,
                format: .currency
            )
            
            FinancialMetricCard(
                title: "Monthly Burn Rate",
                value: summary.monthlyBurnRate,
                subtitle: "Spending Rate",
                icon: "flame.fill",
                color: .red,
                format: .currency
            )
            
            FinancialMetricCard(
                title: "Inventory Turnover",
                value: summary.inventoryTurnoverRate,
                subtitle: "Times per Year",
                icon: "arrow.clockwise",
                color: .indigo,
                format: .decimal
            )
        }
    }
    
    private var financialChartsSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Revenue vs Costs chart
                ChartCard(title: "Revenue vs Costs") {
                    Chart {
                        ForEach(financialManager.periodData, id: \.period) { data in
                            BarMark(
                                x: .value("Period", data.period),
                                y: .value("Revenue", data.revenue)
                            )
                            .foregroundStyle(.green)
                            
                            BarMark(
                                x: .value("Period", data.period),
                                y: .value("Costs", data.costs)
                            )
                            .foregroundStyle(.red)
                        }
                    }
                    .frame(height: 200)
                    .chartYAxis {
                        AxisMarks(format: .currency(code: "USD"))
                    }
                }
                
                // Purchase order trends
                ChartCard(title: "Purchase Order Trends") {
                    Chart {
                        ForEach(financialManager.purchaseOrderData, id: \.month) { data in
                            LineMark(
                                x: .value("Month", data.month),
                                y: .value("Spending", data.totalSpent)
                            )
                            .foregroundStyle(.blue.gradient)
                            .lineStyle(StrokeStyle(lineWidth: 3))
                        }
                    }
                    .frame(height: 200)
                    .chartYAxis {
                        AxisMarks(format: .currency(code: "USD"))
                    }
                }
            }
        }
    }
    
    private var vehicleInventorySection: some View {
        ChartCard(title: "Vehicle Inventory Breakdown") {
            VStack(spacing: 12) {
                ForEach(financialManager.vehicleFinancialData.prefix(10), id: \.vehicle.id) { data in
                    VehicleFinancialRow(data: data)
                }
                
                if financialManager.vehicleFinancialData.count > 10 {
                    Text("+ \(financialManager.vehicleFinancialData.count - 10) more vehicles")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var purchaseOrderSection: some View {
        ChartCard(title: "Purchase Order Analysis") {
            VStack(spacing: 12) {
                ForEach(financialManager.purchaseOrderData.prefix(6), id: \.month) { data in
                    PurchaseOrderFinancialRow(data: data)
                }
            }
        }
    }
    
    private func periodSpending(summary: FinancialSummary) -> String {
        switch selectedPeriod {
        case .monthly: return "Monthly Spending"
        case .quarterly: return "Quarterly Spending"
        case .yearly: return "Yearly Spending"
        }
    }
    
    private func periodSpendingValue(summary: FinancialSummary) -> Double {
        switch selectedPeriod {
        case .monthly: return summary.monthlyPOSpending
        case .quarterly: return summary.quarterlyPOSpending
        case .yearly: return summary.yearlyPOSpending
        }
    }
}

// MARK: - Supporting Views

struct FinancialMetricCard: View {
    let title: String
    let value: Double
    let subtitle: String
    let icon: String
    let color: Color
    let format: MetricFormat
    
    enum MetricFormat {
        case currency
        case decimal
        case percentage
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                
                Spacer()
                
                Text(formattedValue)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            Text(title)
                .font(.headline)
                .lineLimit(1)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2)
    }
    
    private var formattedValue: String {
        switch format {
        case .currency:
            return NumberFormatter.currency.string(from: NSNumber(value: value)) ?? "$0"
        case .decimal:
            return String(format: "%.2f", value)
        case .percentage:
            return String(format: "%.1f%%", value)
        }
    }
}

struct VehicleFinancialRow: View {
    let data: VehicleFinancialData
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(data.vehicle.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(data.itemCount) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(NumberFormatter.currency.string(from: NSNumber(value: data.inventoryValue)) ?? "$0")
                    .font(.subheadline)
                    .fontWeight(.bold)
                
                Text("\(Int(data.utilizationRate * 100))% utilized")
                    .font(.caption)
                    .foregroundColor(data.utilizationRate > 0.7 ? .green : .orange)
            }
        }
        .padding(.vertical, 4)
    }
}

struct PurchaseOrderFinancialRow: View {
    let data: PurchaseOrderFinancialData
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(data.month)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(data.orderCount) orders")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(NumberFormatter.currency.string(from: NSNumber(value: data.totalSpent)) ?? "$0")
                    .font(.subheadline)
                    .fontWeight(.bold)
                
                Text("Avg: \(NumberFormatter.currency.string(from: NSNumber(value: data.averageOrderValue)) ?? "$0")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct DetailedFinancialReportView: View {
    @Environment(\.dismiss) private var dismiss
    let financialManager: FinancialTrackingManager
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Detailed Financial Report")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding()
                    
                    // Comprehensive financial analysis would go here
                    Text("Comprehensive financial analysis coming soon...")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
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

// MARK: - Extensions

extension NumberFormatter {
    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter
    }()
} 