import Foundation
import UniformTypeIdentifiers
import UIKit
import SwiftUI
import SwiftData

/// Utility for working with inventory templates and CSV exports
@MainActor
class InventoryTemplateUtility {
    
    enum TemplateError: Error, LocalizedError {
        case templateNotFound
        case failedToAccessTemplate
        case failedToShare
        case failedToExportData
        case failedToParseCSV
        case invalidFormat
        case warehouseNotFound
        
        var errorDescription: String? {
            switch self {
            case .templateNotFound:
                return "The inventory template file was not found in the app bundle."
            case .failedToAccessTemplate:
                return "Failed to access the inventory template file."
            case .failedToShare:
                return "Failed to share the inventory template file."
            case .failedToExportData:
                return "Failed to export inventory data."
            case .failedToParseCSV:
                return "Failed to parse the CSV file. Please check the format."
            case .invalidFormat:
                return "The file format is invalid. Please use the correct template."
            case .warehouseNotFound:
                return "No default warehouse found. Please create a warehouse first."
            }
        }
    }
    
    /// Get the URL for the bundled inventory template
    static func getTemplateURL() throws -> URL {
        guard let fileURL = Bundle.main.url(forResource: "InventoryTemplate", withExtension: "xlsx") else {
            throw TemplateError.templateNotFound
        }
        return fileURL
    }
    
    /// Share the bundled inventory template
    static func shareTemplate(from viewController: UIViewController) async throws {
        let templateURL = try getTemplateURL()
        
        // Create a temporary copy to share
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("InventoryTemplate.xlsx")
        
        // Copy the template to temp directory
        try FileManager.default.copyItem(at: templateURL, to: tempURL)
        
        // Create activity view controller
        let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
        
        await MainActor.run {
            // Present the activity view controller
            viewController.present(activityVC, animated: true)
        }
    }
    
    /// Export inventory items to CSV format
    static func exportInventoryToCSV(items: [AppInventoryItem], modelContext: ModelContext) -> String {
        // CSV Header
        var csvString = "Name,Category,Description,PartNumber,Quantity,MinimumStockLevel,Price,Location,Supplier\n"
        
        // Add each item as a row
        for item in items {
            // Find all StockLocationItems for this inventory item
            let stockLocations = fetchStockLocationsForItem(item, modelContext: modelContext)
            
            // If no stock locations exist, show with zero quantity
            if stockLocations.isEmpty {
                // Properly escape fields with quotes if they contain commas
                let row = [
                    escapeCsvField(item.name),
                    escapeCsvField(item.category),
                    escapeCsvField(item.itemDescription ?? ""),
                    escapeCsvField(item.partNumber),
                    "0", // No quantity
                    "0", // No minimum stock level
                    "\(item.pricePerUnit)",
                    "", // No location
                    escapeCsvField(item.supplier ?? "")
                ].joined(separator: ",")
                
                csvString += row + "\n"
            } else {
                // Show each stock location as a separate row
                for stockLocation in stockLocations {
                    // Use locationName directly as it's a non-optional property
                    let row = [
                        escapeCsvField(item.name),
                        escapeCsvField(item.category),
                        escapeCsvField(item.itemDescription ?? ""),
                        escapeCsvField(item.partNumber),
                        "\(stockLocation.quantity)",
                        "\(stockLocation.minimumStockLevel)",
                        "\(item.pricePerUnit)",
                        escapeCsvField(stockLocation.locationName),
                        escapeCsvField(item.supplier ?? "")
                    ].joined(separator: ",")
                    
                    csvString += row + "\n"
                }
            }
        }
        
        return csvString
    }
    
    /// Fetch stock locations for an inventory item
    private static func fetchStockLocationsForItem(_ item: AppInventoryItem, modelContext: ModelContext) -> [StockLocationItem] {
        // Check if ID exists and is not empty
        if item.id.isEmpty {
            return []
        }
        
        let itemId = item.id
        
        let predicate = #Predicate<StockLocationItem> { stockItem in
            stockItem.inventoryItem?.id == itemId
        }
        
        let descriptor = FetchDescriptor<StockLocationItem>(predicate: predicate)
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("Error fetching stock locations: \(error)")
            return []
        }
    }
    
    /// Share inventory items as CSV
    static func shareInventoryCSV(items: [AppInventoryItem], modelContext: ModelContext, from viewController: UIViewController) async throws {
        let csvString = exportInventoryToCSV(items: items, modelContext: modelContext)
        
        // Convert to data
        guard let csvData = csvString.data(using: .utf8) else {
            throw TemplateError.failedToExportData
        }
        
        // Save to temporary file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Inventory_\(Date().formatted(date: .numeric, time: .omitted)).csv")
        
        try csvData.write(to: tempURL)
        
        // Create activity view controller
        let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
        
        await MainActor.run {
            // Present the activity view controller
            viewController.present(activityVC, animated: true)
        }
    }
    
    /// Helper to escape CSV fields
    private static func escapeCsvField(_ field: String) -> String {
        // If the field contains commas, quotes, or newlines, wrap it in quotes
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            // Double any quotes within the field
            let escapedField = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escapedField)\""
        }
        return field
    }
    
    /// Import inventory items from CSV data
    static func importInventoryFromCSV(data: Data, modelContext: ModelContext) throws -> [AppInventoryItem] {
        // Convert data to string
        guard let csvString = String(data: data, encoding: .utf8) else {
            throw TemplateError.failedToParseCSV
        }
        
        // Split into lines
        var lines = csvString.components(separatedBy: .newlines).filter { !$0.isEmpty }
        
        // Need at least header + one data row
        guard lines.count >= 2 else {
            throw TemplateError.invalidFormat
        }
        
        // Parse header
        let header = lines.removeFirst().components(separatedBy: ",")
        
        // Validate header format
        let requiredColumns = ["Name", "Category", "PartNumber"]
        for column in requiredColumns {
            if !header.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == column.lowercased() }) {
                throw TemplateError.invalidFormat
            }
        }
        
        // Get default warehouse for new items
        let defaultWarehouse = try getDefaultWarehouse(modelContext: modelContext)
        
        // Process data rows
        var importedItems: [AppInventoryItem] = []
        
        for line in lines {
            // Parse CSV line, handling quoted fields that might contain commas
            let fields = parseCSVLine(line)
            
            // Skip if we don't have enough fields
            if fields.count < requiredColumns.count {
                continue
            }
            
            // Create inventory item and stock location
            let (item, _) = try createItemAndStockFromFields(fields, header: header, warehouse: defaultWarehouse, modelContext: modelContext)
            
            importedItems.append(item)
        }
        
        // Save changes
        try modelContext.save()
        
        return importedItems
    }
    
    /// Get or create default warehouse for inventory imports
    private static func getDefaultWarehouse(modelContext: ModelContext) throws -> AppWarehouse {
        // Try to find an existing warehouse
        let descriptor = FetchDescriptor<AppWarehouse>()
        let warehouses = try modelContext.fetch(descriptor)
        
        if let warehouse = warehouses.first {
            return warehouse
        }
        
        // If no warehouse exists, create a default one
        let defaultWarehouse = AppWarehouse(name: "Main Warehouse", location: "Default Location")
        modelContext.insert(defaultWarehouse)
        
        return defaultWarehouse
    }
    
    /// Parse a CSV line respecting quoted fields
    private static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var inQuotes = false
        let lineChars = Array(line)
        var index = 0
        
        while index < lineChars.count {
            let char = lineChars[index]
            if char == "\"" {
                // Handle double quotes inside quoted fields
                if inQuotes && index < lineChars.count - 1 && lineChars[index + 1] == "\"" {
                    // This is an escaped quote inside a quoted field
                    currentField.append(char)
                    // Skip the next quote character
                    index += 2
                    continue
                } else {
                    // Toggle quote state
                    inQuotes = !inQuotes
                }
            } else if char == "," && !inQuotes {
                // End of field
                fields.append(currentField)
                currentField = ""
            } else {
                // Add character to current field
                currentField.append(char)
            }
            index += 1
        }
        
        // Add the last field
        fields.append(currentField)
        
        return fields
    }
    
    /// Create an inventory item and stock location from parsed CSV fields
    private static func createItemAndStockFromFields(_ fields: [String], header: [String], warehouse: AppWarehouse, modelContext: ModelContext) throws -> (AppInventoryItem, StockLocationItem) {
        let item = AppInventoryItem()
        
        // Initialize default values for stock location
        var quantity = 0
        var minimumStockLevel = 0
        
        // Map fields to object properties
        for (index, columnName) in header.enumerated() {
            if index < fields.count {
                let value = fields[index].trimmingCharacters(in: .whitespacesAndNewlines)
                switch columnName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                case "name": 
                    item.name = value
                case "category": 
                    item.category = value
                case "description": 
                    item.itemDescription = value
                case "partnumber", "part number", "sku": 
                    item.partNumber = value
                case "cost", "price", "priceperunit": 
                    item.pricePerUnit = Double(value) ?? 0.0
                case "quantity", "qty", "stock":
                    quantity = Int(value) ?? 0
                case "reorderpoint", "min quantity", "reorder point", "minimumstocklevel", "target stock", "max quantity", "targetstock":
                    minimumStockLevel = Int(value) ?? 0
                case "location":
                    // Just ignore the location for now as we're using the default warehouse
                    // We could add custom logic here in the future to find or create warehouses by name
                    break
                case "supplier":
                    item.supplier = value
                default:
                    break
                }
            }
        }
        
        // Add item to context
        modelContext.insert(item)
        
        // Create stock location for this item
        let stockLocation = StockLocationItem(
            inventoryItem: item,
            quantity: quantity,
            minimumStockLevel: minimumStockLevel,
            warehouse: warehouse
        )
        
        // Add stock location to context
        modelContext.insert(stockLocation)
        
        return (item, stockLocation)
    }
}

// Helper SwiftUI View for sharing the template
struct InventoryTemplateShare: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        
        // Share the template when the view appears
        Task {
            do {
                try await InventoryTemplateUtility.shareTemplate(from: controller)
            } catch {
                print("Failed to share template: \(error.localizedDescription)")
            }
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

// Helper SwiftUI View for sharing CSV export
struct InventoryCSVExport: UIViewControllerRepresentable {
    let items: [AppInventoryItem]
    @Environment(\.modelContext) private var modelContext
    
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        
        // Share the CSV when the view appears
        Task {
            do {
                try await InventoryTemplateUtility.shareInventoryCSV(items: items, modelContext: modelContext, from: controller)
            } catch {
                print("Failed to export CSV: \(error.localizedDescription)")
            }
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

// Document picker for importing CSV files
struct CSVDocumentPicker: UIViewControllerRepresentable {
    var onDocumentPicked: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.commaSeparatedText])
        documentPicker.delegate = context.coordinator
        documentPicker.allowsMultipleSelection = false
        return documentPicker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: CSVDocumentPicker
        
        init(_ parent: CSVDocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.onDocumentPicked(url)
        }
    }
} 