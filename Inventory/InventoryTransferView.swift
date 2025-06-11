import SwiftUI
import SwiftData
import PhotosUI

struct InventoryTransferView: View {
    @EnvironmentObject var inventoryManager: InventoryManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let sourceWarehouse: AppWarehouse
    let stockItem: StockLocationItem
    
    @State private var selectedVehicle: AppVehicle?
    @State private var transferQuantity = 1
    @State private var notes = ""
    @State private var showingPhotoCapture = false
    @State private var transferPhoto: UIImage?
    @State private var showingScanner = false
    @State private var scannedBarcode: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Item Details")) {
                    if let item = stockItem.inventoryItem {
                        DetailRow(label: "Item", value: item.name)
                        DetailRow(label: "Available Quantity", value: "\(stockItem.quantity)")
                    }
                }
                
                Section(header: Text("Transfer Details")) {
                    Picker("Select Vehicle", selection: $selectedVehicle) {
                        Text("Select a Vehicle").tag(nil as AppVehicle?)
                        ForEach(inventoryManager.vehicles, id: \.id) { vehicle in
                            Text(vehicle.displayName).tag(Optional(vehicle))
                        }
                    }
                    
                    Stepper("Quantity: \(transferQuantity)", value: $transferQuantity, in: 1...stockItem.quantity)
                    
                    TextField("Notes", text: $notes)
                }
                
                Section(header: Text("Verification")) {
                    Button(action: { showingPhotoCapture = true }) {
                        Label("Take Photo", systemImage: "camera")
                    }
                    
                    if let photo = transferPhoto {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                    }
                    
                    Button(action: { showingScanner = true }) {
                        Label("Scan Barcode", systemImage: "barcode.viewfinder")
                    }
                    
                    if let barcode = scannedBarcode {
                        DetailRow(label: "Scanned Barcode", value: barcode)
                    }
                }
            }
            .navigationTitle("Transfer Inventory")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Transfer") { performTransfer() }
                    .disabled(!canTransfer)
            )
            .sheet(isPresented: $showingPhotoCapture) {
                ImagePicker(image: $transferPhoto)
            }
            .sheet(isPresented: $showingScanner) {
                BarcodeScannerView { code in
                    scannedBarcode = code
                    showingScanner = false
                }
            }
        }
    }
    
    private var canTransfer: Bool {
        selectedVehicle != nil && transferQuantity > 0 && transferQuantity <= stockItem.quantity
    }
    
    private func performTransfer() {
        guard let vehicle = selectedVehicle,
              let item = stockItem.inventoryItem else { return }
        
        // Create a pending transfer
        let transfer = PendingTransfer(
            quantity: transferQuantity,
            notes: notes,
            inventoryItem: item,
            fromWarehouse: sourceWarehouse,
            toVehicle: vehicle
        )
        
        // Create usage record for tracking
        let usageRecord = AppInventoryUsageRecord(
            id: UUID().uuidString,
            inventoryItemId: item.id,
            quantity: transferQuantity,
            timestamp: Date(),
            vehicleId: vehicle.id,
            notes: "Transfer from \(sourceWarehouse.name) to \(vehicle.displayName)"
        )
        
        // Update stock quantities
        stockItem.quantity -= transferQuantity
        
        // Find or create vehicle stock location
        if let vehicleStock = item.stockLocationItems?.first(where: { $0.vehicle?.id == vehicle.id }) {
            vehicleStock.quantity += transferQuantity
        } else {
            let newVehicleStock = StockLocationItem(
                inventoryItem: item,
                quantity: transferQuantity,
                vehicle: vehicle
            )
            if item.stockLocationItems == nil {
                item.stockLocationItems = []
            }
            item.stockLocationItems?.append(newVehicleStock)
        }
        
        // Save to model context
        modelContext.insert(transfer)
        modelContext.insert(usageRecord)
        
        dismiss()
    }
}

