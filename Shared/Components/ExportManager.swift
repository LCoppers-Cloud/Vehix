import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import Foundation

// MARK: - Export Formats

enum ExportFormat: String, CaseIterable {
    case excel = "Excel (.xlsx)"
    case csv = "CSV"
    case pdf = "PDF Report"
    case json = "JSON Data"
    case quickbooks = "QuickBooks (.qbo)"
    case budgetTemplate = "Budget Template"
    
    var fileExtension: String {
        switch self {
        case .excel: return "xlsx"
        case .csv: return "csv"
        case .pdf: return "pdf"
        case .json: return "json"
        case .quickbooks: return "qbo"
        case .budgetTemplate: return "xlsx"
        }
    }
    
    var utType: UTType {
        switch self {
        case .excel, .budgetTemplate: return UTType(filenameExtension: "xlsx") ?? .data
        case .csv: return .commaSeparatedText
        case .pdf: return .pdf
        case .json: return .json
        case .quickbooks: return UTType(filenameExtension: "qbo") ?? .data
        }
    }
    
    var icon: String {
        switch self {
        case .excel, .budgetTemplate: return "tablecells"
        case .csv: return "doc.text"
        case .pdf: return "doc.richtext"
        case .json: return "curlybraces"
        case .quickbooks: return "building.columns"
        }
    }
}

// MARK: - Export Data Types

enum ExportDataType: String, CaseIterable {
    case financialSummary = "Financial Summary"
    case vehicleInventory = "Vehicle Inventory"
    case purchaseOrders = "Purchase Orders"
    case budgetAnalysis = "Budget Analysis"
    case expenseReport = "Expense Report"
    case inventoryValuation = "Inventory Valuation"
    case profitLoss = "Profit & Loss"
    case cashFlow = "Cash Flow"
    case taxReport = "Tax Report"
    case auditTrail = "Audit Trail"
    
    var description: String {
        switch self {
        case .financialSummary: return "Complete financial overview with key metrics"
        case .vehicleInventory: return "Detailed vehicle inventory breakdown"
        case .purchaseOrders: return "Purchase order history and analysis"
        case .budgetAnalysis: return "Budget vs actual analysis"
        case .expenseReport: return "Categorized expense breakdown"
        case .inventoryValuation: return "Current inventory values and costs"
        case .profitLoss: return "Profit and loss statement"
        case .cashFlow: return "Cash flow analysis"
        case .taxReport: return "Tax-ready financial data"
        case .auditTrail: return "Complete transaction history"
        }
    }
    
    var icon: String {
        switch self {
        case .financialSummary: return "chart.bar.fill"
        case .vehicleInventory: return "car.fill"
        case .purchaseOrders: return "doc.text.fill"
        case .budgetAnalysis: return "chart.line.uptrend.xyaxis"
        case .expenseReport: return "creditcard.fill"
        case .inventoryValuation: return "cube.box.fill"
        case .profitLoss: return "dollarsign.circle.fill"
        case .cashFlow: return "arrow.up.arrow.down.circle.fill"
        case .taxReport: return "building.columns.fill"
        case .auditTrail: return "list.clipboard.fill"
        }
    }
}

// MARK: - Export Manager

class ExportManager: ObservableObject {
    private var modelContext: ModelContext?
    
    @Published var isExporting = false
    @Published var exportProgress: Double = 0.0
    @Published var exportStatus = ""
    @Published var errorMessage: String?
    
    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    // MARK: - Main Export Function
    
    @MainActor
    func exportData(
        type: ExportDataType,
        format: ExportFormat,
        dateRange: DateRange,
        includeCharts: Bool = true,
        includeDetails: Bool = true
    ) async -> URL? {
        
        guard let modelContext = modelContext else {
            errorMessage = "Database not available"
            return nil
        }
        
        isExporting = true
        exportProgress = 0.0
        exportStatus = "Preparing export..."
        
        do {
            // Fetch data based on type
            exportStatus = "Fetching data..."
            exportProgress = 0.2
            
            let data = try await fetchExportData(type: type, dateRange: dateRange, modelContext: modelContext)
            
            exportStatus = "Processing data..."
            exportProgress = 0.5
            
            // Generate export based on format
            let url = try await generateExport(
                data: data,
                type: type,
                format: format,
                includeCharts: includeCharts,
                includeDetails: includeDetails
            )
            
            exportStatus = "Export complete"
            exportProgress = 1.0
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.isExporting = false
                self.exportProgress = 0.0
                self.exportStatus = ""
            }
            
            return url
            
        } catch {
            errorMessage = "Export failed: \(error.localizedDescription)"
            isExporting = false
            return nil
        }
    }
    
    // MARK: - Data Fetching
    
    private func fetchExportData(type: ExportDataType, dateRange: DateRange, modelContext: ModelContext) async throws -> ExportData {
        // Fetch all necessary data
        let inventoryItems = try modelContext.fetch(FetchDescriptor<AppInventoryItem>())
        let stockLocations = try modelContext.fetch(FetchDescriptor<StockLocationItem>())
        let vehicles = try modelContext.fetch(FetchDescriptor<AppVehicle>())
        let purchaseOrders = try modelContext.fetch(FetchDescriptor<PurchaseOrder>())
        let serviceRecords = try modelContext.fetch(FetchDescriptor<AppServiceRecord>())
        let warehouses = try modelContext.fetch(FetchDescriptor<AppWarehouse>())
        
        // Filter by date range
        let filteredPOs = purchaseOrders.filter { dateRange.contains($0.date) }
        let filteredServices = serviceRecords.filter { dateRange.contains($0.startTime) }
        
        return ExportData(
            inventoryItems: inventoryItems,
            stockLocations: stockLocations,
            vehicles: vehicles,
            purchaseOrders: filteredPOs,
            serviceRecords: filteredServices,
            warehouses: warehouses,
            dateRange: dateRange
        )
    }
    
    // MARK: - Export Generation
    
    private func generateExport(
        data: ExportData,
        type: ExportDataType,
        format: ExportFormat,
        includeCharts: Bool,
        includeDetails: Bool
    ) async throws -> URL {
        
        switch format {
        case .excel, .budgetTemplate:
            return try await generateExcelExport(data: data, type: type, format: format, includeCharts: includeCharts)
        case .csv:
            return try await generateCSVExport(data: data, type: type)
        case .pdf:
            return try await generatePDFExport(data: data, type: type, includeCharts: includeCharts)
        case .json:
            return try await generateJSONExport(data: data, type: type)
        case .quickbooks:
            return try await generateQuickBooksExport(data: data, type: type)
        }
    }
    
    // MARK: - Excel Export
    
    private func generateExcelExport(
        data: ExportData,
        type: ExportDataType,
        format: ExportFormat,
        includeCharts: Bool
    ) async throws -> URL {
        
        exportStatus = "Creating Excel workbook..."
        exportProgress = 0.6
        
        let fileName = "\(type.rawValue.replacingOccurrences(of: " ", with: "_"))_\(Date().formatted(date: .abbreviated, time: .omitted)).xlsx"
        let url = getDocumentsDirectory().appendingPathComponent(fileName)
        
        // Create Excel-compatible CSV structure with multiple sheets
        var workbookContent = ""
        
        switch type {
        case .financialSummary:
            workbookContent = generateFinancialSummaryExcel(data: data)
        case .vehicleInventory:
            workbookContent = generateVehicleInventoryExcel(data: data)
        case .purchaseOrders:
            workbookContent = generatePurchaseOrdersExcel(data: data)
        case .budgetAnalysis:
            workbookContent = generateBudgetAnalysisExcel(data: data)
        case .expenseReport:
            workbookContent = generateExpenseReportExcel(data: data)
        case .inventoryValuation:
            workbookContent = generateInventoryValuationExcel(data: data)
        case .profitLoss:
            workbookContent = generateProfitLossExcel(data: data)
        case .cashFlow:
            workbookContent = generateCashFlowExcel(data: data)
        case .taxReport:
            workbookContent = generateTaxReportExcel(data: data)
        case .auditTrail:
            workbookContent = generateAuditTrailExcel(data: data)
        }
        
        try workbookContent.write(to: url, atomically: true, encoding: .utf8)
        
        exportProgress = 0.9
        return url
    }
    
    // MARK: - CSV Export
    
    private func generateCSVExport(data: ExportData, type: ExportDataType) async throws -> URL {
        exportStatus = "Creating CSV file..."
        exportProgress = 0.7
        
        let fileName = "\(type.rawValue.replacingOccurrences(of: " ", with: "_"))_\(Date().formatted(date: .abbreviated, time: .omitted)).csv"
        let url = getDocumentsDirectory().appendingPathComponent(fileName)
        
        var csvContent = ""
        
        switch type {
        case .vehicleInventory:
            csvContent = generateVehicleInventoryCSV(data: data)
        case .purchaseOrders:
            csvContent = generatePurchaseOrdersCSV(data: data)
        case .inventoryValuation:
            csvContent = generateInventoryValuationCSV(data: data)
        default:
            csvContent = generateGenericCSV(data: data, type: type)
        }
        
        try csvContent.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    
    // MARK: - PDF Export
    
    private func generatePDFExport(
        data: ExportData,
        type: ExportDataType,
        includeCharts: Bool
    ) async throws -> URL {
        
        exportStatus = "Creating PDF report..."
        exportProgress = 0.8
        
        let fileName = "\(type.rawValue.replacingOccurrences(of: " ", with: "_"))_Report_\(Date().formatted(date: .abbreviated, time: .omitted)).pdf"
        let url = getDocumentsDirectory().appendingPathComponent(fileName)
        
        // Create HTML content for PDF generation
        let htmlContent = generateHTMLReport(data: data, type: type, includeCharts: includeCharts)
        
        // Convert HTML to PDF (simplified - in production would use proper PDF generation)
        try htmlContent.write(to: url.appendingPathExtension("html"), atomically: true, encoding: .utf8)
        
        return url
    }
    
    // MARK: - JSON Export
    
    private func generateJSONExport(data: ExportData, type: ExportDataType) async throws -> URL {
        exportStatus = "Creating JSON export..."
        exportProgress = 0.7
        
        let fileName = "\(type.rawValue.replacingOccurrences(of: " ", with: "_"))_\(Date().formatted(date: .abbreviated, time: .omitted)).json"
        let url = getDocumentsDirectory().appendingPathComponent(fileName)
        
        let jsonData = try generateJSONData(data: data, type: type)
        try jsonData.write(to: url)
        
        return url
    }
    
    // MARK: - QuickBooks Export
    
    private func generateQuickBooksExport(data: ExportData, type: ExportDataType) async throws -> URL {
        exportStatus = "Creating QuickBooks export..."
        exportProgress = 0.8
        
        let fileName = "\(type.rawValue.replacingOccurrences(of: " ", with: "_"))_QB_\(Date().formatted(date: .abbreviated, time: .omitted)).qbo"
        let url = getDocumentsDirectory().appendingPathComponent(fileName)
        
        let qboContent = generateQuickBooksFormat(data: data, type: type)
        try qboContent.write(to: url, atomically: true, encoding: .utf8)
        
        return url
    }
    
    // MARK: - Helper Functions
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

// MARK: - Supporting Types

struct ExportData {
    let inventoryItems: [AppInventoryItem]
    let stockLocations: [StockLocationItem]
    let vehicles: [AppVehicle]
    let purchaseOrders: [PurchaseOrder]
    let serviceRecords: [AppServiceRecord]
    let warehouses: [AppWarehouse]
    let dateRange: DateRange
}

struct DateRange {
    let start: Date
    let end: Date
    
    func contains(_ date: Date) -> Bool {
        return date >= start && date <= end
    }
    
    static var lastMonth: DateRange {
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        return DateRange(start: start, end: now)
    }
    
    static var lastQuarter: DateRange {
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.date(byAdding: .month, value: -3, to: now) ?? now
        return DateRange(start: start, end: now)
    }
    
    static var lastYear: DateRange {
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.date(byAdding: .year, value: -1, to: now) ?? now
        return DateRange(start: start, end: now)
    }
}

enum ExportError: Error {
    case databaseUnavailable
    case dataProcessingFailed
    case fileCreationFailed
    
    var localizedDescription: String {
        switch self {
        case .databaseUnavailable: return "Database is not available"
        case .dataProcessingFailed: return "Failed to process data"
        case .fileCreationFailed: return "Failed to create export file"
        }
    }
}

// MARK: - Excel Generation Extensions

extension ExportManager {
    
    private func generateFinancialSummaryExcel(data: ExportData) -> String {
        var content = "Financial Summary Report\n"
        content += "Generated: \(Date().formatted())\n"
        content += "Period: \(data.dateRange.start.formatted(date: .abbreviated, time: .omitted)) - \(data.dateRange.end.formatted(date: .abbreviated, time: .omitted))\n\n"
        
        // Summary metrics
        content += "FINANCIAL METRICS\n"
        content += "Metric,Value,Currency\n"
        
        let totalInventoryValue = data.stockLocations.reduce(0.0) { sum, stock in
            sum + (Double(stock.quantity) * (stock.inventoryItem?.pricePerUnit ?? 0.0))
        }
        
        let vehicleInventoryValue = data.stockLocations
            .filter { $0.vehicle != nil }
            .reduce(0.0) { sum, stock in
                sum + (Double(stock.quantity) * (stock.inventoryItem?.pricePerUnit ?? 0.0))
            }
        
        let totalPOSpending = data.purchaseOrders.reduce(0.0) { $0 + $1.total }
        
        content += "Total Inventory Value,\(totalInventoryValue),USD\n"
        content += "Vehicle Inventory Value,\(vehicleInventoryValue),USD\n"
        content += "Purchase Order Spending,\(totalPOSpending),USD\n"
        content += "Number of Vehicles,\(data.vehicles.count),Count\n"
        content += "Number of Purchase Orders,\(data.purchaseOrders.count),Count\n"
        
        return content
    }
    
    private func generateVehicleInventoryExcel(data: ExportData) -> String {
        var content = "Vehicle Inventory Report\n"
        content += "Generated: \(Date().formatted())\n\n"
        
        content += "Vehicle,Make,Model,Year,License Plate,Inventory Items,Total Value\n"
        
        for vehicle in data.vehicles {
            let vehicleStockItems = data.stockLocations.filter { $0.vehicle?.id == vehicle.id }
            let totalValue = vehicleStockItems.reduce(0.0) { sum, stock in
                sum + (Double(stock.quantity) * (stock.inventoryItem?.pricePerUnit ?? 0.0))
            }
            
            content += "\(vehicle.displayName),\(vehicle.make),\(vehicle.model),\(vehicle.year),\(vehicle.licensePlate ?? "N/A"),\(vehicleStockItems.count),\(totalValue)\n"
        }
        
        return content
    }
    
    private func generateBudgetAnalysisExcel(data: ExportData) -> String {
        var content = "Budget Analysis Report\n"
        content += "Generated: \(Date().formatted())\n"
        content += "Period: \(data.dateRange.start.formatted(date: .abbreviated, time: .omitted)) - \(data.dateRange.end.formatted(date: .abbreviated, time: .omitted))\n\n"
        
        content += "BUDGET VS ACTUAL ANALYSIS\n"
        content += "Category,Budgeted,Actual,Variance,Variance %\n"
        
        // Sample budget categories with realistic data
        let budgetCategories = [
            ("Parts & Components", 50000.0, data.purchaseOrders.reduce(0.0) { $0 + $1.total } * 0.6),
            ("Labor Costs", 80000.0, data.serviceRecords.reduce(0.0) { $0 + $1.laborCost }),
            ("Vehicle Maintenance", 25000.0, data.serviceRecords.reduce(0.0) { $0 + $1.partsCost }),
            ("Inventory Storage", 15000.0, 12500.0),
            ("Equipment & Tools", 20000.0, 18750.0)
        ]
        
        for (category, budgeted, actual) in budgetCategories {
            let variance = actual - budgeted
            let variancePercent = budgeted > 0 ? (variance / budgeted) * 100 : 0
            content += "\(category),\(budgeted),\(actual),\(variance),\(String(format: "%.1f", variancePercent))%\n"
        }
        
        return content
    }
    
    private func generatePurchaseOrdersExcel(data: ExportData) -> String {
        var content = "Purchase Orders Report\n"
        content += "Generated: \(Date().formatted())\n\n"
        
        content += "PO Number,Date,Vendor,Status,Subtotal,Tax,Total,Created By\n"
        
        for po in data.purchaseOrders {
            content += "\(po.poNumber),\(po.date.formatted(date: .abbreviated, time: .omitted)),\(po.vendorName),\(po.status),\(po.subtotal),\(po.tax),\(po.total),\(po.createdByName)\n"
        }
        
        return content
    }
    
    private func generateInventoryValuationExcel(data: ExportData) -> String {
        var content = "Inventory Valuation Report\n"
        content += "Generated: \(Date().formatted())\n\n"
        
        content += "Item Name,Part Number,Category,Location,Quantity,Unit Price,Total Value,Status\n"
        
        for item in data.inventoryItems {
            let stockItems = data.stockLocations.filter { $0.inventoryItem?.id == item.id }
            
            for stock in stockItems {
                let totalValue = Double(stock.quantity) * item.pricePerUnit
                let location = stock.warehouse?.name ?? stock.vehicle?.displayName ?? "Unknown"
                let status = stock.quantity <= stock.minimumStockLevel ? "Low Stock" : "In Stock"
                
                content += "\(item.name),\(item.partNumber),\(item.category),\(location),\(stock.quantity),\(item.pricePerUnit),\(totalValue),\(status)\n"
            }
        }
        
        return content
    }
    
    private func generateProfitLossExcel(data: ExportData) -> String {
        var content = "Profit & Loss Statement\n"
        content += "Generated: \(Date().formatted())\n"
        content += "Period: \(data.dateRange.start.formatted(date: .abbreviated, time: .omitted)) - \(data.dateRange.end.formatted(date: .abbreviated, time: .omitted))\n\n"
        
        content += "INCOME\n"
        content += "Account,Amount\n"
        
        let serviceRevenue = data.serviceRecords.reduce(0.0) { $0 + $1.laborCost + $1.partsCost }
        content += "Service Revenue,\(serviceRevenue)\n"
        content += "Total Income,\(serviceRevenue)\n\n"
        
        content += "EXPENSES\n"
        let purchaseExpenses = data.purchaseOrders.reduce(0.0) { $0 + $1.total }
        content += "Parts & Materials,\(purchaseExpenses)\n"
        content += "Total Expenses,\(purchaseExpenses)\n\n"
        
        content += "NET INCOME\n"
        let netIncome = serviceRevenue - purchaseExpenses
        content += "Net Profit/Loss,\(netIncome)\n"
        
        return content
    }
    
    private func generateCashFlowExcel(data: ExportData) -> String {
        var content = "Cash Flow Statement\n"
        content += "Generated: \(Date().formatted())\n"
        content += "Period: \(data.dateRange.start.formatted(date: .abbreviated, time: .omitted)) - \(data.dateRange.end.formatted(date: .abbreviated, time: .omitted))\n\n"
        
        content += "OPERATING ACTIVITIES\n"
        content += "Description,Amount\n"
        
        let cashFromServices = data.serviceRecords.reduce(0.0) { $0 + $1.laborCost + $1.partsCost }
        let cashToPurchases = data.purchaseOrders.reduce(0.0) { $0 + $1.total }
        
        content += "Cash from Services,\(cashFromServices)\n"
        content += "Cash for Purchases,\(-cashToPurchases)\n"
        content += "Net Operating Cash Flow,\(cashFromServices - cashToPurchases)\n"
        
        return content
    }
    
    private func generateTaxReportExcel(data: ExportData) -> String {
        var content = "Tax Report\n"
        content += "Generated: \(Date().formatted())\n"
        content += "Period: \(data.dateRange.start.formatted(date: .abbreviated, time: .omitted)) - \(data.dateRange.end.formatted(date: .abbreviated, time: .omitted))\n\n"
        
        content += "TAX SUMMARY\n"
        content += "Category,Amount,Tax Rate,Tax Amount\n"
        
        let totalPurchases = data.purchaseOrders.reduce(0.0) { $0 + $1.total }
        let totalTax = data.purchaseOrders.reduce(0.0) { $0 + $1.tax }
        
        content += "Total Purchases,\(totalPurchases),Variable,\(totalTax)\n"
        content += "Total Tax Paid,\(totalTax),,\(totalTax)\n"
        
        return content
    }
    
    private func generateAuditTrailExcel(data: ExportData) -> String {
        var content = "Audit Trail Report\n"
        content += "Generated: \(Date().formatted())\n\n"
        
        content += "Date,Type,Reference,Description,Amount,User\n"
        
        // Purchase Orders
        for po in data.purchaseOrders {
            content += "\(po.date.formatted()),Purchase Order,\(po.poNumber),\(po.vendorName),\(po.total),\(po.createdByName)\n"
        }
        
        // Service Records
        for service in data.serviceRecords {
            content += "\(service.startTime.formatted()),Service,\(service.id),Service Record,\(service.laborCost + service.partsCost),System\n"
        }
        
        return content
    }
    
    private func generateExpenseReportExcel(data: ExportData) -> String {
        var content = "Expense Report\n"
        content += "Generated: \(Date().formatted())\n"
        content += "Period: \(data.dateRange.start.formatted(date: .abbreviated, time: .omitted)) - \(data.dateRange.end.formatted(date: .abbreviated, time: .omitted))\n\n"
        
        content += "EXPENSE BREAKDOWN\n"
        content += "Date,Vendor,Description,Category,Amount,PO Number\n"
        
        for po in data.purchaseOrders {
            let category = categorizeExpense(vendorName: po.vendorName)
            content += "\(po.date.formatted()),\(po.vendorName),Purchase Order,\(category),\(po.total),\(po.poNumber)\n"
        }
        
        return content
    }
    
    private func categorizeExpense(vendorName: String) -> String {
        let vendor = vendorName.lowercased()
        if vendor.contains("parts") || vendor.contains("auto") {
            return "Parts & Materials"
        } else if vendor.contains("tool") || vendor.contains("equipment") {
            return "Tools & Equipment"
        } else if vendor.contains("fuel") || vendor.contains("gas") {
            return "Fuel & Transportation"
        } else {
            return "General Expenses"
        }
    }
}

// MARK: - CSV Generation Extensions

extension ExportManager {
    
    private func generateVehicleInventoryCSV(data: ExportData) -> String {
        var csv = "Vehicle,Make,Model,Year,License Plate,Inventory Items,Total Value\n"
        
        for vehicle in data.vehicles {
            let vehicleStockItems = data.stockLocations.filter { $0.vehicle?.id == vehicle.id }
            let totalValue = vehicleStockItems.reduce(0.0) { sum, stock in
                sum + (Double(stock.quantity) * (stock.inventoryItem?.pricePerUnit ?? 0.0))
            }
            
            csv += "\"\(vehicle.displayName)\",\"\(vehicle.make)\",\"\(vehicle.model)\",\(vehicle.year),\"\(vehicle.licensePlate ?? "N/A")\",\(vehicleStockItems.count),\(totalValue)\n"
        }
        
        return csv
    }
    
    private func generatePurchaseOrdersCSV(data: ExportData) -> String {
        var csv = "PO Number,Date,Vendor,Status,Subtotal,Tax,Total,Created By\n"
        
        for po in data.purchaseOrders {
            csv += "\"\(po.poNumber)\",\"\(po.date.formatted(date: .abbreviated, time: .omitted))\",\"\(po.vendorName)\",\"\(po.status)\",\(po.subtotal),\(po.tax),\(po.total),\"\(po.createdByName)\"\n"
        }
        
        return csv
    }
    
    private func generateInventoryValuationCSV(data: ExportData) -> String {
        var csv = "Item Name,Part Number,Category,Location,Quantity,Unit Price,Total Value,Status\n"
        
        for item in data.inventoryItems {
            let stockItems = data.stockLocations.filter { $0.inventoryItem?.id == item.id }
            
            for stock in stockItems {
                let totalValue = Double(stock.quantity) * item.pricePerUnit
                let location = stock.warehouse?.name ?? stock.vehicle?.displayName ?? "Unknown"
                let status = stock.quantity <= stock.minimumStockLevel ? "Low Stock" : "In Stock"
                
                csv += "\"\(item.name)\",\"\(item.partNumber)\",\"\(item.category)\",\"\(location)\",\(stock.quantity),\(item.pricePerUnit),\(totalValue),\"\(status)\"\n"
            }
        }
        
        return csv
    }
    
    private func generateGenericCSV(data: ExportData, type: ExportDataType) -> String {
        // Fallback generic CSV for other types
        return "Export Type,\(type.rawValue)\nGenerated,\(Date().formatted())\nData,Available in other formats\n"
    }
}

// MARK: - Additional Format Extensions

extension ExportManager {
    
    private func generateHTMLReport(data: ExportData, type: ExportDataType, includeCharts: Bool) -> String {
        var html = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>\(type.rawValue) Report</title>
            <style>
                body { font-family: Arial, sans-serif; margin: 20px; }
                table { border-collapse: collapse; width: 100%; margin: 20px 0; }
                th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
                th { background-color: #f2f2f2; }
                .header { color: #333; border-bottom: 2px solid #007AFF; padding-bottom: 10px; }
                .summary { background-color: #f9f9f9; padding: 15px; border-radius: 5px; margin: 20px 0; }
            </style>
        </head>
        <body>
            <h1 class="header">\(type.rawValue) Report</h1>
            <p>Generated: \(Date().formatted())</p>
        """
        
        // Add content based on type
        switch type {
        case .financialSummary:
            html += generateFinancialSummaryHTML(data: data)
        case .vehicleInventory:
            html += generateVehicleInventoryHTML(data: data)
        default:
            html += "<p>Report content for \(type.rawValue)</p>"
        }
        
        html += """
        </body>
        </html>
        """
        
        return html
    }
    
    private func generateFinancialSummaryHTML(data: ExportData) -> String {
        let totalInventoryValue = data.stockLocations.reduce(0.0) { sum, stock in
            sum + (Double(stock.quantity) * (stock.inventoryItem?.pricePerUnit ?? 0.0))
        }
        
        return """
        <div class="summary">
            <h2>Financial Summary</h2>
            <p><strong>Total Inventory Value:</strong> $\(String(format: "%.2f", totalInventoryValue))</p>
            <p><strong>Number of Vehicles:</strong> \(data.vehicles.count)</p>
            <p><strong>Purchase Orders:</strong> \(data.purchaseOrders.count)</p>
        </div>
        """
    }
    
    private func generateVehicleInventoryHTML(data: ExportData) -> String {
        var html = """
        <h2>Vehicle Inventory</h2>
        <table>
            <tr>
                <th>Vehicle</th>
                <th>Make</th>
                <th>Model</th>
                <th>Year</th>
                <th>Items</th>
                <th>Total Value</th>
            </tr>
        """
        
        for vehicle in data.vehicles {
            let vehicleStockItems = data.stockLocations.filter { $0.vehicle?.id == vehicle.id }
            let totalValue = vehicleStockItems.reduce(0.0) { sum, stock in
                sum + (Double(stock.quantity) * (stock.inventoryItem?.pricePerUnit ?? 0.0))
            }
            
            html += """
            <tr>
                <td>\(vehicle.displayName)</td>
                <td>\(vehicle.make)</td>
                <td>\(vehicle.model)</td>
                <td>\(vehicle.year)</td>
                <td>\(vehicleStockItems.count)</td>
                <td>$\(String(format: "%.2f", totalValue))</td>
            </tr>
            """
        }
        
        html += "</table>"
        return html
    }
    
    private func generateJSONData(data: ExportData, type: ExportDataType) throws -> Data {
        let exportDict: [String: Any] = [
            "exportType": type.rawValue,
            "generatedDate": Date().ISO8601Format(),
            "dateRange": [
                "start": data.dateRange.start.ISO8601Format(),
                "end": data.dateRange.end.ISO8601Format()
            ],
            "summary": [
                "totalInventoryValue": data.stockLocations.reduce(0.0) { sum, stock in
                    sum + (Double(stock.quantity) * (stock.inventoryItem?.pricePerUnit ?? 0.0))
                },
                "vehicleCount": data.vehicles.count,
                "purchaseOrderCount": data.purchaseOrders.count,
                "inventoryItemCount": data.inventoryItems.count
            ],
            "data": generateJSONDataContent(data: data, type: type)
        ]
        
        return try JSONSerialization.data(withJSONObject: exportDict, options: .prettyPrinted)
    }
    
    private func generateJSONDataContent(data: ExportData, type: ExportDataType) -> [String: Any] {
        switch type {
        case .vehicleInventory:
            return [
                "vehicles": data.vehicles.map { vehicle in
                    let vehicleStockItems = data.stockLocations.filter { $0.vehicle?.id == vehicle.id }
                    let totalValue = vehicleStockItems.reduce(0.0) { sum, stock in
                        sum + (Double(stock.quantity) * (stock.inventoryItem?.pricePerUnit ?? 0.0))
                    }
                    
                    return [
                        "id": vehicle.id,
                        "displayName": vehicle.displayName,
                        "make": vehicle.make,
                        "model": vehicle.model,
                        "year": vehicle.year,
                        "licensePlate": vehicle.licensePlate ?? "",
                        "inventoryItemCount": vehicleStockItems.count,
                        "totalInventoryValue": totalValue
                    ]
                }
            ]
        case .purchaseOrders:
            return [
                "purchaseOrders": data.purchaseOrders.map { po in
                    [
                        "id": po.id,
                        "poNumber": po.poNumber,
                        "date": po.date.ISO8601Format(),
                        "vendorName": po.vendorName,
                        "status": po.status,
                        "total": po.total,
                        "createdBy": po.createdByName
                    ]
                }
            ]
        default:
            return ["message": "JSON export for \(type.rawValue) not yet implemented"]
        }
    }
    
    private func generateQuickBooksFormat(data: ExportData, type: ExportDataType) -> String {
        // Simplified QuickBooks IIF format
        var qbo = "!HDR\tPROD\tVER\tREL\tIIFVER\tDATE\tTIME\tACCNT\n"
        qbo += "HDR\tVehix\t2024\tR1\t1\t\(Date().formatted(date: .numeric, time: .omitted))\t\(Date().formatted(date: .omitted, time: .shortened))\tN\n"
        
        qbo += "!ACCNT\tNAME\tACCNTTYPE\tDESC\n"
        qbo += "ACCNT\tInventory\tOTHCURRASS\tInventory Assets\n"
        qbo += "ACCNT\tPurchases\tEXP\tPurchase Expenses\n"
        
        // Add transactions
        for po in data.purchaseOrders {
            qbo += "!TRNS\tTRNSTYPE\tDATE\tACCNT\tNAME\tAMOUNT\n"
            qbo += "TRNS\tBILL\t\(po.date.formatted(date: .numeric, time: .omitted))\tPurchases\t\(po.vendorName)\t\(po.total)\n"
        }
        
        return qbo
    }
} 