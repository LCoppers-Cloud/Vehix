import SwiftUI

// MARK: - Shared Inventory Types

struct InventoryItemStatus {
    let item: AppInventoryItem
    let totalQuantity: Int
    let totalValue: Double
    let status: StockStatus
    let locations: Int
}

enum StockStatus {
    case inStock
    case lowStock
    case outOfStock
    case overStock
    
    var color: Color {
        switch self {
        case .inStock: return .green
        case .lowStock: return .orange
        case .outOfStock: return .red
        case .overStock: return .yellow
        }
    }
    
    var icon: String {
        switch self {
        case .inStock: return "checkmark.circle.fill"
        case .lowStock: return "exclamationmark.triangle.fill"
        case .outOfStock: return "xmark.circle.fill"
        case .overStock: return "arrow.up.circle.fill"
        }
    }
    
    var text: String {
        switch self {
        case .inStock: return "In Stock"
        case .lowStock: return "Low Stock"
        case .outOfStock: return "Out of Stock"
        case .overStock: return "Overstocked"
        }
    }
}

// MARK: - Shared Inventory Helpers

extension Collection where Element == AppInventoryItem {
    func toInventoryStatuses(with stockLocations: [StockLocationItem]) -> [InventoryItemStatus] {
        return self.map { item in
            let stockForItem = stockLocations.filter { $0.inventoryItem?.id == item.id }
            let totalQuantity = stockForItem.reduce(0) { $0 + $1.quantity }
            let totalValue = Double(totalQuantity) * item.pricePerUnit
            let minStock = stockForItem.map(\.minimumStockLevel).max() ?? 5
            
            let status: StockStatus
            if totalQuantity == 0 {
                status = .outOfStock
            } else if totalQuantity <= minStock {
                status = .lowStock
            } else if totalQuantity > minStock * 3 {
                status = .overStock
            } else {
                status = .inStock
            }
            
            return InventoryItemStatus(
                item: item,
                totalQuantity: totalQuantity,
                totalValue: totalValue,
                status: status,
                locations: stockForItem.count
            )
        }
    }
}

// MARK: - Inventory Row View Component

struct InventoryRowView: View {
    let itemStatus: InventoryItemStatus
    let onTap: () -> Void
    
    @State private var stockLocations: [StockLocationItem] = []
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Item photo or placeholder
                if let photoData = itemStatus.item.photoData,
                   let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                } else {
                    Image(systemName: "cube.box")
                        .font(.title2)
                        .foregroundColor(.gray)
                        .frame(width: 50, height: 50)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                
                // Item information
                VStack(alignment: .leading, spacing: 4) {
                    Text(itemStatus.item.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(itemStatus.item.partNumber)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text(itemStatus.item.category)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if !warehouseInfo.isEmpty {
                            Divider()
                                .frame(height: 12)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "building.2")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                Text(warehouseInfo)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Status and quantity information
                VStack(alignment: .trailing, spacing: 4) {
                    HStack {
                        Image(systemName: itemStatus.status.icon)
                            .foregroundColor(itemStatus.status.color)
                        Text(itemStatus.status.text)
                            .font(.caption)
                            .foregroundColor(itemStatus.status.color)
                    }
                    
                    Text("\(itemStatus.totalQuantity) \(itemStatus.item.unit)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(String(format: "$%.2f", itemStatus.totalValue))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if itemStatus.locations > 0 {
                        Text("\(itemStatus.locations) location\(itemStatus.locations == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // Computed property to show warehouse information
    private var warehouseInfo: String {
        // Get warehouse information from stock locations
        if let stockLocationItems = itemStatus.item.stockLocationItems {
            let warehouses = stockLocationItems.compactMap { $0.warehouse?.name }.unique()
            let vehicles = stockLocationItems.compactMap { $0.vehicle?.make }.unique()
            
            if warehouses.count == 1 && vehicles.isEmpty {
                return warehouses.first ?? ""
            } else if warehouses.isEmpty && vehicles.count == 1 {
                return vehicles.first ?? ""
            } else if warehouses.count + vehicles.count > 1 {
                return "Multiple"
            }
        }
        return ""
    }
}

// Helper extension for unique arrays
extension Array where Element: Hashable {
    func unique() -> Array {
        return Array(Set(self))
    }
}

// MARK: - Inventory Summary Card

struct InventorySummaryCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String
    let color: Color
    let action: (() -> Void)?
    
    init(title: String, value: String, subtitle: String? = nil, icon: String, color: Color, action: (() -> Void)? = nil) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
        self.action = action
    }
    
    var body: some View {
        Button(action: action ?? {}) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.title2)
                    
                    Spacer()
                    
                    if action != nil {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(value)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(action == nil)
    }
} 