import SwiftUI
import UniformTypeIdentifiers

struct ExportOptionsView: View {
    let inventoryItems: [InventoryItemStatus]
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedExportType: ExportType = .inventoryList
    @State private var selectedFormat: ExportFormat = .csv
    @State private var includeImages = false
    @State private var includeInactiveItems = false
    @State private var selectedDateRange: DateRange = .allTime
    @State private var customStartDate = Date()
    @State private var customEndDate = Date()
    @State private var isExporting = false
    @State private var exportProgress: Double = 0.0
    @State private var showingExportComplete = false
    @State private var exportedFileURL: URL?
    
    enum ExportType: String, CaseIterable {
        case inventoryList = "Inventory List"
        case stockLevels = "Stock Levels"
        case warehouseReport = "Warehouse Report"
        case vehicleInventory = "Vehicle Inventory"
        case lowStockReport = "Low Stock Report"
        case costAnalysis = "Cost Analysis"
        case usageReport = "Usage Report"
        
        var description: String {
            switch self {
            case .inventoryList:
                return "Complete list of all inventory items with details"
            case .stockLevels:
                return "Current stock levels across all locations"
            case .warehouseReport:
                return "Warehouse inventory breakdown and analytics"
            case .vehicleInventory:
                return "Inventory currently on vehicles"
            case .lowStockReport:
                return "Items below minimum stock levels"
            case .costAnalysis:
                return "Inventory costs and value analysis"
            case .usageReport:
                return "Inventory usage and consumption patterns"
            }
        }
    }
    
    enum ExportFormat: String, CaseIterable {
        case csv = "CSV"
        case excel = "Excel"
        case pdf = "PDF"
        case json = "JSON"
        
        var fileExtension: String {
            switch self {
            case .csv: return "csv"
            case .excel: return "xlsx"
            case .pdf: return "pdf"
            case .json: return "json"
            }
        }
        
        var contentType: UTType {
            switch self {
            case .csv: return .commaSeparatedText
            case .excel: return UTType("com.microsoft.excel.xlsx") ?? .data
            case .pdf: return .pdf
            case .json: return .json
            }
        }
    }
    
    enum DateRange: String, CaseIterable {
        case allTime = "All Time"
        case lastMonth = "Last Month"
        case lastQuarter = "Last Quarter"
        case lastYear = "Last Year"
        case custom = "Custom Range"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isExporting {
                    exportProgressView
                } else {
                    exportOptionsForm
                }
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Export") {
                        startExport()
                    }
                    .disabled(isExporting)
                }
            }
            .alert("Export Complete", isPresented: $showingExportComplete) {
                Button("Share") {
                    shareExportedFile()
                }
                Button("OK") { }
            } message: {
                Text("Your \(selectedExportType.rawValue) has been exported successfully.")
            }
        }
    }
    
    private var exportOptionsForm: some View {
        Form {
            Section("Export Type") {
                Picker("Type", selection: $selectedExportType) {
                    ForEach(ExportType.allCases, id: \.self) { type in
                        VStack(alignment: .leading) {
                            Text(type.rawValue)
                                .font(.headline)
                            Text(type.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .tag(type)
                    }
                }
                .pickerStyle(.menu)
            }
            
            Section("Format") {
                Picker("Format", selection: $selectedFormat) {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            Section("Date Range") {
                Picker("Range", selection: $selectedDateRange) {
                    ForEach(DateRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.menu)
                
                if selectedDateRange == .custom {
                    DatePicker("From", selection: $customStartDate, displayedComponents: .date)
                    DatePicker("To", selection: $customEndDate, displayedComponents: .date)
                }
            }
            
            Section("Options") {
                Toggle("Include Images", isOn: $includeImages)
                    .disabled(selectedFormat == .csv || selectedFormat == .json)
                
                Toggle("Include Inactive Items", isOn: $includeInactiveItems)
            }
            
            Section("Preview") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Export Summary")
                        .font(.headline)
                    
                    Label("Type: \(selectedExportType.rawValue)", systemImage: "doc.fill")
                    Label("Format: \(selectedFormat.rawValue)", systemImage: "square.and.arrow.up")
                    Label("Items: ~\(estimatedItemCount)", systemImage: "number")
                    
                    if selectedFormat == .pdf {
                        Label("Size: ~\(estimatedFileSize)", systemImage: "archivebox")
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
    
    private var exportProgressView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            VStack(spacing: 20) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Exporting \(selectedExportType.rawValue)")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Preparing your data for export...")
                    .foregroundColor(.secondary)
                
                ProgressView(value: exportProgress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .scaleEffect(1.2)
                
                Text("\(Int(exportProgress * 100))% Complete")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var estimatedItemCount: Int {
        switch selectedExportType {
        case .inventoryList:
            return inventoryItems.count
        case .stockLevels:
            return inventoryItems.reduce(0) { $0 + $1.locations }
        case .warehouseReport:
            return inventoryItems.count // Simplified estimate
        case .vehicleInventory:
            return inventoryItems.count // Simplified estimate
        case .lowStockReport:
            return inventoryItems.filter { $0.status == .lowStock || $0.status == .outOfStock }.count
        case .costAnalysis:
            return inventoryItems.count
        case .usageReport:
            return inventoryItems.count
        }
    }
    
    private var estimatedFileSize: String {
        let baseSize = estimatedItemCount * 50 // 50 bytes per item estimate
        let sizeInKB = baseSize / 1024
        
        if sizeInKB < 1024 {
            return "\(sizeInKB) KB"
        } else {
            return "\(sizeInKB / 1024) MB"
        }
    }
    
    private func startExport() {
        isExporting = true
        exportProgress = 0.0
        
        // Simulate export progress
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            exportProgress += 0.1
            
            if exportProgress >= 1.0 {
                timer.invalidate()
                completeExport()
            }
        }
    }
    
    private func completeExport() {
        // In a real implementation, this would generate the actual file
        isExporting = false
        exportProgress = 0.0
        showingExportComplete = true
        
        // Generate a placeholder file URL
        let fileName = "\(selectedExportType.rawValue.replacingOccurrences(of: " ", with: "_")).\(selectedFormat.fileExtension)"
        exportedFileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
    }
    
    private func shareExportedFile() {
        guard let url = exportedFileURL else { return }
        
        // In a real implementation, this would present a share sheet
        print("Sharing file: \(url.lastPathComponent)")
    }
}

#Preview {
    ExportOptionsView(inventoryItems: [])
} 