# Vehix Model Architecture Documentation

## Overview
This document explains the architecture of the Vehix app's data model system, particularly focusing on inventory items, type aliases, and the pattern for extending functionality through extensions. Understanding this architecture is crucial for maintaining and extending the codebase.

## Type Aliases and Model Relationships

### Core Type Aliases
The app uses type aliases (defined in `ModelConfiguration.swift`) to provide a consistent API across the codebase:

```swift
typealias AppInventoryItem = Vehix.InventoryItem
typealias AppVehicle = Vehix.Vehicle
typealias AppServiceRecord = Vehix.ServiceRecord
typealias AppVendor = Vehix.Vendor
typealias AppWarehouse = Vehix.Warehouse
typealias AppUser = Auth.User
typealias AppInventoryUsageRecord = Vehix.InventoryUsageRecord
```

### Model Implementations
There are multiple implementations of similar models in the codebase:

1. **Namespace Models** (`VehicleModels.swift`):
   - `Vehix.InventoryItem`
   - `Vehix.Vehicle`
   - `Vehix.ServiceRecord`
   - `Vehix.Vendor`
   - `Vehix.InventoryUsageRecord` (simplified version)

2. **Individual Model Files**:
   - `InventoryItem.swift` contains `InventoryItem`
   - `Vehicle.swift` contains `Vehicle`
   - `ServiceRecord.swift` contains `ServiceRecord`
   - `Vendor.swift` contains `Vendor`
   - `Warehouse.swift` contains `Warehouse`

3. **Extended Models** in InventoryItemExtended.swift:
   - `InventoryUsageRecord` (enhanced version with additional fields)

### Inventory Usage Records Implementation

A key challenge in the architecture is the presence of two different implementations of the inventory usage record model:

1. **Vehix.InventoryUsageRecord** (defined in VehicleModels.swift):
   ```swift
   @Model
   final class InventoryUsageRecord {
       var id: String
       var inventoryItemId: String
       var quantity: Int
       var timestamp: Date
       var technicianId: String?
       var vehicleId: String?
       var jobId: String?
       var notes: String?
       var photoEvidence: Data?
       
       init(id: String = UUID().uuidString, 
            inventoryItemId: String, 
            quantity: Int,
            timestamp: Date = Date(),
            technicianId: String? = nil,
            vehicleId: String? = nil,
            jobId: String? = nil,
            notes: String? = nil) { ... }
   }
   ```

2. **InventoryUsageRecord** (defined in InventoryItemExtended.swift):
   ```swift
   @Model
   final class InventoryUsageRecord {
       var id: String
       var itemId: String             
       var quantity: Int
       var usageDate: Date
       var jobId: String?
       var jobNumber: String?
       var technicianId: String?
       var technicianName: String?
       var vehicleId: String?
       var comments: String?
       var imageData: Data?
       var cost: Double
       var createdAt: Date
       
       // Relationships
       var inventoryItem: AppInventoryItem?
       var vehicle: AppVehicle?
       var serviceRecord: AppServiceRecord?
       
       init(id:, itemId:, quantity:, usageDate:, jobId:, jobNumber:,
            technicianId:, technicianName:, vehicleId:, comments:,
            imageData:, cost:, inventoryItem:, vehicle:, serviceRecord:,
            createdAt:) { ... }
   }
   ```

**Important Implementation Note**: 
The enhanced `InventoryUsageRecord` from InventoryItemExtended.swift should be used instead of the `AppInventoryUsageRecord` type alias when additional fields or relationships are needed. Key differences:

- Field names: `usageDate` vs `timestamp`, `itemId` vs `inventoryItemId`
- Additional fields: `cost`, `jobNumber`, `technicianName`, etc.
- Relationship fields: `inventoryItem`, `vehicle`, `serviceRecord`

### Important Relationships

The current architecture is transitioning from individual model files to the consolidated namespace approach. Throughout the codebase, you should:

- Use the `AppX` type aliases consistently rather than direct model references
- Be aware of property overlap between different model implementations
- For inventory usage records, use the enhanced `InventoryUsageRecord` class directly, not the type alias

## Extension Pattern

### Extension Usage

Extensions are used to add functionality to models without modifying their core definitions:

1. **Base Properties**: The `Vehix.InventoryItem` in `VehicleModels.swift` defines the core properties.

2. **Extended Functionality**: Files like `InventoryItemExtended.swift` add computed properties and methods.

3. **Manager Extensions**: Files like `InventoryManager.swift` may also add properties with runtime associated objects.

### Warehouse Relationship Pattern

The warehouse relationship is handled through extension properties in `InventoryItemExtended.swift`:

```swift
// Add warehouse relationship properties that don't exist in the base class
@objc var warehouseId: String? {
    get {
        // Use location as a proxy for warehouseId
        return location
    }
    set {
        location = newValue
    }
}

// Warehouse relationship (computed property that loads the warehouse on-demand)
var warehouse: AppWarehouse? {
    get {
        guard let warehouseId = warehouseId else { return nil }
        guard let modelContext = ModelContext.current() else { return nil }
        
        // Fetch warehouse by ID
        let descriptor = FetchDescriptor<AppWarehouse>(
            predicate: #Predicate<AppWarehouse> { warehouse in
                warehouse.id == warehouseId
            }
        )
        let warehouses = try? modelContext.fetch(descriptor)
        return warehouses?.first
    }
    set {
        warehouseId = newValue?.id
    }
}
```

This pattern allows us to:
1. Use the `location` property as storage for the warehouse ID
2. Lazily load the warehouse object when needed
3. Maintain compatibility with code that expects a `warehouse` property

### Vehicle Relationships

When assigning models to vehicles, we must be careful with type conversions. The pattern to follow is:

```swift
// Instead of direct assignment (which causes type errors)
record.vehicle = self  // Error: Cannot assign 'Vehicle' to 'Vehix.Vehicle'

// Create a typed AppVehicle object using the same properties
let appVehicle = AppVehicle(
    id: self.id,
    make: self.make,
    model: self.model,
    year: self.year
)
// Then assign the properly typed object
record.vehicle = appVehicle
```

### Avoiding Duplicate Properties

A key challenge in the architecture is avoiding duplicate property definitions. To handle this:

1. **Documentation**: Always document when a property might be defined elsewhere.

2. **Helper Methods**: Use helper methods instead of computed properties when duplicates might exist.

3. **Protocol Bridging**: Use protocols like `ExtendedInventoryItem` to bridge between optional and non-optional versions of properties.

## Optional vs Non-Optional Properties

### The Challenge

Some properties exist in multiple places with different optionality:

```swift
// In InventoryManager.swift
var needsWarehouseReplenishment: Bool? { ... }

// In InventoryItemExtended.swift (commented out to avoid conflicts)
var needsWarehouseReplenishment: Bool { ... }
```

### Solution Pattern

To handle these differences safely:

1. **Helper Methods**: Create methods that safely unwrap optional properties:

```swift
func isReplenishmentNeeded() -> Bool {
    if let needsReplenishment = (self as? any ExtendedInventoryItem)?.needsWarehouseReplenishment {
        return needsReplenishment
    }
    // Fallback logic
    return quantity <= reorderPoint
}
```

2. **Protocol Bridging**: Define protocols that make the relationship explicit:

```swift
protocol ExtendedInventoryItem {
    var needsWarehouseReplenishment: Bool? { get }
    var suggestedReplenishmentQuantity: Int? { get }
}
```

### Helper Methods vs Optional Values

When working with optional values in SwiftUI:

1. **Always unwrap optional values** before using them in conditional statements or calculations
2. **Provide default values** for optionals when used in UI components
3. **Use extension methods** to standardize handling of optional values:

```swift 
// Instead of using optional property directly in views
if item.needsWarehouseReplenishment == true {
    // This could cause problems if needsWarehouseReplenishment is nil
}

// Use a helper method that safely handles the optional
if item.isReplenishmentNeeded() {
    // This is safe regardless of the property's optionality
}
```

## iOS 18 Compatibility

### SwiftData Predicates

iOS 18 has more strict requirements for SwiftData predicates:

1. **Use `#Predicate`** syntax for type-safe predicates:

```swift
let descriptor = FetchDescriptor<InventoryUsageRecord>(
    predicate: #Predicate<InventoryUsageRecord> { record in
        record.itemId == itemId
    }
)
```

2. **Simpler Filters for Complex Logic**: When complex predicates cause compiler type-checking timeouts, break them into simpler steps:

```swift
// Instead of complex nested predicates that might time out:
descriptor = FetchDescriptor<AppInventoryUsageRecord>(
    predicate: #Predicate<AppInventoryUsageRecord> { record in
        record.usageDate >= startDate &&
        record.usageDate <= endDate &&
        record.vehicleId == vehicleId &&
        record.technicianId == technicianId
    }
)

// Use a two-step approach for complex filtering:
// 1. Fetch all records with a simple descriptor
let baseDescriptor = FetchDescriptor<InventoryUsageRecord>()
let allRecords = try modelContext.fetch(baseDescriptor)

// 2. Filter in memory where logic is more complex
let filteredRecords = allRecords.filter { record in
    let dateMatches = record.usageDate >= startDate && record.usageDate <= endDate
    return dateMatches && record.vehicleId == vehicleId && record.technicianId == technicianId
}
```

3. **Local Filtering**: When complex predicates are needed, fetch all items and filter locally:

```swift
let descriptor = FetchDescriptor<AppUser>()
let allUsers = try modelContext.fetch(descriptor)
return allUsers.first(where: { $0.id == techId })?.fullName ?? "Unknown"
```

## Best Practices for Code Changes

When modifying the codebase, follow these guidelines:

1. **Consistent Type Aliases**: Always use `AppX` type aliases rather than direct model references.

2. **Check for Duplicates**: Before adding computed properties, check if they exist elsewhere in the codebase.

3. **Add Documentation**: When extending models, document the relationships and potential conflicts.

4. **Safe Property Access**: For properties that might be defined in multiple places:
   - Create helper methods that handle optionality safely
   - Use protocol bridging where appropriate

5. **Regression Testing**: After making changes, test all views that might be affected by model changes.

6. **Model Initialization**: When creating a new model instance, be careful to initialize it with the correct type:
   ```swift
   // Wrong: Direct initialization with wrong type
   let vehicle = Vehicle(...)
   record.vehicle = vehicle // Type mismatch error
   
   // Correct: Initialize with the proper AppVehicle alias
   let vehicle = AppVehicle(...)
   record.vehicle = vehicle // Works correctly
   ```

7. **Handle Different InventoryUsageRecord Implementations**:
   - Use the enhanced `InventoryUsageRecord` from InventoryItemExtended.swift for most features
   - Carefully check field names and available properties when referencing either implementation

## Future Improvements

The architecture could be improved by:

1. **Complete Consolidation**: Finish migrating to the `Vehix` namespace approach.

2. **Property Centralization**: Define all computed properties in a single extension file per model.

3. **Protocol Conformance**: Make all models explicitly conform to protocols that define their extended behavior.

4. **Documentation Generation**: Add SwiftDoc comments to enable automatic documentation generation.

5. **Unified Model Implementations**: Consolidate the duplicate `InventoryUsageRecord` implementations into a single, comprehensive model. 