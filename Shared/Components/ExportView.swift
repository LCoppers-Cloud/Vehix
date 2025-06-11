import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ExportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authService: AppAuthService
    
    @StateObject private var exportManager = ExportManager()
    
    @State private var selectedDataType: ExportDataType = .financialSummary
    @State private var selectedFormat: ExportFormat = .excel
    @State private var selectedDateRange: DateRangeOption = .lastMonth
    @State private var customStartDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var customEndDate = Date()
    @State private var includeCharts = true
    @State private var includeDetails = true
    
    @State private var showingExportSheet = false
    @State private var exportedFileURL: URL?
    @State private var showingShareSheet = false
    @State private var showingErrorAlert = false
    
    enum DateRangeOption: String, CaseIterable {
        case lastWeek = "Last Week"
        case lastMonth = "Last Month"
        case lastQuarter = "Last Quarter"
        case lastYear = "Last Year"
        case custom = "Custom Range"
        
        func toDateRange(customStart: Date, customEnd: Date) -> DateRange {
            let calendar = Calendar.current
            let now = Date()
            
            switch self {
            case .lastWeek:
                let start = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
                return DateRange(start: start, end: now)
            case .lastMonth:
                return DateRange.lastMonth
            case .lastQuarter:
                return DateRange.lastQuarter
            case .lastYear:
                return DateRange.lastYear
            case .custom:
                return DateRange(start: customStart, end: customEnd)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Data Type Selection
                    dataTypeSection
                    
                    // Format Selection
                    formatSection
                    
                    // Date Range Selection
                    dateRangeSection
                    
                    // Export Options
                    exportOptionsSection
                    
                    // Export Button
                    exportButtonSection
                }
                .padding()
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                exportManager.setModelContext(modelContext)
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportedFileURL {
                    ShareSheet(items: [url])
                }
            }
            .alert("Export Error", isPresented: $showingErrorAlert) {
                Button("OK") { }
            } message: {
                Text(exportManager.errorMessage ?? "An error occurred during export")
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.and.arrow.up.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text("Export Business Data")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Generate professional reports in multiple formats for accounting, analysis, and compliance.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Data Type Section
    
    private var dataTypeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select Data Type")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(ExportDataType.allCases, id: \.self) { dataType in
                    DataTypeCard(
                        dataType: dataType,
                        isSelected: selectedDataType == dataType
                    ) {
                        selectedDataType = dataType
                        // Auto-select appropriate format for data type
                        updateRecommendedFormat(for: dataType)
                    }
                }
            }
        }
    }
    
    // MARK: - Format Section
    
    private var formatSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Export Format")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(ExportFormat.allCases, id: \.self) { format in
                    FormatCard(
                        format: format,
                        isSelected: selectedFormat == format,
                        isRecommended: isRecommendedFormat(format, for: selectedDataType)
                    ) {
                        selectedFormat = format
                    }
                }
            }
        }
    }
    
    // MARK: - Date Range Section
    
    private var dateRangeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Date Range")
                .font(.headline)
            
            Picker("Date Range", selection: $selectedDateRange) {
                ForEach(DateRangeOption.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            
            if selectedDateRange == .custom {
                VStack(spacing: 12) {
                    HStack {
                        Text("From:")
                            .font(.subheadline)
                            .frame(width: 60, alignment: .leading)
                        
                        DatePicker("", selection: $customStartDate, displayedComponents: .date)
                            .labelsHidden()
                    }
                    
                    HStack {
                        Text("To:")
                            .font(.subheadline)
                            .frame(width: 60, alignment: .leading)
                        
                        DatePicker("", selection: $customEndDate, displayedComponents: .date)
                            .labelsHidden()
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Export Options Section
    
    private var exportOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Export Options")
                .font(.headline)
            
            VStack(spacing: 12) {
                Toggle("Include Charts & Graphs", isOn: $includeCharts)
                    .disabled(!supportsCharts(selectedFormat))
                
                Toggle("Include Detailed Data", isOn: $includeDetails)
                
                if selectedFormat == .budgetTemplate {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Budget Template Features:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("• Pre-formatted budget categories\n• Variance analysis formulas\n• Monthly/quarterly breakdowns\n• Professional formatting")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                
                if selectedFormat == .quickbooks {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("QuickBooks Integration:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("• IIF format for direct import\n• Chart of accounts mapping\n• Transaction categorization\n• Tax-ready formatting")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    // MARK: - Export Button Section
    
    private var exportButtonSection: some View {
        VStack(spacing: 16) {
            if exportManager.isExporting {
                VStack(spacing: 12) {
                    ProgressView(value: exportManager.exportProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                    
                    Text(exportManager.exportStatus)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
                Button(action: performExport) {
                    HStack {
                        Image(systemName: selectedFormat.icon)
                        Text("Export \(selectedDataType.rawValue)")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                
                Text("File will be saved to your device and can be shared with accounting software, business partners, or stored for records.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func updateRecommendedFormat(for dataType: ExportDataType) {
        switch dataType {
        case .budgetAnalysis:
            selectedFormat = .budgetTemplate
        case .taxReport, .auditTrail:
            selectedFormat = .quickbooks
        case .financialSummary, .profitLoss:
            selectedFormat = .excel
        case .vehicleInventory, .inventoryValuation:
            selectedFormat = .csv
        default:
            selectedFormat = .excel
        }
    }
    
    private func isRecommendedFormat(_ format: ExportFormat, for dataType: ExportDataType) -> Bool {
        switch dataType {
        case .budgetAnalysis:
            return format == .budgetTemplate || format == .excel
        case .taxReport, .auditTrail:
            return format == .quickbooks || format == .csv
        case .financialSummary, .profitLoss, .cashFlow:
            return format == .excel || format == .pdf
        case .vehicleInventory, .inventoryValuation:
            return format == .csv || format == .excel
        default:
            return format == .excel
        }
    }
    
    private func supportsCharts(_ format: ExportFormat) -> Bool {
        switch format {
        case .pdf, .excel:
            return true
        default:
            return false
        }
    }
    
    private func performExport() {
        let dateRange = selectedDateRange.toDateRange(
            customStart: customStartDate,
            customEnd: customEndDate
        )
        
        Task {
            let url = await exportManager.exportData(
                type: selectedDataType,
                format: selectedFormat,
                dateRange: dateRange,
                includeCharts: includeCharts,
                includeDetails: includeDetails
            )
            
            await MainActor.run {
                if let url = url {
                    exportedFileURL = url
                    showingShareSheet = true
                } else {
                    showingErrorAlert = true
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct DataTypeCard: View {
    let dataType: ExportDataType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: dataType.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .blue)
                
                Text(dataType.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(dataType.description)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 100)
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct FormatCard: View {
    let format: ExportFormat
    let isSelected: Bool
    let isRecommended: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Image(systemName: format.icon)
                        .font(.title2)
                        .foregroundColor(isSelected ? .white : .blue)
                    
                    if isRecommended && !isSelected {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                            Spacer()
                        }
                    }
                }
                
                Text(format.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .foregroundColor(isSelected ? .white : .primary)
                
                if isRecommended {
                    Text("Recommended")
                        .font(.caption2)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .orange)
                        .fontWeight(.medium)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 80)
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color.blue : 
                        isRecommended ? Color.orange.opacity(0.5) : Color.clear,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ExportView()
        .environmentObject(AppAuthService())
        .modelContainer(for: [AppInventoryItem.self, StockLocationItem.self, AppVehicle.self], inMemory: true)
} 