import SwiftUI
import SwiftData

struct WarehousesView: View {
    @EnvironmentObject var inventoryManager: InventoryManager
    
    var body: some View {
        VStack {
            if inventoryManager.warehouses.isEmpty {
                emptyStateView
            } else {
                warehouseListView
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "building.2")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Warehouses Found")
                .font(.headline)
            
            Text("Add warehouses to organize your inventory")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var warehouseListView: some View {
        List {
            ForEach(inventoryManager.warehouses) { warehouse in
                Button(action: {
                    inventoryManager.selectedWarehouse = warehouse
                }) {
                    HStack {
                        Image(systemName: "building.2.fill")
                            .foregroundColor(.blue)
                        
                        Text(warehouse.name)
                            .font(.headline)
                        
                        Spacer()
                        
                        if warehouse.id == inventoryManager.selectedWarehouse?.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .padding(.vertical, 4)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
} 