import SwiftUI
import SwiftData

/// A reusable row component for selecting inventory items with quantity controls
public struct ItemSelectionRow: View {
    var item: AppInventoryItem
    var stockLocation: StockLocationItem?
    var isSelected: Bool
    var quantity: Binding<Int>? = nil
    var minimumLevel: Binding<Int>? = nil
    var toggleAction: () -> Void
    
    init(
        item: AppInventoryItem, 
        stockLocation: StockLocationItem? = nil,
        isSelected: Bool,
        quantity: Binding<Int>? = nil,
        minimumLevel: Binding<Int>? = nil,
        toggleAction: @escaping () -> Void
    ) {
        self.item = item
        self.stockLocation = stockLocation
        self.isSelected = isSelected
        self.quantity = quantity
        self.minimumLevel = minimumLevel
        self.toggleAction = toggleAction
    }
    
    // For simpler usage in InventoryUsageView
    init(
        item: AppInventoryItem, 
        stockLocation: StockLocationItem? = nil,
        isSelected: Bool,
        toggleAction: @escaping () -> Void
    ) {
        self.item = item
        self.stockLocation = stockLocation
        self.isSelected = isSelected
        self.toggleAction = toggleAction
    }
    
    // For simpler usage in AddInventoryToVehicleView
    init(
        item: AppInventoryItem,
        isSelected: Bool,
        quantity: Binding<Int>,
        minimumLevel: Binding<Int>,
        onToggle: @escaping (Bool) -> Void
    ) {
        self.item = item
        self.isSelected = isSelected
        self.quantity = quantity
        self.minimumLevel = minimumLevel
        self.toggleAction = { onToggle(!isSelected) }
    }
    
    public var body: some View {
        HStack {
            Button(action: toggleAction) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.title2)
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.headline)
                
                HStack {
                    Text(item.partNumber)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !item.category.isEmpty {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(item.category)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let stockLocation = stockLocation {
                    Text("In stock: \(stockLocation.quantity)")
                        .font(.caption)
                        .foregroundColor(stockLocation.isBelowMinimumStock ? .orange : .green)
                }
            }
            
            Spacer()
            
            if isSelected, let quantity = quantity, let minimumLevel = minimumLevel {
                VStack {
                    Stepper("Qty: \(quantity.wrappedValue)", value: quantity, in: 1...99)
                        .labelsHidden()
                    
                    Stepper("Min: \(minimumLevel.wrappedValue)", value: minimumLevel, in: 1...99)
                        .labelsHidden()
                }
                .frame(width: 100)
            }
        }
        .padding(.vertical, 6)
    }
} 