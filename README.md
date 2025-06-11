# Vehix App

A comprehensive inventory management application for vehicle service businesses.

## Model Ambiguity Issue Resolution

### Problem

The app was experiencing model ambiguity errors due to duplicate model class definitions across different files:

- Models defined in individual files (e.g., `User.swift`, `Vehicle.swift`, `InventoryItem.swift`)
- Models defined in consolidated files (e.g., `VehicleModels.swift`)

This caused Swift compiler errors like:
```
'Vehicle' is ambiguous for type lookup in this context
Found this candidate
Found this candidate
```

### Implemented Solution

We've resolved the ambiguity issues with a comprehensive namespace approach:

1. **Namespacing Models in `VehicleModels.swift`**
   - All model definitions in VehicleModels.swift are now within the `Vehix` namespace
   - Relationships between models use fully qualified names (e.g., `Vehix.Vehicle`)
   - Added additional models to the namespace (Vendor, Warehouse, InventoryUsageRecord)

2. **TypeAlias Definitions in `ModelConfiguration.swift`**
   - Created clear typealiases for use throughout the app (e.g., `AppVehicle`, `AppInventoryItem`)
   - Added comprehensive documentation on how to implement these

3. **Auth Service Disambiguation**
   - Created `AuthNamespace.swift` with `AppAuthService` typealias
   - Updated key views to use `AppAuthService` instead of `AuthService`

4. **Updated Schema Configuration in `VehixApp.swift`**
   - Added explicit namespace references in the schema
   - Added migration instructions in comments

## Remaining Tasks to Fix Ambiguity Issues

To completely resolve the remaining ambiguity issues, follow these steps:

### 1. Update AuthService References in Views

In any file with the error `'AuthService' is ambiguous for type lookup in this context`:

```swift
// Change from:
@EnvironmentObject var authService: AuthService

// To:
@EnvironmentObject var authService: AppAuthService

// And in preview providers:
.environmentObject(AppAuthService())
```

### 2. Update Model References to Use AppX Typealiases

For files with model ambiguity errors like `'Vehicle' is ambiguous for type lookup in this context`:

```swift
// Change from:
@Query var vehicles: [Vehicle]
@State private var vehicle: Vehicle?
func processVehicle(_ vehicle: Vehicle) -> Void

// To:
@Query var vehicles: [AppVehicle]
@State private var vehicle: AppVehicle?
func processVehicle(_ vehicle: AppVehicle) -> Void
```

### 3. Fix Invalid Component Errors in Swift Key Paths

For errors like `Invalid component of Swift key path`:

```swift
// Change from:
@Relationship(inverse: \ServiceRecord.vehicle)

// To:
@Relationship(inverse: \Vehix.ServiceRecord.vehicle)
// or
@Relationship(inverse: \AppServiceRecord.vehicle)
```

### 4. Remove "return" in ViewBuilder Context

For errors like `Cannot use explicit 'return' statement in the body of result builder 'ViewBuilder'`:
```swift
// Change from:
var body: some View {
    if condition {
        return Text("Condition is true")
    } else {
        return Text("Condition is false")
    }
}

// To:
var body: some View {
    if condition {
        Text("Condition is true")
    } else {
        Text("Condition is false")
    }
}
```

### 5. Special Case: Missing ModelContext Parameter

For the error `Missing argument for parameter 'modelContext' in call`:

Add the modelContext parameter to the call, or if it's an initializer, update to pass the modelContext.

### 6. Resolve Redundant Declarations

For errors like `Invalid redeclaration of 'XYZ'`:

1. Check where the duplicated component is defined
2. Update one of the duplicates to have a distinct name or namespace
3. Consider using the AppX typealiases instead of direct model references

## Testing After Changes

After making these changes:

1. Build the project regularly to catch any new errors
2. Test each view after updating
3. Verify that all data operations work correctly
4. Ensure relationships between models are maintained

## Features

- Inventory management for service vehicles and warehouse
- Usage tracking with photo evidence
- Automatic replenishment alerting
- Vendor management and order generation
- Integration with ServiceTitan and Samsara

## Development Setup

1. Clone the repository
2. Open `Vehix.xcodeproj` in Xcode
3. Build and run the project

## Architecture

The app uses SwiftData for persistence and follows MVVM architecture:
- Models: Defined in the `Models` directory
- Views: SwiftUI views for user interaction
- Services: Business logic and data processing

## Testing

Run the test suite with:
```
Command+U
``` 