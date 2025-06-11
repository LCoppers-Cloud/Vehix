import SwiftUI
import UniformTypeIdentifiers

struct ReportExportView: View {
    let reportType: AdvancedReportsView.ReportType
    let period: AdvancedReportsView.ReportPeriod
    let startDate: Date
    let endDate: Date
    let inventoryItems: [InventoryItemStatus]
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFormat: ExportFormat = .pdf
    @State private var includeCharts = true
    @State private var includeRawData = false
    @State private var includeCompanyLogo = true
    @State private var customTitle = ""
    @State private var recipientEmail = ""
    @State private var includeNotes = ""
    @State private var isExporting = false
    @State private var exportProgress: Double = 0.0
    @State private var showingExportComplete = false
    @State private var exportedFileURL: URL?
    
    enum ExportFormat: String, CaseIterable {
        case pdf = "PDF Report"
        case excel = "Excel Spreadsheet"
        case powerpoint = "PowerPoint Presentation"
        case csv = "CSV Data"
        case json = "JSON Data"
        
        var icon: String {
            switch self {
            case .pdf: return "doc.richtext"
            case .excel: return "tablecells"
            case .powerpoint: return "presentation"
            case .csv: return "doc.text"
            case .json: return "curlybraces"
            }
        }
        
        var description: String {
            switch self {
            case .pdf: return "Professional report with charts and analysis"
            case .excel: return "Spreadsheet with data tables and formulas"
            case .powerpoint: return "Presentation slides for meetings"
            case .csv: return "Raw data in comma-separated format"
            case .json: return "Structured data in JSON format"
            }
        }
        
        var fileExtension: String {
            switch self {
            case .pdf: return "pdf"
            case .excel: return "xlsx"
            case .powerpoint: return "pptx"
            case .csv: return "csv"
            case .json: return "json"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isExporting {
                    exportProgressView
                } else {
                    exportConfigurationView
                }
            }
            .navigationTitle("Export Report")
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
                    shareExportedReport()
                }
                Button("Email") {
                    emailExportedReport()
                }
                Button("Save") {
                    saveExportedReport()
                }
                Button("OK") { }
            } message: {
                Text("Your \(reportType.rawValue) report has been exported successfully.")
            }
        }
    }
    
    private var exportConfigurationView: some View {
        Form {
            Section("Report Details") {
                VStack(alignment: .leading, spacing: 8) {
                    Label(reportType.rawValue, systemImage: reportType.icon)
                        .font(.headline)
                    
                    Text("Period: \(period.rawValue)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if period == .custom {
                        Text("From \(startDate.formatted(date: .abbreviated, time: .omitted)) to \(endDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            
            Section("Export Format") {
                ForEach(ExportFormat.allCases, id: \.self) { format in
                    HStack {
                        Image(systemName: format.icon)
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(format.rawValue)
                                .font(.headline)
                            Text(format.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if selectedFormat == format {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedFormat = format
                    }
                }
            }
            
            Section("Content Options") {
                if selectedFormat == .pdf || selectedFormat == .powerpoint {
                    Toggle("Include Charts & Graphs", isOn: $includeCharts)
                    Toggle("Include Company Logo", isOn: $includeCompanyLogo)
                }
                
                if selectedFormat == .excel || selectedFormat == .csv {
                    Toggle("Include Raw Data Tables", isOn: $includeRawData)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Custom Title (Optional)")
                        .font(.headline)
                    
                    TextField("Enter custom report title", text: $customTitle)
                        .textFieldStyle(.roundedBorder)
                    
                    Text("Leave blank to use default title")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Distribution") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email Recipient (Optional)")
                        .font(.headline)
                    
                    TextField("Enter email address", text: $recipientEmail)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    Text("Report will be automatically emailed after export")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Additional Notes (Optional)")
                        .font(.headline)
                    
                    TextField("Add notes or comments for this report", text: $includeNotes, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }
            }
            
            Section("Report Preview") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Export Summary")
                        .font(.headline)
                    
                    VStack(spacing: 8) {
                        ReportPreviewRow(
                            label: "Report Type",
                            value: reportType.rawValue
                        )
                        
                        ReportPreviewRow(
                            label: "Format",
                            value: selectedFormat.rawValue
                        )
                        
                        ReportPreviewRow(
                            label: "Period",
                            value: formatPeriodString()
                        )
                        
                        ReportPreviewRow(
                            label: "Data Points",
                            value: "\(estimatedDataPoints())"
                        )
                        
                        ReportPreviewRow(
                            label: "Estimated Size",
                            value: estimatedFileSize()
                        )
                        
                        if !recipientEmail.isEmpty {
                            ReportPreviewRow(
                                label: "Email To",
                                value: recipientEmail
                            )
                        }
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
                Image(systemName: selectedFormat.icon)
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Generating \(reportType.rawValue)")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Creating your \(selectedFormat.rawValue.lowercased())...")
                    .foregroundColor(.secondary)
                
                ProgressView(value: exportProgress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .scaleEffect(1.2)
                
                Text(progressStatusText())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func formatPeriodString() -> String {
        switch period {
        case .monthly:
            return "Monthly"
        case .quarterly:
            return "Quarterly"
        case .yearly:
            return "Yearly"
        case .custom:
            return "\(startDate.formatted(date: .abbreviated, time: .omitted)) - \(endDate.formatted(date: .abbreviated, time: .omitted))"
        }
    }
    
    private func estimatedDataPoints() -> Int {
        switch reportType {
        case .monthlyUsage:
            return 12 * inventoryItems.count
        case .vehicleInventory:
            return inventoryItems.count * 10 // Simplified estimate
        case .warehouseCosts:
            return inventoryItems.count * 20 // Simplified estimate
        case .costAnalysis:
            return inventoryItems.count * 5
        case .lowStockAnalysis:
            return inventoryItems.filter { $0.status == .lowStock || $0.status == .outOfStock }.count
        case .utilizationRates:
            return inventoryItems.reduce(0) { $0 + $1.locations }
        case .expenseReports:
            return 100 // Various financial metrics
        }
    }
    
    private func estimatedFileSize() -> String {
        let baseSize: Int
        
        switch selectedFormat {
        case .pdf:
            baseSize = includeCharts ? 2048 : 512 // KB
        case .excel:
            baseSize = 1024
        case .powerpoint:
            baseSize = includeCharts ? 4096 : 1024
        case .csv:
            baseSize = 256
        case .json:
            baseSize = 512
        }
        
        let dataMultiplier = max(1, estimatedDataPoints() / 100)
        let finalSize = baseSize * dataMultiplier
        
        if finalSize < 1024 {
            return "\(finalSize) KB"
        } else {
            return "\(finalSize / 1024) MB"
        }
    }
    
    private func progressStatusText() -> String {
        let progress = Int(exportProgress * 100)
        
        switch progress {
        case 0..<20:
            return "Collecting data..."
        case 20..<40:
            return "Processing analytics..."
        case 40..<60:
            return "Generating charts..."
        case 60..<80:
            return "Formatting report..."
        case 80..<100:
            return "Finalizing export..."
        default:
            return "Complete!"
        }
    }
    
    private func startExport() {
        isExporting = true
        exportProgress = 0.0
        
        // Simulate export progress with different stages
        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { timer in
            exportProgress += 0.1
            
            if exportProgress >= 1.0 {
                timer.invalidate()
                completeExport()
            }
        }
    }
    
    private func completeExport() {
        isExporting = false
        exportProgress = 0.0
        showingExportComplete = true
        
        // Generate a realistic filename
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        
        let filename = "\(reportType.rawValue.replacingOccurrences(of: " ", with: "_"))_\(dateString).\(selectedFormat.fileExtension)"
        exportedFileURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        
        // Auto-email if recipient provided
        if !recipientEmail.isEmpty {
            emailExportedReport()
        }
    }
    
    private func shareExportedReport() {
        guard let url = exportedFileURL else { return }
        
        // In a real implementation, this would present a share sheet
        print("Sharing report: \(url.lastPathComponent)")
    }
    
    private func emailExportedReport() {
        guard let url = exportedFileURL else { return }
        
        // In a real implementation, this would compose and send an email
        print("Emailing report \(url.lastPathComponent) to \(recipientEmail)")
    }
    
    private func saveExportedReport() {
        guard let url = exportedFileURL else { return }
        
        // In a real implementation, this would save to documents or present document picker
        print("Saving report: \(url.lastPathComponent)")
    }
}

// MARK: - Supporting Views

struct ReportPreviewRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(value)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.subheadline)
    }
}

#Preview {
    ReportExportView(
        reportType: .monthlyUsage,
        period: .monthly,
        startDate: Date(),
        endDate: Date(),
        inventoryItems: []
    )
} 