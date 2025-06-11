import SwiftUI
import SwiftData
import AVFoundation
import CoreLocation
import UIKit
import UserNotifications

// All component types are already available in the project without special imports

// The enhanced VendorSelectionView is in a separate file
// which is used in place of the original implementation

// MARK: - Models and Enums

// GPS-based customer location for when ServiceTitan is not connected
struct GPSCustomerLocation: Identifiable, Codable {
    var id = UUID().uuidString
    var customerName: String
    var address: String
    var coordinates: CLLocationCoordinate2D
    var lastVisited: Date
    var visitCount: Int = 1
    var isManuallyAdded: Bool = false
    
    // For Codable compliance with CLLocationCoordinate2D
    enum CodingKeys: String, CodingKey {
        case id, customerName, address, lastVisited, visitCount, isManuallyAdded
        case latitude, longitude
    }
    
    init(customerName: String, address: String, coordinates: CLLocationCoordinate2D, isManuallyAdded: Bool = false) {
        self.customerName = customerName
        self.address = address
        self.coordinates = coordinates
        self.lastVisited = Date()
        self.isManuallyAdded = isManuallyAdded
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        customerName = try container.decode(String.self, forKey: .customerName)
        address = try container.decode(String.self, forKey: .address)
        lastVisited = try container.decode(Date.self, forKey: .lastVisited)
        visitCount = try container.decode(Int.self, forKey: .visitCount)
        isManuallyAdded = try container.decode(Bool.self, forKey: .isManuallyAdded)
        
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        coordinates = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(customerName, forKey: .customerName)
        try container.encode(address, forKey: .address)
        try container.encode(lastVisited, forKey: .lastVisited)
        try container.encode(visitCount, forKey: .visitCount)
        try container.encode(isManuallyAdded, forKey: .isManuallyAdded)
        try container.encode(coordinates.latitude, forKey: .latitude)
        try container.encode(coordinates.longitude, forKey: .longitude)
    }
}

// Models
struct PurchaseOrderDraft: Identifiable {
    var id = UUID().uuidString
    var jobId: String
    var jobNumber: String
    var customerName: String
    var customerAddress: String
    var vendorId: String
    var vendorName: String
    var poNumber: String
    var date: Date = Date()
    var total: Double?
    var receiptImage: UIImage?
    var locationDescription: String?
    var coordinates: CLLocationCoordinate2D?
    var technicianId: String
    var technicianName: String
    var isCurrentJob: Bool = false
    var status: PurchaseOrderStatus = .draft
    var managerNotes: String?
    var isValidated: Bool = false
    
    // Validation for mandatory fields
    var isValid: Bool {
        return !jobId.isEmpty && 
               !vendorId.isEmpty && 
               !vendorName.isEmpty && 
               total != nil && 
               total! > 0 && 
               receiptImage != nil
    }
    
    // Convert to the actual PurchaseOrder model
    func toPurchaseOrder(userId: String, userName: String) -> PurchaseOrder {
        let po = PurchaseOrder(
            poNumber: poNumber,
            date: date,
            vendorId: vendorId,
            vendorName: vendorName,
            status: .submitted,
            subtotal: total ?? 0,
            tax: 0, // Could calculate this based on location
            total: total ?? 0,
            notes: managerNotes,
            createdByUserId: userId,
            createdByName: userName,
            serviceTitanJobId: jobId,
            serviceTitanJobNumber: jobNumber
        )
        
        // Create receipt if image exists
        if let image = receiptImage {
            let receipt = Receipt(
                date: date,
                total: total ?? 0,
                imageData: image.jpegData(compressionQuality: 0.8),
                vendorId: vendorId,
                rawVendorName: vendorName
            )
            po.receipt = receipt
        }
        
        return po
    }
}

// Purchase Order Creation Flow
@MainActor
class PurchaseOrderCreationManager: ObservableObject {
    @Published var currentStep: POCreationStep = .selectJob
    @Published var draft: PurchaseOrderDraft?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingAlert = false
    @Published var showingExitWarning = false
    @Published var requiresReceipt: Bool = true
    @Published var availableJobs: [ServiceTitanJob] = []
    @Published var currentJob: ServiceTitanJob?
    @Published var scannedReceipt: Receipt?
    @Published var recognizedVendor: AppVendor?
    @Published var manualTotal: String = ""
    @Published var isSubmittingToManager = false
    @Published var hasValidationErrors = false
    @Published var validationMessage = ""
    
    let syncManager: ServiceTitanSyncManager
    @Published var receiptScannerManager: ReceiptScannerManager
    private var modelContext: ModelContext?
    
    var locationManager = CLLocationManager()
    var currentLocation: CLLocationCoordinate2D?
    var locationDescription: String?
    private var locationDelegate: LocationDelegate?
    private var poIdentifier: String?
    
    // GPS-based customer locations (when ServiceTitan not connected)
    @Published var gpsCustomerLocations: [GPSCustomerLocation] = []
    @Published var showingGPSCustomerSelection = false
    @Published var showingManualCustomerEntry = false
    @Published var isLookingUpAddress = false
    private var locationHistory: [CLLocationCoordinate2D] = []
    
    // App lifecycle monitoring
    @Published var appWillTerminate = false
    
    init(syncManager: ServiceTitanSyncManager, modelContext: ModelContext?) {
        self.syncManager = syncManager
        self.modelContext = modelContext
        
        // Initialize receipt scanner manager on main actor
        if let context = modelContext {
            self.receiptScannerManager = ReceiptScannerManager(modelContext: context)
        } else {
            self.receiptScannerManager = ReceiptScannerManager(modelContext: nil)
        }
        
        setupLocationManager()
        setupAppLifecycleMonitoring()
        checkForInProgressPurchaseOrders()
        loadGPSCustomerHistory()
        
        // Load jobs only if ServiceTitan is connected
        if syncManager.serviceTitanService.isConnected {
            loadAvailableJobs()
        } else {
            // If not connected, prepare GPS-based customer selection
            startGPSLocationTracking()
        }
    }
    
    func setModelContext(_ context: ModelContext?) {
        self.modelContext = context
        if let context = context {
            self.receiptScannerManager = ReceiptScannerManager(modelContext: context)
        }
    }
    
    private func setupLocationManager() {
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        
        locationDelegate = LocationDelegate { [weak self] location, description in
            self?.currentLocation = location
            self?.locationDescription = description
            
            // Track location history for GPS-based customer detection
            if !(self?.syncManager.serviceTitanService.isConnected ?? false) {
                self?.trackLocationForCustomerDetection(location)
            }
        }
        locationManager.delegate = locationDelegate
    }
    
    // MARK: - GPS-Based Customer Location Methods
    
    private func startGPSLocationTracking() {
        print("📍 Starting GPS-based customer location tracking (ServiceTitan not connected)")
        // Location updates are handled by the existing location manager
    }
    
    private func trackLocationForCustomerDetection(_ location: CLLocationCoordinate2D) {
        locationHistory.append(location)
        
        // Keep only recent locations (last 50)
        if locationHistory.count > 50 {
            locationHistory.removeFirst()
        }
        
        // Check if we're at a known customer location
        checkForNearbyCustomers(location)
    }
    
    private func checkForNearbyCustomers(_ location: CLLocationCoordinate2D) {
        for customerLocation in gpsCustomerLocations {
            let distance = distanceBetween(location, customerLocation.coordinates)
            
            // If within 100 meters of a known customer location
            if distance < 100 {
                // Update visit count and last visited date
                updateCustomerLocationVisit(customerLocation.id)
                break
            }
        }
    }
    
    private func distanceBetween(_ coord1: CLLocationCoordinate2D, _ coord2: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: coord1.latitude, longitude: coord1.longitude)
        let location2 = CLLocation(latitude: coord2.latitude, longitude: coord2.longitude)
        return location1.distance(from: location2)
    }
    
    private func updateCustomerLocationVisit(_ customerId: String) {
        if let index = gpsCustomerLocations.firstIndex(where: { $0.id == customerId }) {
            gpsCustomerLocations[index].lastVisited = Date()
            gpsCustomerLocations[index].visitCount += 1
            saveGPSCustomerHistory()
        }
    }
    
    private func loadGPSCustomerHistory() {
        if let data = UserDefaults.standard.data(forKey: "gps_customer_locations"),
           let locations = try? JSONDecoder().decode([GPSCustomerLocation].self, from: data) {
            gpsCustomerLocations = locations
        }
    }
    
    private func saveGPSCustomerHistory() {
        do {
            let data = try JSONEncoder().encode(gpsCustomerLocations)
            UserDefaults.standard.set(data, forKey: "gps_customer_locations")
        } catch {
            print("❌ Failed to save GPS customer history: \(error)")
        }
    }
    
    func addManualCustomerLocation(customerName: String, address: String) {
        guard let currentLocation = currentLocation else {
            errorMessage = "Current location not available"
            return
        }
        
        let newCustomer = GPSCustomerLocation(
            customerName: customerName,
            address: address,
            coordinates: currentLocation,
            isManuallyAdded: true
        )
        
        gpsCustomerLocations.append(newCustomer)
        saveGPSCustomerHistory()
        
        // Create draft with this customer
        createDraftFromGPSCustomer(newCustomer)
    }
    
    func lookupAddressFromGPS(_ location: CLLocationCoordinate2D, completion: @escaping (String?) -> Void) {
        let geocoder = CLGeocoder()
        let clLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        
        isLookingUpAddress = true
        geocoder.reverseGeocodeLocation(clLocation) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                self?.isLookingUpAddress = false
                
                if let placemark = placemarks?.first {
                    let address = [
                        placemark.subThoroughfare,
                        placemark.thoroughfare,
                        placemark.locality,
                        placemark.administrativeArea,
                        placemark.postalCode
                    ].compactMap { $0 }.joined(separator: ", ")
                    
                    completion(address.isEmpty ? nil : address)
                } else {
                    completion(nil)
                }
            }
        }
    }
    
    func createDraftFromGPSCustomer(_ customer: GPSCustomerLocation) {
        guard let currentUserId = getCurrentTechnicianId(),
              let currentUserName = getCurrentTechnicianName() else {
            errorMessage = "Technician information not available"
            return
        }
        
        draft = PurchaseOrderDraft(
            jobId: "GPS-\(UUID().uuidString.prefix(8))",
            jobNumber: "GPS-\(Date().timeIntervalSince1970)",
            customerName: customer.customerName,
            customerAddress: customer.address,
            vendorId: "",
            vendorName: "",
            poNumber: generatePONumber(jobNumber: "GPS", technicianId: currentUserId),
            technicianId: currentUserId,
            technicianName: currentUserName
        )
        
        draft?.coordinates = customer.coordinates
        currentStep = .captureReceipt
    }
    
    private func getCurrentTechnicianId() -> String? {
        // Replace with actual technician ID from authentication
        return "tech_gps_\(UUID().uuidString.prefix(8))"
    }
    
    private func getCurrentTechnicianName() -> String? {
        // Replace with actual technician name from authentication
        return "GPS Technician"
    }
    
    func generateGPSBasedCustomerList() {
        guard let currentLocation = currentLocation else {
            errorMessage = "Current location not available"
            return
        }
        
        // Look up address for current location
        lookupAddressFromGPS(currentLocation) { [weak self] address in
            guard let self = self else { return }
            
            if let address = address {
                // Check if this location already exists
                let existingCustomer = self.gpsCustomerLocations.first { customer in
                    self.distanceBetween(currentLocation, customer.coordinates) < 50
                }
                
                if existingCustomer == nil {
                    // Suggest this as a new location
                    let suggestedCustomer = GPSCustomerLocation(
                        customerName: "Customer at \(address.components(separatedBy: ",").first ?? "this location")",
                        address: address,
                        coordinates: currentLocation
                    )
                    
                    // Add to beginning of list as a suggestion
                    self.gpsCustomerLocations.insert(suggestedCustomer, at: 0)
                }
            }
            
            // Sort by most recently visited and proximity
            self.sortGPSCustomersByRelevance()
            self.showingGPSCustomerSelection = true
        }
    }
    
    private func sortGPSCustomersByRelevance() {
        guard let currentLocation = currentLocation else { return }
        
        gpsCustomerLocations.sort { customer1, customer2 in
            let distance1 = distanceBetween(currentLocation, customer1.coordinates)
            let distance2 = distanceBetween(currentLocation, customer2.coordinates)
            
            // Prioritize by proximity first (within 1km), then by recent visits
            if distance1 < 1000 && distance2 >= 1000 {
                return true
            } else if distance1 >= 1000 && distance2 < 1000 {
                return false
            } else {
                // Both are close or both are far, sort by recent visits
                return customer1.lastVisited > customer2.lastVisited
            }
        }
    }
    
    private func setupAppLifecycleMonitoring() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleAppTermination()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleAppBackground()
            }
        }
    }
    
    // Load available jobs for technician
    private func loadAvailableJobs() {
        // Get current technician ID (you'll need to pass this from authentication)
        let currentTechId = "current_tech_id" // Replace with actual technician ID
        
        syncManager.syncJobsForTechnician(techId: currentTechId) { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    self?.availableJobs = self?.syncManager.jobs ?? []
                    self?.identifyCurrentJob()
                } else {
                    self?.errorMessage = "Failed to load jobs"
                }
            }
        }
    }
    
    // Identify current active job
    private func identifyCurrentJob() {
        // Find the job marked as "In Progress" - this should be highlighted in red
        currentJob = availableJobs.first { $0.status.lowercased() == "in progress" }
        
        // If we have a current job, mark it in the draft
        if let current = currentJob, var existingDraft = draft {
            existingDraft.isCurrentJob = true
            existingDraft.jobId = current.id
            existingDraft.jobNumber = current.jobNumber
            existingDraft.customerName = current.customerName
            existingDraft.customerAddress = current.address
            draft = existingDraft
        }
    }
    
    // Generate PO number with enhanced formatting
    func generatePONumber(jobNumber: String, technicianId: String) -> String {
        let date = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateString = dateFormatter.string(from: date)
        
        // Get sequence number for today
        let sequence = getSequenceNumberForToday()
        
        return "\(jobNumber)-\(dateString)-\(String(format: "%03d", sequence))"
    }
    
    private func getSequenceNumberForToday() -> Int {
        // In a real implementation, this would query the database for today's POs
        return Int.random(in: 1...999)
    }
    
    // MARK: - Step Navigation with Validation
    
    func proceedToNextStep() {
        switch currentStep {
        case .selectJob:
            if validateJobSelection() {
                currentStep = .captureReceipt
                saveDraft()
                scheduleInProgressNotification()
            }
        case .captureReceipt:
            if validateReceiptCapture() {
                // Check if we have a recognized vendor from receipt scanning
                if recognizedVendor != nil {
                    currentStep = .enterTotal
                } else {
                    currentStep = .verifyVendor
                }
                saveDraft()
            }
        case .verifyVendor:
            if validateVendor() {
                currentStep = .enterTotal
                saveDraft()
            }
        case .enterTotal:
            if validateTotal() {
                currentStep = .review
                saveDraft()
            }
        case .review:
            if validateReview() {
                submitToManager()
            }
        case .managerApproval:
            break // Handled by manager
        case .complete:
            completePO()
        }
    }
    
    func goToPreviousStep() {
        switch currentStep {
        case .selectJob:
            break
        case .captureReceipt:
            currentStep = .selectJob
        case .verifyVendor:
            currentStep = .captureReceipt
        case .enterTotal:
            currentStep = .verifyVendor
        case .review:
            currentStep = .enterTotal
        case .managerApproval:
            currentStep = .review
        case .complete:
            break
        }
        saveDraft()
    }
    
    // MARK: - Validation Methods
    
    private func validateJobSelection() -> Bool {
        guard let draft = draft else {
            showValidationError("Please select a job for this purchase order.")
            return false
        }
        
        if draft.jobId.isEmpty {
            showValidationError("Please select a job before proceeding.")
            return false
        }
        
        return true
    }
    
    private func validateReceiptCapture() -> Bool {
        guard let draft = draft else {
            showValidationError("No purchase order data found.")
            return false
        }
        
        if draft.receiptImage == nil {
            showValidationError("Please capture a receipt image before proceeding.")
            return false
        }
        
        return true
    }
    
    private func validateVendor() -> Bool {
        guard let draft = draft else {
            showValidationError("No purchase order data found.")
            return false
        }
        
        if draft.vendorId.isEmpty || draft.vendorName.isEmpty {
            showValidationError("Please verify the vendor information before proceeding.")
            return false
        }
        
        return true
    }
    
    private func validateTotal() -> Bool {
        guard let draft = draft else {
            showValidationError("No purchase order data found.")
            return false
        }
        
        guard let total = draft.total, total > 0 else {
            showValidationError("Please enter a valid total amount greater than $0.00.")
            return false
        }
        
        return true
    }
    
    private func validateReview() -> Bool {
        guard let draft = draft else {
            showValidationError("No purchase order data found.")
            return false
        }
        
        if !draft.isValid {
            showValidationError("Please complete all required fields before submitting.")
            return false
        }
        
        return true
    }
    
    private func showValidationError(_ message: String) {
        validationMessage = message
        hasValidationErrors = true
        errorMessage = message
        showingAlert = true
    }
    
    // MARK: - Manager Review Process
    
    private func submitToManager() {
        guard let draft = draft else { return }
        
        isSubmittingToManager = true
        
        // Create the purchase order
        let po = draft.toPurchaseOrder(
            userId: draft.technicianId,
            userName: draft.technicianName
        )
        
        po.status = PurchaseOrderStatus.submitted.rawValue
        
        // Save to database
        modelContext?.insert(po)
        
        do {
            try modelContext?.save()
            
            // Send notification to manager
            scheduleManagerNotification(for: po)
            
            // Update step
            currentStep = .managerApproval
            
            // Clear the draft as it's now submitted
            clearDraft()
            
            isSubmittingToManager = false
            
        } catch {
            errorMessage = "Failed to submit purchase order: \(error.localizedDescription)"
            showingAlert = true
            isSubmittingToManager = false
        }
    }
    
    // MARK: - Notification System
    
    private func scheduleInProgressNotification() {
        guard let draft = draft else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Purchase Order In Progress"
        content.body = "PO \(draft.poNumber) for \(draft.customerName) is waiting to be completed."
        content.categoryIdentifier = "PURCHASE_ORDER"
        content.userInfo = ["poId": draft.id, "step": currentStep.rawValue]
        
        // Schedule notification for 15 minutes if no progress
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 900, repeats: false)
        let request = UNNotificationRequest(
            identifier: "po_in_progress_\(draft.id)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func scheduleManagerNotification(for po: PurchaseOrder) {
        let content = UNMutableNotificationContent()
        content.title = "Purchase Order Requires Approval"
        content.body = "PO \(po.poNumber) from \(po.createdByName) for $\(String(format: "%.2f", po.total)) needs your approval."
        content.categoryIdentifier = "MANAGER_APPROVAL"
        content.userInfo = ["poId": po.id]
        
        let request = UNNotificationRequest(
            identifier: "po_manager_\(po.id)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - App Lifecycle Handling
    
    private func handleAppTermination() {
        if let draft = draft, !draft.isValid {
            // Prevent app closure if PO is incomplete
            scheduleIncompleteNotification()
        }
    }
    
    private func handleAppBackground() {
        if let _ = draft, currentStep != .complete {
            saveDraft()
            scheduleResumeNotification()
        }
    }
    
    private func scheduleIncompleteNotification() {
        guard let draft = draft else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Incomplete Purchase Order"
        content.body = "PO \(draft.poNumber) was not completed. Tap to resume where you left off."
        content.categoryIdentifier = "PURCHASE_ORDER"
        content.userInfo = ["poId": draft.id, "step": currentStep.rawValue]
        
        let request = UNNotificationRequest(
            identifier: "po_incomplete_\(draft.id)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func scheduleResumeNotification() {
        guard let draft = draft else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Resume Purchase Order"
        content.body = "Complete PO \(draft.poNumber) for \(draft.customerName)."
        content.categoryIdentifier = "PURCHASE_ORDER"
        content.userInfo = ["poId": draft.id, "step": currentStep.rawValue]
        
        let request = UNNotificationRequest(
            identifier: "po_resume_\(draft.id)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: false) // 1 hour
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Draft Management
    
    private func saveDraft() {
        guard let draft = draft else { return }
        
        var draftDict: [String: Any] = [
            "id": draft.id,
            "jobId": draft.jobId,
            "jobNumber": draft.jobNumber,
            "customerName": draft.customerName,
            "customerAddress": draft.customerAddress,
            "vendorId": draft.vendorId,
            "vendorName": draft.vendorName,
            "poNumber": draft.poNumber,
            "date": draft.date.timeIntervalSince1970,
            "technicianId": draft.technicianId,
            "technicianName": draft.technicianName,
            "isCurrentJob": draft.isCurrentJob,
            "status": draft.status.rawValue,
            "currentStep": currentStep.rawValue
        ]
        
        if let total = draft.total {
            draftDict["total"] = total
        }
        
        if let locationDesc = locationDescription {
            draftDict["locationDescription"] = locationDesc
        }
        
        if let coordinates = currentLocation {
            let lat = coordinates.latitude
            let lon = coordinates.longitude
            
            // Only save valid, finite coordinates
            if lat.isFinite && lon.isFinite && 
               lat >= -90 && lat <= 90 && 
               lon >= -180 && lon <= 180 {
                draftDict["latitude"] = lat
                draftDict["longitude"] = lon
            }
        }
        
        if let notes = draft.managerNotes {
            draftDict["managerNotes"] = notes
        }
        
        // Save image to documents directory instead of UserDefaults
        if let image = draft.receiptImage {
            saveReceiptImageToFile(image, draftId: draft.id)
        }
        
        // Validate that the dictionary can be property list serialized before saving
        do {
            let _ = try PropertyListSerialization.data(fromPropertyList: draftDict, format: .binary, options: 0)
            UserDefaults.standard.set(draftDict, forKey: "po_draft_\(draft.id)")
            UserDefaults.standard.set(draft.id, forKey: "current_po_draft_id")
        } catch {
            print("❌ Failed to save draft - invalid data types: \(error)")
            print("Draft data: \(draftDict)")
        }
        
        self.poIdentifier = draft.id
    }
    
    private func loadSavedDraft() -> PurchaseOrderDraft? {
        guard let draftId = UserDefaults.standard.string(forKey: "current_po_draft_id"),
              let draftDict = UserDefaults.standard.dictionary(forKey: "po_draft_\(draftId)") else {
            return nil
        }
        
        guard let jobId = draftDict["jobId"] as? String,
              let jobNumber = draftDict["jobNumber"] as? String,
              let customerName = draftDict["customerName"] as? String,
              let customerAddress = draftDict["customerAddress"] as? String,
              let vendorId = draftDict["vendorId"] as? String,
              let vendorName = draftDict["vendorName"] as? String,
              let poNumber = draftDict["poNumber"] as? String,
              let timestamp = draftDict["date"] as? TimeInterval,
              let technicianId = draftDict["technicianId"] as? String,
              let technicianName = draftDict["technicianName"] as? String else {
            return nil
        }
        
        var draft = PurchaseOrderDraft(
            jobId: jobId,
            jobNumber: jobNumber,
            customerName: customerName,
            customerAddress: customerAddress,
            vendorId: vendorId,
            vendorName: vendorName,
            poNumber: poNumber,
            date: Date(timeIntervalSince1970: timestamp),
            technicianId: technicianId,
            technicianName: technicianName
        )
        
        // Set optional properties
        if let total = draftDict["total"] as? Double {
            draft.total = total
        }
        
        draft.locationDescription = draftDict["locationDescription"] as? String
        draft.isCurrentJob = draftDict["isCurrentJob"] as? Bool ?? false
        draft.managerNotes = draftDict["managerNotes"] as? String
        
        if let latitude = draftDict["latitude"] as? Double,
           let longitude = draftDict["longitude"] as? Double {
            draft.coordinates = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        
        if let statusRaw = draftDict["status"] as? String {
            draft.status = PurchaseOrderStatus(rawValue: statusRaw) ?? .draft
        }
        
        // Load receipt image from file
        draft.receiptImage = loadReceiptImageFromFile(draftId: draftId)
        
        // Load current step
        if let stepRaw = draftDict["currentStep"] as? String,
           let step = POCreationStep(rawValue: stepRaw) {
            currentStep = step
        }
        
        return draft
    }
    
    private func clearDraft() {
        if let draft = draft {
            UserDefaults.standard.removeObject(forKey: "po_draft_\(draft.id)")
            UserDefaults.standard.removeObject(forKey: "current_po_draft_id")
            
            // Remove receipt image file
            deleteReceiptImageFile(draftId: draft.id)
            
            // Cancel any pending notifications
            UNUserNotificationCenter.current().removePendingNotificationRequests(
                withIdentifiers: [
                    "po_in_progress_\(draft.id)",
                    "po_incomplete_\(draft.id)",
                    "po_resume_\(draft.id)"
                ]
            )
        }
        
        draft = nil
        currentStep = .selectJob
        hasValidationErrors = false
        validationMessage = ""
    }
    
    // MARK: - File Management
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    private func receiptImageURL(draftId: String) -> URL {
        getDocumentsDirectory().appendingPathComponent("po_receipt_\(draftId).jpg")
    }
    
    private func saveReceiptImageToFile(_ image: UIImage, draftId: String) {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else { return }
        
        do {
            try imageData.write(to: receiptImageURL(draftId: draftId))
        } catch {
            print("Error saving receipt image: \(error)")
        }
    }
    
    private func loadReceiptImageFromFile(draftId: String) -> UIImage? {
        let url = receiptImageURL(draftId: draftId)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        
        do {
            let imageData = try Data(contentsOf: url)
            return UIImage(data: imageData)
        } catch {
            print("Error loading receipt image: \(error)")
            return nil
        }
    }
    
    private func deleteReceiptImageFile(draftId: String) {
        let url = receiptImageURL(draftId: draftId)
        try? FileManager.default.removeItem(at: url)
    }
    
    // MARK: - ServiceTitan Integration
    
    func syncWithServiceTitan(po: PurchaseOrder) {
        // Submit to ServiceTitan if connected
        if syncManager.serviceTitanService.isConnected {
            syncManager.serviceTitanService.submitPurchaseOrder(po) { [weak self] success, error in
                DispatchQueue.main.async {
                    if success {
                        po.syncWithServiceTitan(
                            poId: "ST-\(po.id)",
                            jobId: po.serviceTitanJobId,
                            jobNumber: po.serviceTitanJobNumber
                        )
                        
                        try? self?.modelContext?.save()
                    } else {
                        self?.errorMessage = "Failed to sync with ServiceTitan: \(error ?? "Unknown error")"
                    }
                }
            }
        }
    }
    
    // MARK: - Public Methods
    
    func startNewPO(technicianId: String, technicianName: String) {
        // Check if there's already a draft in progress
        if let existingDraft = loadSavedDraft() {
            draft = existingDraft
            return
        }
        
        // Create new draft
        draft = PurchaseOrderDraft(
            jobId: "",
            jobNumber: "",
            customerName: "",
            customerAddress: "",
            vendorId: "",
            vendorName: "",
            poNumber: "",
            technicianId: technicianId,
            technicianName: technicianName
        )
        
        currentStep = .selectJob
        loadAvailableJobs()
    }
    
    func selectJob(_ job: ServiceTitanJob) {
        guard var draft = draft else { return }
        
        draft.jobId = job.id
        draft.jobNumber = job.jobNumber
        draft.customerName = job.customerName
        draft.customerAddress = job.address
        draft.isCurrentJob = (job.id == currentJob?.id)
        draft.poNumber = generatePONumber(
            jobNumber: job.jobNumber,
            technicianId: draft.technicianId
        )
        
        self.draft = draft
        proceedToNextStep()
    }
    
    func selectVendor(_ vendor: AppVendor) {
        guard var draft = draft else { 
            // Create new draft if none exists - must provide all required fields
            let newDraft = PurchaseOrderDraft(
                id: UUID().uuidString,
                jobId: "", // Will be set when job is selected
                jobNumber: "",
                customerName: "",
                customerAddress: "",
                vendorId: vendor.id,
                vendorName: vendor.name,
                poNumber: "",
                technicianId: "current_tech_id", // Replace with actual ID
                technicianName: "Current Tech" // Replace with actual name
            )
            self.draft = newDraft
            recognizedVendor = vendor
            proceedToNextStep()
            return
        }
        
        // Update existing draft with vendor information
        draft.vendorId = vendor.id
        draft.vendorName = vendor.name
        self.draft = draft
        recognizedVendor = vendor
        proceedToNextStep()
    }
    
    func processReceiptImage(_ image: UIImage) {
        guard var draft = draft else { return }
        
        draft.receiptImage = image
        self.draft = draft
        
        // Process the image with receipt scanner
        Task { [weak self] in
            await self?.receiptScannerManager.processReceiptImage(image)
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                // Update draft with scanned information
                if let vendor = self.receiptScannerManager.recognizedVendor {
                    self.draft?.vendorId = vendor.id
                    self.draft?.vendorName = vendor.name
                    self.recognizedVendor = vendor
                }
                
                if let total = self.receiptScannerManager.recognizedTotal {
                    self.draft?.total = total
                    self.manualTotal = String(format: "%.2f", total)
                }
                
                self.proceedToNextStep()
            }
        }
    }
    
    func updateTotal(_ totalString: String) {
        guard var draft = draft else { return }
        
        if let total = Double(totalString), total > 0 {
            draft.total = total
            self.draft = draft
            hasValidationErrors = false
        } else {
            showValidationError("Please enter a valid amount.")
        }
    }
    
    func completePO() {
        clearDraft()
        currentStep = .complete
    }
    
    func savePurchaseOrder(userId: String, userName: String, completion: @escaping (Bool, String?) -> Void) {
        guard let draft = draft else {
            completion(false, "No purchase order data available")
            return
        }
        
        guard let modelContext = modelContext else {
            completion(false, "Database not available")
            return
        }
        
        // Convert draft to purchase order
        let purchaseOrder = draft.toPurchaseOrder(userId: userId, userName: userName)
        
        // Save to database
        do {
            modelContext.insert(purchaseOrder)
            try modelContext.save()
            
            // Sync with ServiceTitan if connected
            syncWithServiceTitan(po: purchaseOrder)
            
            // Clear the draft
            clearDraft()
            
            completion(true, "Purchase order created successfully")
        } catch {
            completion(false, "Failed to save purchase order: \(error.localizedDescription)")
        }
    }
    
    // Check for incomplete POs on app launch
    private func checkForInProgressPurchaseOrders() {
        if let savedDraft = loadSavedDraft() {
            self.draft = savedDraft
            scheduleResumeNotification()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// Location manager delegate with GPS throttling
class LocationDelegate: NSObject, CLLocationManagerDelegate {
    let onLocationUpdate: (CLLocationCoordinate2D, String) -> Void
    
    // GPS throttling properties
    private var lastReverseGeocodingTime: Date = Date.distantPast
    private var lastLocation: CLLocation?
    private let minimumTimeInterval: TimeInterval = 30.0 // 30 seconds between reverse geocoding requests
    private let minimumDistanceForReverseGeocoding: CLLocationDistance = 100.0 // 100 meters
    
    init(onLocationUpdate: @escaping (CLLocationCoordinate2D, String) -> Void) {
        self.onLocationUpdate = onLocationUpdate
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Always update the coordinate, but throttle reverse geocoding
        let shouldPerformReverseGeocoding = shouldReverseGeocode(for: location)
        
        if shouldPerformReverseGeocoding {
            performReverseGeocoding(for: location)
        } else {
            // Use cached description or generic description
            let description = "Current Location"
            onLocationUpdate(location.coordinate, description)
        }
    }
    
    private func shouldReverseGeocode(for location: CLLocation) -> Bool {
        let now = Date()
        let timeSinceLastRequest = now.timeIntervalSince(lastReverseGeocodingTime)
        
        // Check time interval
        guard timeSinceLastRequest >= minimumTimeInterval else {
            return false
        }
        
        // Check distance if we have a previous location
        if let lastLoc = lastLocation {
            let distance = location.distance(from: lastLoc)
            guard distance >= minimumDistanceForReverseGeocoding else {
                return false
            }
        }
        
        return true
    }
    
    private func performReverseGeocoding(for location: CLLocation) {
        lastReverseGeocodingTime = Date()
        lastLocation = location
        
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            if let error = error {
                print("Reverse geocoding error: \(error.localizedDescription)")
                self?.onLocationUpdate(location.coordinate, "Current Location")
                return
            }
            
            let description = placemarks?.first?.name ?? "Current Location"
            self?.onLocationUpdate(location.coordinate, description)
        }
    }
}

// Steps in the purchase order creation flow
enum POCreationStep: String, CaseIterable {
    case selectJob = "Select Job"
    case captureReceipt = "Capture Receipt"
    case verifyVendor = "Verify Vendor"
    case enterTotal = "Enter Total"
    case review = "Review"
    case managerApproval = "Manager Approval"
    case complete = "Complete"
    
    var stepNumber: Int {
        switch self {
        case .selectJob: return 1
        case .captureReceipt: return 2
        case .verifyVendor: return 3
        case .enterTotal: return 4
        case .review: return 5
        case .managerApproval: return 6
        case .complete: return 7
        }
    }
}

// Main purchase order creation view
struct PurchaseOrderCreationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AppAuthService
    
    @StateObject private var creationManager: PurchaseOrderCreationManager
    @State private var showTutorial = false
    
    init(syncManager: ServiceTitanSyncManager, modelContext: ModelContext? = nil) {
        _creationManager = StateObject(wrappedValue: PurchaseOrderCreationManager(syncManager: syncManager, modelContext: modelContext))
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Progress indicator
                ProgressView(value: progressValue, total: 5.0)
                    .padding()
                
                // Current step indicator
                Text(stepTitle)
                    .font(.headline)
                    .padding(.bottom)
                
                // Main content based on current step
                switch creationManager.currentStep {
                case .selectJob:
                    if creationManager.syncManager.serviceTitanService.isConnected {
                        JobSelectionView(jobs: creationManager.availableJobs, currentJob: creationManager.currentJob, onJobSelected: { job in
                            creationManager.selectJob(job)
                        })
                    } else {
                        GPSCustomerSelectionView(creationManager: creationManager)
                    }
                case .captureReceipt:
                    ReceiptCaptureStepView(creationManager: creationManager)
                case .verifyVendor:
                    VendorSelectionView(creationManager: creationManager)
                case .enterTotal:
                    TotalEntryView(creationManager: creationManager)
                case .review:
                    PurchaseOrderReviewView(creationManager: creationManager)
                case .managerApproval:
                    Text("Awaiting Manager Approval...")
                        .padding()
                case .complete:
                    Text("Purchase Order Complete!")
                        .padding()
                }
            }
            .navigationTitle("New Purchase Order")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button(action: {
                    showTutorial = true
                }) {
                    Image(systemName: "questionmark.circle")
                }
            )
            .alert(isPresented: $creationManager.showingAlert) {
                Alert(
                    title: Text("Error"),
                    message: Text(creationManager.errorMessage ?? "An error occurred"),
                    dismissButton: .default(Text("OK"))
                )
            }
            .onAppear {
                creationManager.syncManager.setModelContext(modelContext)
                checkFirstTimeTutorial()
            }
            .fullScreenCover(isPresented: $showTutorial) {
                PurchaseOrderTutorial(showTutorial: $showTutorial)
            }
        }
    }
    
    // Progress value for the progress bar
    private var progressValue: Double {
        switch creationManager.currentStep {
        case .selectJob: return 1.0
        case .captureReceipt: return 2.0
        case .verifyVendor: return 3.0
        case .enterTotal: return 4.0
        case .review: return 5.0
        case .managerApproval: return 6.0
        case .complete: return 7.0
        }
    }
    
    // Title for the current step
    private var stepTitle: String {
        switch creationManager.currentStep {
        case .selectJob: return "Select Job"
        case .captureReceipt: return "Capture Receipt"
        case .verifyVendor: return "Select Vendor"
        case .enterTotal: return "Enter Total"
        case .review: return "Review Purchase Order"
        case .managerApproval: return "Awaiting Approval"
        case .complete: return "Complete"
        }
    }
    
    // Check if this is first time using Purchase Orders and show tutorial
    private func checkFirstTimeTutorial() {
        // Check if user has seen the tutorial before
        let hasSeenTutorial = UserDefaults.standard.bool(forKey: "hasSeenPOTutorial")
        if !hasSeenTutorial {
            showTutorial = true
        }
    }
}

// MARK: - Enhanced Job Selection View
struct JobSelectionView: View {
    let jobs: [ServiceTitanJob]
    let currentJob: ServiceTitanJob?
    let onJobSelected: (ServiceTitanJob) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                if jobs.isEmpty {
                    ContentUnavailableView(
                        "No Jobs Available",
                        systemImage: "briefcase",
                        description: Text("No jobs found for today. Make sure you're connected to ServiceTitan and have assigned jobs.")
                    )
                } else {
                    List {
                        // Current Job Section - Highlighted in Red
                        if let current = currentJob {
                            Section {
                                CurrentJobRow(job: current) {
                                    onJobSelected(current)
                                    dismiss()
                                }
                            } header: {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                    Text("CURRENT JOB")
                                        .font(.headline)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        
                        // Other Jobs Section
                        let otherJobs = jobs.filter { $0.id != currentJob?.id }
                        if !otherJobs.isEmpty {
                            Section("Other Jobs Today") {
                                ForEach(otherJobs) { job in
                                    JobRow(job: job) {
                                        onJobSelected(job)
                                        dismiss()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Job")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// Current Job Row - Highlighted in Red
struct CurrentJobRow: View {
    let job: ServiceTitanJob
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(job.jobNumber)
                            .font(.headline)
                            .foregroundColor(.red)
                        
                        Text("CURRENT JOB")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(job.status.uppercased())
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                        
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundColor(.red)
                            .font(.title2)
                    }
                }
                
                Divider()
                    .background(Color.red.opacity(0.3))
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.red)
                            .frame(width: 16)
                        Text(job.customerName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.red)
                            .frame(width: 16)
                        Text(job.address)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .foregroundColor(.red)
                            .frame(width: 16)
                        Text(job.jobDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.red, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Regular Job Row
struct JobRow: View {
    let job: ServiceTitanJob
    let onSelect: () -> Void
    
    private var statusColor: Color {
        switch job.status.lowercased() {
        case "scheduled": return .blue
        case "in progress": return .orange
        case "completed": return .green
        default: return .gray
        }
    }
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(job.jobNumber)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(job.status.uppercased())
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(statusColor)
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right.circle")
                        .foregroundColor(.blue)
                        .font(.title2)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "person")
                            .foregroundColor(.blue)
                            .frame(width: 16)
                        Text(job.customerName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Image(systemName: "location")
                            .foregroundColor(.blue)
                            .frame(width: 16)
                        Text(job.address)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "wrench.and.screwdriver")
                            .foregroundColor(.blue)
                            .frame(width: 16)
                        Text(job.jobDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// View for selecting a vendor - Using the enhanced VendorSelectionView from VendorSelectionView.swift
// This is needed for the PurchaseOrderCreationView to reference when switching between steps

// Custom receipt capture view for creating purchase orders
struct ReceiptCaptureStepView: View {
    @ObservedObject var creationManager: PurchaseOrderCreationManager
    @State private var showingReceiptCapture = false
    
    var body: some View {
        VStack(spacing: 20) {
            if let image = creationManager.draft?.receiptImage {
                // Display the captured receipt
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                
                Text("Receipt captured successfully!")
                    .font(.headline)
                    .foregroundColor(.green)
                
                Button("Continue") {
                    creationManager.proceedToNextStep()
                }
                .padding()
                .frame(minWidth: 200)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                
                Button("Retake Photo") {
                    showingReceiptCapture = true
                }
                .padding(.top, 10)
            } else {
                // Show instructions and capture button
                VStack(spacing: 30) {
                    Image(systemName: "doc.text.viewfinder")
                        .font(.system(size: 70))
                        .foregroundColor(.blue)
                    
                    Text("Receipt Required")
                        .font(.title2)
                        .bold()
                    
                    VStack(spacing: 10) {
                        Text("A photo of the receipt is required to continue.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.primary)
                        
                        Text("Take a clear photo showing the vendor name, date, and total amount.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // Receipt capture tips
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Ensure good lighting")
                        }
                        
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Entire receipt visible in frame")
                        }
                        
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Focus on text clarity")
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    Button(action: {
                        showingReceiptCapture = true
                    }) {
                        HStack {
                            Image(systemName: "camera.fill")
                            Text("Capture Receipt")
                        }
                        .frame(minWidth: 200)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $showingReceiptCapture) {
            ReceiptCaptureView(onCapture: { image in
                creationManager.processReceiptImage(image)
            })
        }
    }
}

// Using shared CameraView from CameraComponents.swift

// View for entering total amount
struct TotalEntryView: View {
    @ObservedObject var creationManager: PurchaseOrderCreationManager
    @State private var totalText = ""
    @State private var showingAlert = false
    
    var body: some View {
        VStack {
            if let draft = creationManager.draft, let receiptImage = draft.receiptImage {
                // Receipt image
                Image(uiImage: receiptImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .cornerRadius(10)
                    .padding()
                
                // Instructions
                Text("Enter the total amount from the receipt")
                    .font(.headline)
                    .padding()
                
                // Total amount entry
                HStack {
                    Text("$")
                        .font(.title)
                    
                    TextField("Amount", text: $totalText)
                        .keyboardType(.decimalPad)
                        .font(.title)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                // Continue button
                Button("Continue") {
                    if let total = Double(totalText) {
                        creationManager.updateTotal(String(format: "%.2f", total))
                    } else {
                        showingAlert = true
                    }
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding()
                .disabled(totalText.isEmpty)
            } else {
                Text("Error: Receipt image not available")
                    .foregroundColor(.red)
            }
        }
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text("Invalid Amount"),
                message: Text("Please enter a valid number"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

// View for reviewing the purchase order
struct PurchaseOrderReviewView: View {
    @ObservedObject var creationManager: PurchaseOrderCreationManager
    @EnvironmentObject var authService: AppAuthService
    @Environment(\.dismiss) private var dismiss
    
    @State private var isSubmitting = false
    @State private var showingSuccessAlert = false
    @State private var successMessage = ""
    
    var body: some View {
        VStack {
            if let draft = creationManager.draft {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Summary header
                        Text("Purchase Order Summary")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        // PO details
                        Group {
                            PurchaseOrderDetailRow(label: "PO Number", value: draft.poNumber)
                            PurchaseOrderDetailRow(label: "Job", value: draft.jobNumber)
                            PurchaseOrderDetailRow(label: "Vendor", value: draft.vendorName)
                            PurchaseOrderDetailRow(label: "Date", value: formattedDate(draft.date))
                            
                            if let location = creationManager.locationDescription {
                                PurchaseOrderDetailRow(label: "Location", value: location)
                            }
                            
                            if let total = draft.total {
                                PurchaseOrderDetailRow(label: "Total Amount", value: "$\(String(format: "%.2f", total))")
                            }
                        }
                        .padding(.horizontal)
                        
                        Divider()
                            .padding(.vertical)
                        
                        // Receipt image
                        if let receiptImage = draft.receiptImage {
                            Text("Receipt")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            Image(uiImage: receiptImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 300)
                                .cornerRadius(10)
                                .padding()
                        }
                    }
                }
                
                Spacer()
                
                // Submit button
                Button(action: submitPurchaseOrder) {
                    if isSubmitting {
                        ProgressView()
                            .padding()
                    } else {
                        Text("Submit Purchase Order")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
                }
                .disabled(isSubmitting)
                .padding(.bottom)
            } else {
                Text("Error: Purchase order data not available")
                    .foregroundColor(.red)
            }
        }
        .alert(isPresented: $showingSuccessAlert) {
            Alert(
                title: Text("Success"),
                message: Text(successMessage),
                dismissButton: .default(Text("OK")) {
                    dismiss()
                }
            )
        }
    }
    
    private func submitPurchaseOrder() {
        isSubmitting = true
        
        // Get current user info
        guard let user = authService.currentUser else {
            creationManager.errorMessage = "User not logged in"
            creationManager.showingAlert = true
            isSubmitting = false
            return
        }
        
        // Save the purchase order
        creationManager.savePurchaseOrder(
            userId: user.id,
            userName: user.fullName ?? user.email
        ) { success, message in
            isSubmitting = false
            
            if success {
                successMessage = message ?? "Purchase order created successfully"
                showingSuccessAlert = true
            } else {
                creationManager.errorMessage = message ?? "Failed to create purchase order"
                creationManager.showingAlert = true
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// Helper view for displaying detail rows
struct PurchaseOrderDetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label + ":")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
            
            Spacer()
        }
    }
}

// MARK: - GPS-Based Customer Selection Views

struct GPSCustomerSelectionView: View {
    @ObservedObject var creationManager: PurchaseOrderCreationManager
    @State private var showingManualEntry = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Header explaining GPS mode
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.orange)
                        Text("GPS Mode")
                            .font(.headline)
                            .foregroundColor(.orange)
                    }
                    
                    Text("ServiceTitan not connected. Using GPS to detect customer locations.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
                
                if creationManager.isLookingUpAddress {
                    VStack {
                        ProgressView()
                        Text("Looking up current location...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else if creationManager.gpsCustomerLocations.isEmpty {
                    ContentUnavailableView(
                        "No Customer Locations Found",
                        systemImage: "location.slash",
                        description: Text("No previous customer locations detected. Add a customer manually or visit a customer location to start tracking.")
                    )
                    .padding()
                } else {
                    List {
                        // Current location suggestion
                        if let currentLocation = creationManager.currentLocation {
                            Section("Current Location") {
                                CurrentLocationRow(
                                    location: currentLocation,
                                    creationManager: creationManager
                                )
                            }
                        }
                        
                        // Previous customer locations
                        Section("Previous Customer Locations") {
                            ForEach(creationManager.gpsCustomerLocations) { customer in
                                GPSCustomerRow(
                                    customer: customer,
                                    currentLocation: creationManager.currentLocation,
                                    onSelect: {
                                        creationManager.createDraftFromGPSCustomer(customer)
                                    }
                                )
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 12) {
                    Button(action: {
                        creationManager.generateGPSBasedCustomerList()
                    }) {
                        HStack {
                            Image(systemName: "location.circle.fill")
                            Text("Detect Current Location")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    Button(action: {
                        showingManualEntry = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Customer Manually")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("Select Customer")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingManualEntry) {
                ManualCustomerEntryView(creationManager: creationManager)
            }
        }
    }
}

struct CurrentLocationRow: View {
    let location: CLLocationCoordinate2D
    @ObservedObject var creationManager: PurchaseOrderCreationManager
    @State private var suggestedAddress: String = "Looking up address..."
    @State private var showingCustomerNameInput = false
    @State private var customerName = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(.blue)
                Text("Current Location")
                    .font(.headline)
                Spacer()
                Text("Now")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(suggestedAddress)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(action: {
                showingCustomerNameInput = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Use This Location")
                }
                .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(8)
        .onAppear {
            creationManager.lookupAddressFromGPS(location) { address in
                suggestedAddress = address ?? "Address not found"
            }
        }
        .alert("Enter Customer Name", isPresented: $showingCustomerNameInput) {
            TextField("Customer Name", text: $customerName)
            Button("Cancel", role: .cancel) { }
            Button("Add") {
                if !customerName.isEmpty {
                    creationManager.addManualCustomerLocation(
                        customerName: customerName,
                        address: suggestedAddress
                    )
                }
            }
        }
    }
}

struct GPSCustomerRow: View {
    let customer: GPSCustomerLocation
    let currentLocation: CLLocationCoordinate2D?
    let onSelect: () -> Void
    
    private var distance: String {
        guard let currentLocation = currentLocation else { return "" }
        let dist = distanceBetween(currentLocation, customer.coordinates)
        if dist < 1000 {
            return "\(Int(dist))m away"
        } else {
            return "\(String(format: "%.1f", dist / 1000))km away"
        }
    }
    
    private var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: customer.lastVisited, relativeTo: Date())
    }
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(customer.customerName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if customer.isManuallyAdded {
                            Text("MANUALLY ADDED")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .cornerRadius(4)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(timeAgo)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if !distance.isEmpty {
                            Text(distance)
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "location")
                            .foregroundColor(.blue)
                            .frame(width: 16)
                        Text(customer.address)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.orange)
                            .frame(width: 16)
                        Text("Visited \(customer.visitCount) time\(customer.visitCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func distanceBetween(_ coord1: CLLocationCoordinate2D, _ coord2: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: coord1.latitude, longitude: coord1.longitude)
        let location2 = CLLocation(latitude: coord2.latitude, longitude: coord2.longitude)
        return location1.distance(from: location2)
    }
}

struct ManualCustomerEntryView: View {
    @ObservedObject var creationManager: PurchaseOrderCreationManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var customerName = ""
    @State private var customerAddress = ""
    @State private var useCurrentLocation = true
    
    var body: some View {
        NavigationView {
            Form {
                Section("Customer Information") {
                    TextField("Customer Name", text: $customerName)
                    TextField("Customer Address", text: $customerAddress)
                }
                
                Section("Location") {
                    Toggle("Use Current GPS Location", isOn: $useCurrentLocation)
                    
                    if useCurrentLocation {
                        if let location = creationManager.currentLocation {
                            Text("📍 \(location.latitude), \(location.longitude)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("⚠️ Current location not available")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                Section {
                    Button("Add Customer") {
                        if !customerName.isEmpty && !customerAddress.isEmpty {
                            creationManager.addManualCustomerLocation(
                                customerName: customerName,
                                address: customerAddress
                            )
                            dismiss()
                        }
                    }
                    .disabled(customerName.isEmpty || customerAddress.isEmpty || (useCurrentLocation && creationManager.currentLocation == nil))
                }
            }
            .navigationTitle("Add Customer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Enhanced Purchase Order Creation with Status Management
struct PurchaseOrderCreation: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AppAuthService
    @EnvironmentObject private var serviceTitanService: ServiceTitanService
    
    @StateObject private var poStatusManager = POStatusManager()
    @StateObject private var creationManager: PurchaseOrderCreationManager
    
    @State private var showingWarning = false
    @State private var currentPONumber: String = ""
    @State private var selectedJobAddress: String = ""
    
    init() {
        // Initialize with nil ModelContext - will be set in onAppear
        let service = ServiceTitanService(modelContext: nil)
        let syncManager = ServiceTitanSyncManager(service: service)
        _creationManager = StateObject(wrappedValue: PurchaseOrderCreationManager(syncManager: syncManager, modelContext: nil))
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Check for incomplete PO
                if poStatusManager.hasIncompletePO {
                    // Show warning and options
                    POCompletionWarningView(
                        onComplete: {
                            poStatusManager.completePO()
                            startNewPO()
                        },
                        onContinue: {
                            // Continue with existing PO
                            if let poNumber = poStatusManager.currentPONumber {
                                currentPONumber = poNumber
                            }
                        }
                    )
                } else {
                    // Normal PO creation flow
                    VStack(spacing: 20) {
                        // PO Number Display (if we have one)
                        if !currentPONumber.isEmpty {
                            EnhancedPONumberDisplay(
                                poNumber: currentPONumber,
                                jobAddress: selectedJobAddress.isEmpty ? nil : selectedJobAddress,
                                receiptsCount: poStatusManager.receiptsCount
                            )
                            .padding(.horizontal)
                        }
                        
                        // Main creation flow
                        PurchaseOrderCreationView(
                            syncManager: creationManager.syncManager,
                            modelContext: modelContext
                        )
                    }
                }
            }
            .navigationTitle("Purchase Order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if poStatusManager.hasIncompletePO {
                            showingWarning = true
                        } else {
                            dismiss()
                        }
                    }
                }
            }
        }
        .onAppear {
            creationManager.syncManager.setModelContext(modelContext)
            creationManager.setModelContext(modelContext)
            
            // Generate PO number if starting new
            if !poStatusManager.hasIncompletePO {
                generatePONumber()
            }
        }
        .alert("Incomplete Purchase Order", isPresented: $showingWarning) {
            Button("Continue Anyway", role: .destructive) {
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You have an incomplete Purchase Order. Are you sure you want to exit without completing it?")
        }
    }
    
    private func startNewPO() {
        generatePONumber()
        // Reset creation manager state
        creationManager.currentStep = .selectJob
        creationManager.draft = nil
    }
    
    private func generatePONumber() {
        Task {
            do {
                // Generate PO number using database-driven sequence
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyyMMdd"
                let dateString = dateFormatter.string(from: Date())
                
                // Get next sequence number from database
                let descriptor = FetchDescriptor<PurchaseOrder>(
                    predicate: #Predicate<PurchaseOrder> { po in
                        po.poNumber.contains(dateString)
                    },
                    sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
                )
                
                let existingPOs = try modelContext.fetch(descriptor)
                let sequenceNumber = existingPOs.count + 1
                
                // Format: JOB123-20240115-001
                let jobPrefix = selectedJobAddress.isEmpty ? "JOB" : "JOB\(selectedJobAddress.prefix(3).uppercased())"
                currentPONumber = "\(jobPrefix)-\(dateString)-\(String(format: "%03d", sequenceNumber))"
                
                // Start tracking this PO
                poStatusManager.startNewPO(
                    poNumber: currentPONumber,
                    jobAddress: selectedJobAddress
                )
                
            } catch {
                print("Error generating PO number: \(error)")
                // Fallback to simple format
                currentPONumber = "PO-\(Date().timeIntervalSince1970)"
            }
        }
    }
} 