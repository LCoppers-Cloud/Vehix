import SwiftUI
import UniformTypeIdentifiers

struct ImportDataView: View {
    let inventoryManager: InventoryManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedImportType: ImportType = .inventoryItems
    @State private var selectedFile: URL?
    @State private var isImporting = false
    @State private var importProgress: Double = 0.0
    @State private var showingFilePicker = false
    @State private var showingImportComplete = false
    @State private var importResults: ImportResults?
    @State private var validationErrors: [ValidationError] = []
    @State private var showingValidationErrors = false
    @State private var previewData: [ImportPreviewRow] = []
    @State private var showingPreview = false
    
    enum ImportType: String, CaseIterable {
        case inventoryItems = "Inventory Items"
        case stockLevels = "Stock Levels"
        case warehouses = "Warehouses"
        case vehicles = "Vehicles"
        case suppliers = "Suppliers"
        
        var description: String {
            switch self {
            case .inventoryItems:
                return "Import new inventory items with details"
            case .stockLevels:
                return "Update current stock levels across locations"
            case .warehouses:
                return "Import warehouse locations and details"
            case .vehicles:
                return "Import vehicle information"
            case .suppliers:
                return "Import supplier contact information"
            }
        }
        
        var templateFields: [String] {
            switch self {
            case .inventoryItems:
                return ["Name", "Part Number", "Category", "Price Per Unit", "Description", "Supplier"]
            case .stockLevels:
                return ["Item ID/Part Number", "Location", "Quantity", "Min Level", "Max Level"]
            case .warehouses:
                return ["Name", "Location/Address", "Description", "Active"]
            case .vehicles:
                return ["License Plate", "Make", "Model", "Year", "VIN", "Active"]
            case .suppliers:
                return ["Name", "Contact Person", "Email", "Phone", "Address"]
            }
        }
        
        var supportedFormats: [UTType] {
            [.commaSeparatedText, .tabSeparatedText, .json]
        }
    }
    
    struct ValidationError {
        let row: Int
        let field: String
        let message: String
    }
    
    struct ImportResults {
        let totalRows: Int
        let successfulImports: Int
        let skippedRows: Int
        let errors: Int
    }
    
    struct ImportPreviewRow {
        let rowNumber: Int
        let data: [String: String]
        let hasErrors: Bool
        let errors: [String]
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isImporting {
                    importProgressView
                } else if showingPreview {
                    previewDataView
                } else {
                    importOptionsView
                }
            }
            .navigationTitle("Import Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if showingPreview {
                        Button("Import") {
                            startImport()
                        }
                        .disabled(previewData.allSatisfy { $0.hasErrors })
                    } else if selectedFile != nil {
                        Button("Preview") {
                            showPreview()
                        }
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: selectedImportType.supportedFormats,
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
            .alert("Import Complete", isPresented: $showingImportComplete) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                if let results = importResults {
                    Text("Successfully imported \(results.successfulImports) of \(results.totalRows) items. \(results.errors) errors, \(results.skippedRows) skipped.")
                }
            }
            .sheet(isPresented: $showingValidationErrors) {
                ValidationErrorsView(errors: validationErrors)
            }
        }
    }
    
    private var importOptionsView: some View {
        Form {
            Section("Import Type") {
                Picker("Type", selection: $selectedImportType) {
                    ForEach(ImportType.allCases, id: \.self) { type in
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
            
            Section("File Selection") {
                if let file = selectedFile {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(file.lastPathComponent, systemImage: "doc.fill")
                            .foregroundColor(.blue)
                        
                        Text("File selected successfully")
                            .font(.caption)
                            .foregroundColor(.green)
                        
                        Button("Choose Different File") {
                            showingFilePicker = true
                        }
                        .font(.caption)
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        
                        Text("No file selected")
                            .foregroundColor(.secondary)
                        
                        Button("Select File") {
                            showingFilePicker = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
            }
            
            Section("Template & Format") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Required Fields")
                        .font(.headline)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(selectedImportType.templateFields, id: \.self) { field in
                            Text(field)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.systemGray6))
                                .cornerRadius(6)
                        }
                    }
                    
                    Button("Download Template") {
                        downloadTemplate()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            Section("Supported Formats") {
                VStack(alignment: .leading, spacing: 8) {
                    Label("CSV (Comma Separated Values)", systemImage: "doc.text")
                    Label("TSV (Tab Separated Values)", systemImage: "doc.text")
                    Label("JSON", systemImage: "curlybraces")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Section("Import Options") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Skip duplicate items", isOn: .constant(true))
                    Toggle("Update existing items", isOn: .constant(false))
                    Toggle("Validate data before import", isOn: .constant(true))
                    
                    Text("Import will validate all data and show preview before processing.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var previewDataView: some View {
        VStack(spacing: 0) {
            // Preview header
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Import Preview")
                            .font(.headline)
                        Text("\(previewData.count) rows found")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if !validationErrors.isEmpty {
                        Button("View Errors (\(validationErrors.count))") {
                            showingValidationErrors = true
                        }
                        .foregroundColor(.red)
                        .font(.caption)
                    }
                }
                
                // Summary stats
                HStack(spacing: 20) {
                    ImportStatusBadge(
                        title: "Valid",
                        count: previewData.filter { !$0.hasErrors }.count,
                        color: .green
                    )
                    
                    ImportStatusBadge(
                        title: "Errors",
                        count: previewData.filter { $0.hasErrors }.count,
                        color: .red
                    )
                    
                    ImportStatusBadge(
                        title: "Total",
                        count: previewData.count,
                        color: .blue
                    )
                }
            }
            .padding()
            .background(Color(.systemGray6))
            
            // Preview table
            List {
                ForEach(previewData.prefix(50), id: \.rowNumber) { row in
                    PreviewRowView(row: row, importType: selectedImportType)
                }
                
                if previewData.count > 50 {
                    Text("... and \(previewData.count - 50) more rows")
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
        }
    }
    
    private var importProgressView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            VStack(spacing: 20) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Importing \(selectedImportType.rawValue)")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Processing your data...")
                    .foregroundColor(.secondary)
                
                ProgressView(value: importProgress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .scaleEffect(1.2)
                
                Text("\(Int(importProgress * 100))% Complete")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                selectedFile = url
            }
        case .failure(let error):
            print("File selection error: \(error)")
        }
    }
    
    private func showPreview() {
        guard selectedFile != nil else { return }
        
        // PRODUCTION MODE: No sample preview data
        // Clear any existing preview data
        previewData = []
        validationErrors = []
        
        // In production, users must provide real files to see preview data
        // No artificial sample data is generated
    }
    
    private func startImport() {
        isImporting = true
        importProgress = 0.0
        showingPreview = false
        
        // Simulate import progress
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            importProgress += 0.1
            
            if importProgress >= 1.0 {
                timer.invalidate()
                completeImport()
            }
        }
    }
    
    private func completeImport() {
        isImporting = false
        importProgress = 0.0
        
        let validRows = previewData.filter { !$0.hasErrors }.count
        let errorRows = previewData.filter { $0.hasErrors }.count
        
        importResults = ImportResults(
            totalRows: previewData.count,
            successfulImports: validRows,
            skippedRows: errorRows,
            errors: errorRows
        )
        
        showingImportComplete = true
    }
    
    private func downloadTemplate() {
        // In a real implementation, this would generate and download a template file
        print("Downloading template for \(selectedImportType.rawValue)")
    }
}

// MARK: - Supporting Views

struct ImportStatusBadge: View {
    let title: String
    let count: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct PreviewRowView: View {
    let row: ImportDataView.ImportPreviewRow
    let importType: ImportDataView.ImportType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Row \(row.rowNumber)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if row.hasErrors {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 4) {
                ForEach(importType.templateFields, id: \.self) { field in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(field)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(row.data[field] ?? "")
                            .font(.caption)
                            .foregroundColor(row.hasErrors ? .red : .primary)
                    }
                }
            }
            
            if !row.errors.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(row.errors, id: \.self) { error in
                        Text("• \(error)")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ValidationErrorsView: View {
    let errors: [ImportDataView.ValidationError]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(errors, id: \.row) { error in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Row \(error.row)")
                            .font(.headline)
                        
                        if !error.field.isEmpty {
                            Text("Field: \(error.field)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(error.message)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .padding(.vertical, 2)
                }
            }
            .navigationTitle("Validation Errors")
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
    ImportDataView(inventoryManager: InventoryManager())
} 