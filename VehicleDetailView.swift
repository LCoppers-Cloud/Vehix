import SwiftUI
import SwiftData

struct VehicleDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authService: AppAuthService
    let vehicle: AppVehicle
    
    @State private var showingEditSheet = false
    @State private var showingSamsaraDetails = false
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Vehicle Image
                ZStack(alignment: .bottomTrailing) {
                    if let data = vehicle.photoData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                            .clipped()
                    } else {
                        HStack {
                            Spacer()
                            Image(systemName: "car.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                                .frame(width: 120, height: 120)
                                .background(Color.blue.opacity(0.8))
                                .clipShape(Circle())
                            Spacer()
                        }
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.3))
                    }
                    
                    // Location indicator (if Samsara connected)
                    if vehicle.isTrackedBySamsara, let location = vehicle.lastKnownLocation {
                        Button(action: {
                            showingSamsaraDetails = true
                        }) {
                            HStack {
                                Image(systemName: "location.fill")
                                Text(location)
                                    .lineLimit(1)
                            }
                            .font(.caption)
                            .padding(8)
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(20)
                            .padding(12)
                        }
                    }
                }
                
                // Vehicle Info
                VStack(alignment: .leading, spacing: 20) {
                    // Basic Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text(vehicle.displayName)
                            .font(.title2)
                            .bold()
                        
                        if let plate = vehicle.licensePlate, !plate.isEmpty {
                            Text("License: \(plate)")
                                .foregroundColor(.secondary)
                        }
                        
                        Text("Type: \(vehicle.vehicleType)")
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // Maintenance Information
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Maintenance")
                            .font(.headline)
                        
                        // Mileage
                        HStack {
                            Image(systemName: "gauge")
                                .frame(width: 24)
                            Text("Mileage: \(vehicle.mileage) miles")
                            
                            if vehicle.isTrackedBySamsara {
                                Text("(Automatic)")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        // Oil Change Info
                        if vehicle.vehicleType != "Electric" {
                            HStack(alignment: .top) {
                                Image(systemName: "drop.fill")
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading) {
                                    if let lastOilDate = vehicle.lastOilChangeDate, let lastOilMileage = vehicle.lastOilChangeMileage {
                                        Text("Last Oil Change: \(formatDate(lastOilDate)) at \(lastOilMileage) miles")
                                    } else {
                                        Text("No oil change records")
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    if vehicle.isOilChangeDue {
                                        Text("Status: DUE NOW")
                                            .foregroundColor(.red)
                                            .bold()
                                    } else {
                                        Text("Status: \(vehicle.oilChangeDueStatus)")
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    // Inventory Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Inventory")
                                .font(.headline)
                            
                            Spacer()
                            
                            if authService.currentUser?.userRole == .admin || authService.currentUser?.userRole == .dealer {
                                NavigationLink(destination: AddInventoryToVehicleView(vehicle: vehicle)) {
                                    Label("Add Items", systemImage: "plus")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(5)
                                }
                            }
                        }
                        
                        if let stockItems = vehicle.stockItems, !stockItems.isEmpty {
                            ForEach(stockItems) { item in
                                HStack {
                                    Text(item.inventoryItem?.name ?? "Unknown Item")
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text("Qty: \(item.quantity)")
                                        .foregroundColor(item.isBelowMinimumStock ? .red : .secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        } else {
                            Text("No inventory assigned to this vehicle")
                                .foregroundColor(.secondary)
                                .italic()
                        }
                        
                        if let stockItems = vehicle.stockItems, !stockItems.isEmpty {
                            Divider()
                            
                            HStack {
                                Text("Total Value:")
                                    .fontWeight(.medium)
                                Spacer()
                                Text("$\(String(format: "%.2f", vehicle.totalInventoryValue))")
                                    .fontWeight(.bold)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    // Additional Information
                    if vehicle.isTrackedBySamsara {
                        samsaraSection
                    }
                }
                
                Spacer()
            }
        }
        .navigationTitle("Vehicle Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if authService.currentUser?.userRole == .admin || authService.currentUser?.userRole == .dealer {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Edit Vehicle") {
                            showingEditSheet = true
                        }
                        
                        Button("Delete Vehicle", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditVehicleForm(vehicle: vehicle) { updatedVehicle in
                // Refresh view with updated vehicle data if needed
            }
        }
        .sheet(isPresented: $showingSamsaraDetails) {
            // TODO: Implement Samsara details view with map
            Text("Samsara Location Map Placeholder")
        }
        .confirmationDialog(
            "Delete Vehicle",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                // Delete the vehicle
                modelContext.delete(vehicle)
                try? modelContext.save()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this vehicle? This action cannot be undone.")
        }
    }
    
    // Helper function to format dates
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    // Samsara section
    private var samsaraSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GPS Tracking")
                .font(.headline)
            
            HStack(alignment: .top) {
                Image(systemName: "location.fill")
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    if let location = vehicle.lastKnownLocation {
                        Text(location)
                    } else {
                        Text("Location unavailable")
                            .foregroundColor(.secondary)
                    }
                    
                    if let date = vehicle.lastLocationUpdateDate {
                        Text("Updated: \(formatDate(date))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Button(action: {
                showingSamsaraDetails = true
            }) {
                Text("View on Map")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

// Placeholder for AddInventoryToVehicleView
struct AddInventoryToVehicleView: View {
    let vehicle: AppVehicle
    
    var body: some View {
        // This will be implemented fully in a separate file
        Text("Add Inventory to \(vehicle.displayName)")
            .navigationTitle("Add Inventory")
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: AppVehicle.self, configurations: config)
        
        let sampleVehicle = AppVehicle(
            make: "Toyota",
            model: "Camry",
            year: 2022,
            mileage: 15000
        )
        
        return NavigationStack {
            VehicleDetailView(vehicle: sampleVehicle)
        }
        .modelContainer(container)
        .environmentObject(AppAuthService())
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
} 