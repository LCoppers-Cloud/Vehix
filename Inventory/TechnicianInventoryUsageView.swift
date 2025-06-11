import SwiftUI
import SwiftData
import CoreLocation
import PhotosUI

struct TechnicianInventoryUsageView: View {
    @EnvironmentObject var authService: AppAuthService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let vehicle: AppVehicle
    let stockItem: StockLocationItem
    
    @StateObject private var locationManager = LocationManager()
    @State private var usageQuantity = 1
    @State private var notes = ""
    @State private var showingPhotoCapture = false
    @State private var usagePhoto: UIImage?
    @State private var jobNumber = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Item Details")) {
                    if let item = stockItem.inventoryItem {
                        LabeledContent("Item") {
                            Text(item.name)
                        }
                        LabeledContent("Available Quantity") {
                            Text("\(stockItem.quantity)")
                        }
                    }
                }
                
                Section(header: Text("Usage Details")) {
                    TextField("Job Number", text: $jobNumber)
                        .keyboardType(.numberPad)
                    
                    Stepper("Quantity Used: \(usageQuantity)", value: $usageQuantity, in: 1...stockItem.quantity)
                    
                    TextField("Notes", text: $notes)
                }
                
                Section(header: Text("Photo Documentation")) {
                    Button(action: { showingPhotoCapture = true }) {
                        Label("Take Photo", systemImage: "camera")
                    }
                    
                    if let photo = usagePhoto {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                    }
                }
                
                Section(header: Text("Location")) {
                    if let location = locationManager.currentLocation {
                        LabeledContent("Latitude") {
                            Text(String(format: "%.6f", location.coordinate.latitude))
                        }
                        LabeledContent("Longitude") {
                            Text(String(format: "%.6f", location.coordinate.longitude))
                        }
                    } else {
                        Text("Acquiring location...")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Record Usage")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Submit") { recordUsage() }
                    .disabled(!canSubmit)
            )
            .sheet(isPresented: $showingPhotoCapture) {
                ImagePicker(image: $usagePhoto)
            }
            .onAppear {
                locationManager.requestLocation()
            }
        }
    }
    
    private var canSubmit: Bool {
        !jobNumber.isEmpty && usageQuantity > 0 && usageQuantity <= stockItem.quantity && usagePhoto != nil
    }
    
    private func recordUsage() {
        guard let item = stockItem.inventoryItem,
              let _ = locationManager.currentLocation,
              let user = authService.currentUser else { return }
        
        // Create usage record
        let usageRecord = AppInventoryUsageRecord(
            id: UUID().uuidString,
            inventoryItemId: item.id,
            quantity: usageQuantity,
            timestamp: Date(),
            technicianId: user.id,
            vehicleId: vehicle.id,
            jobId: jobNumber,
            notes: notes
        )
        
        // Update stock quantity
        stockItem.quantity -= usageQuantity
        stockItem.updatedAt = Date()
        
        // Save to model context
        modelContext.insert(usageRecord)
        
        dismiss()
    }
}

// Location Manager for GPS tracking
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    
    @Published var currentLocation: CLLocation?
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestLocation() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.first
        manager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
} 