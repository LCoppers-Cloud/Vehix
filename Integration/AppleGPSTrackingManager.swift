import Foundation
import CoreLocation
import SwiftData
import UserNotifications
import MapKit

/// Manages Apple GPS tracking for vehicles when Samsara is not available
@MainActor
class AppleGPSTrackingManager: NSObject, ObservableObject {
    
    // Singleton instance
    static let shared = AppleGPSTrackingManager()
    @Published var isTracking = false
    @Published var currentLocation: CLLocation?
    @Published var totalDistance: Double = 0.0 // in meters
    @Published var currentSpeed: Double = 0.0 // in m/s
    @Published var trackingStartTime: Date?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    // Legal compliance properties
    @Published var hasUserConsent: Bool = false
    @Published var isWithinWorkHours: Bool = false
    @Published var trackingReason: String = ""
    
    private let locationManager = CLLocationManager()
    private var modelContext: ModelContext?
    private var lastLocation: CLLocation?
    private var currentVehicle: Vehix.Vehicle?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    
    // Tracking settings
    private let minimumDistanceFilter: Double = 10.0 // meters
    private let minimumTimeInterval: TimeInterval = 30.0 // seconds
    private let significantSpeedThreshold: Double = 2.0 // m/s (about 4.5 mph)
    
    private var trackingSession: VehicleTrackingSession?
    private var consentRecord: GPSConsentRecord?
    private var workHoursConfig: WorkHoursConfiguration?
    private var isSetupComplete = false
    
    private override init() {
        super.init()
        // Don't setup location manager immediately - wait for explicit call
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    func setCurrentVehicle(_ vehicle: Vehix.Vehicle) {
        self.currentVehicle = vehicle
    }
    
    // MARK: - Location Manager Setup
    
    func setupLocationManagerIfNeeded() {
        guard !isSetupComplete else { return }
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = minimumDistanceFilter
        
        // Don't request authorization automatically - let the user initiate
        authorizationStatus = locationManager.authorizationStatus
        isSetupComplete = true
    }
    
    // MARK: - Tracking Control
    
    func startTracking(for vehicle: Vehix.Vehicle) {
        // Setup location manager if not already done
        setupLocationManagerIfNeeded()
        
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            requestLocationPermission()
            return
        }
        
        guard !isTracking else { return }
        
        currentVehicle = vehicle
        trackingStartTime = Date()
        totalDistance = 0.0
        lastLocation = nil
        
        locationManager.startUpdatingLocation()
        isTracking = true
        
        print("Started GPS tracking for vehicle: \(vehicle.displayName)")
        
        // Send notification to user
        sendTrackingNotification(message: "GPS tracking started for \(vehicle.displayName)")
    }
    
    func stopTracking() {
        guard isTracking else { return }
        
        locationManager.stopUpdatingLocation()
        isTracking = false
        
        trackingStartTime = nil
        currentVehicle = nil
        
        print("Stopped GPS tracking")
        
        // Send notification to user
        sendTrackingNotification(message: "GPS tracking stopped. Distance: \(formatDistance(totalDistance))")
    }
    
    func pauseTracking() {
        guard isTracking else { return }
        locationManager.stopUpdatingLocation()
    }
    
    func resumeTracking() {
        guard isTracking else { return }
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else { return }
        
        locationManager.startUpdatingLocation()
    }
    
    // MARK: - Background Task Management
    
    private func startBackgroundTask() {
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "VehicleGPSTracking") {
            self.endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }
    
    // MARK: - Location Processing
    
    private func processLocationUpdate(_ location: CLLocation) {
        guard let lastLoc = lastLocation else {
            lastLocation = location
            return
        }
        
        // Calculate distance from last location
        let distance = location.distance(from: lastLoc)
        
        // Only process if significant movement
        guard distance >= minimumDistanceFilter else { return }
        
        // Calculate time interval
        let timeInterval = location.timestamp.timeIntervalSince(lastLoc.timestamp)
        
        // Only process if enough time has passed
        guard timeInterval >= minimumTimeInterval else { return }
        
        // Calculate speed
        let speed = distance / timeInterval
        
        // Only add to total distance if moving at reasonable speed
        if speed >= significantSpeedThreshold {
                          totalDistance += distance
              currentSpeed = speed
              
              // Add location point with legal compliance verification
              addLocationPointWithCompliance(location, distance: distance)
              
              // Update vehicle mileage periodically
            updateVehicleMileage()
        }
        
        lastLocation = location
        currentLocation = location
    }
    
    private func updateVehicleMileage() {
        guard let modelContext = modelContext,
              let vehicle = currentVehicle else { return }
        
        do {
            // Find the vehicle
            let vehicleId = vehicle.id
            let vehicleDescriptor = FetchDescriptor<Vehix.Vehicle>(
                predicate: #Predicate<Vehix.Vehicle> { $0.id == vehicleId }
            )
            
            if let vehicle = try modelContext.fetch(vehicleDescriptor).first {
                // Convert meters to miles and add to vehicle mileage
                let milesAdded = Int(totalDistance * 0.000621371) // meters to miles
                
                if milesAdded > 0 {
                    vehicle.mileage += milesAdded
                    vehicle.lastLocationUpdateDate = Date()
                    vehicle.lastKnownLocation = getCurrentLocationDescription()
                    vehicle.updatedAt = Date()
                    
                    try modelContext.save()
                    
                    // Reset total distance to avoid double counting
                    totalDistance = 0.0
                }
            }
        } catch {
            print("Error updating vehicle mileage: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func calculateAverageSpeed() -> Double {
        guard let startTime = trackingStartTime else { return 0.0 }
        
        let totalTime = Date().timeIntervalSince(startTime)
        guard totalTime > 0 else { return 0.0 }
        
        return totalDistance / totalTime
    }
    
    private func getCurrentLocationDescription() -> String? {
        guard let location = currentLocation else { return nil }
        
        let geocoder = CLGeocoder()
        var locationDescription: String?
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let placemark = placemarks?.first {
                var components: [String] = []
                
                if let city = placemark.locality {
                    components.append(city)
                }
                if let state = placemark.administrativeArea {
                    components.append(state)
                }
                
                locationDescription = components.joined(separator: ", ")
            }
        }
        
        return locationDescription
    }
    
    private func formatDistance(_ meters: Double) -> String {
        let miles = meters * 0.000621371
        return String(format: "%.1f miles", miles)
    }
    
    private func sendTrackingNotification(message: String) {
        let content = UNMutableNotificationContent()
        content.title = "Vehicle Tracking"
        content.body = message
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "vehicle.tracking.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send tracking notification: \(error)")
            }
        }
    }
    
    // MARK: - Public Interface
    
    func requestLocationPermission() {
        setupLocationManagerIfNeeded()
        locationManager.requestWhenInUseAuthorization()
    }
    
    func requestAlwaysLocationPermission() {
        setupLocationManagerIfNeeded()
        locationManager.requestAlwaysAuthorization()
    }
    
    func getCurrentLocationString() -> String {
        guard let location = currentLocation else { return "Location unavailable" }
        
        return String(format: "%.6f, %.6f", location.coordinate.latitude, location.coordinate.longitude)
    }
    
    func getTrackingStatusString() -> String {
        if isTracking {
            let duration = trackingStartTime?.timeIntervalSinceNow ?? 0
            let hours = Int(abs(duration)) / 3600
            let minutes = (Int(abs(duration)) % 3600) / 60
            
            return "Tracking: \(hours)h \(minutes)m • \(formatDistance(totalDistance))"
        } else {
            return "Not tracking"
        }
    }
    
    // MARK: - Private Methods
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    private func calculateDistance(from: CLLocation, to: CLLocation) -> Double {
        return from.distance(from: to)
    }
    
    private func sendLowFuelNotification() {
        guard isTracking else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Vehicle Tracking"
        content.body = "Long trip detected. Consider checking fuel level."
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "low-fuel-warning",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send notification: \(error)")
            }
        }
    }
    
    private func sendSpeedingAlert(speed: Double) {
        guard isTracking else { return }
        
        let kmh = speed * 3.6
        guard kmh > 120 else { return } // Alert if over 120 km/h
        
        let content = UNMutableNotificationContent()
        content.title = "Speed Alert"
        content.body = "Current speed: \(String(format: "%.1f", kmh)) km/h. Please drive safely."
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "speed-alert-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send speed alert: \(error)")
            }
        }
    }
    
    // MARK: - Legal Compliance Methods
    
    /// Check and verify all legal requirements before starting GPS tracking
    func verifyLegalComplianceForTracking(userId: String, businessPurpose: String) async -> Bool {
        guard let context = modelContext else { return false }
        
        // Check user consent
        await checkUserConsent(userId: userId, context: context)
        
        // Check work hours configuration
        await loadWorkHoursConfiguration(userId: userId, context: context)
        
        // Verify current time is within work hours
        updateWorkHoursStatus()
        
        // Set tracking reason
        trackingReason = businessPurpose
        
        // Return true only if all legal requirements are met
        return hasUserConsent && isWithinWorkHours && !businessPurpose.isEmpty
    }
    
    /// Request GPS consent from user with business purpose
    func requestGPSConsent(userId: String, businessPurpose: String) async -> Bool {
        guard let context = modelContext else { return false }
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                // In a real app, this would show a consent dialog
                // For now, we'll create a consent record
                let consent = GPSConsentRecord(
                    userId: userId,
                    businessPurpose: businessPurpose
                )
                consent.giveConsent()
                
                context.insert(consent)
                try? context.save()
                
                self.consentRecord = consent
                self.hasUserConsent = true
                
                continuation.resume(returning: true)
            }
        }
    }
    
    /// Revoke GPS consent
    func revokeGPSConsent() {
        guard let consent = consentRecord else { return }
        
        consent.revokeConsent()
        hasUserConsent = false
        
        // Stop tracking immediately if running
        if isTracking {
            stopTracking()
        }
        
        try? modelContext?.save()
    }
    
    private func checkUserConsent(userId: String, context: ModelContext) async {
        let descriptor = FetchDescriptor<GPSConsentRecord>(
            predicate: #Predicate<GPSConsentRecord> { record in
                record.userId == userId && record.isActive == true
            }
        )
        
        do {
            let consents = try context.fetch(descriptor)
            if let activeConsent = consents.first(where: { $0.hasValidConsent }) {
                consentRecord = activeConsent
                hasUserConsent = true
            } else {
                hasUserConsent = false
            }
        } catch {
            print("Error fetching consent records: \(error)")
            hasUserConsent = false
        }
    }
    
    private func loadWorkHoursConfiguration(userId: String, context: ModelContext) async {
        let descriptor = FetchDescriptor<WorkHoursConfiguration>(
            predicate: #Predicate<WorkHoursConfiguration> { config in
                config.userId == userId && config.isActive == true
            }
        )
        
        do {
            let configs = try context.fetch(descriptor)
            workHoursConfig = configs.first
        } catch {
            print("Error fetching work hours configuration: \(error)")
            // Create default configuration
            let defaultConfig = WorkHoursConfiguration(userId: userId)
            context.insert(defaultConfig)
            try? context.save()
            workHoursConfig = defaultConfig
        }
    }
    
    private func updateWorkHoursStatus() {
        if let config = workHoursConfig {
            isWithinWorkHours = config.isWithinWorkHours()
        } else {
            // Default work hours check
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: Date())
            let weekday = calendar.component(.weekday, from: Date())
            
            // Monday-Friday, 6 AM to 8 PM
            let isWorkDay = weekday >= 2 && weekday <= 6
            let isWorkHour = hour >= 6 && hour <= 20
            
            isWithinWorkHours = isWorkDay && isWorkHour
        }
    }
    
    /// Start GPS tracking with legal compliance verification
    func startTrackingWithCompliance(for vehicle: Vehix.Vehicle, userId: String, businessPurpose: String) async -> Bool {
        // Verify legal compliance first
        let isCompliant = await verifyLegalComplianceForTracking(userId: userId, businessPurpose: businessPurpose)
        
        guard isCompliant else {
            print("GPS tracking denied: Legal compliance requirements not met")
            return false
        }
        
        // Proceed with tracking
        startTracking(for: vehicle)
        
        // Create tracking session with compliance data
        if let context = modelContext {
            trackingSession = VehicleTrackingSession(
                vehicleId: vehicle.id,
                userId: userId,
                startTime: Date(),
                userConsent: hasUserConsent,
                businessPurpose: businessPurpose
            )
            context.insert(trackingSession!)
            try? context.save()
        }
        
        return true
    }
    
    /// Enhanced stop tracking with session finalization
    func stopTrackingWithCompliance() {
        // Finalize tracking session
        if let session = trackingSession {
            session.endTime = Date()
            if let currentLocation = currentLocation {
                session.setEndLocation(currentLocation)
            }
            session.totalDistance = totalDistance
            
            if let startTime = trackingStartTime {
                let duration = Date().timeIntervalSince(startTime)
                session.averageSpeed = duration > 0 ? totalDistance / duration : 0.0
            }
            
            try? modelContext?.save()
        }
        
        trackingSession = nil
        stopTracking()
    }
    
    /// Add location point with legal compliance verification
    private func addLocationPointWithCompliance(_ location: CLLocation, distance: Double) {
        guard let session = trackingSession,
              hasUserConsent,
              isWithinWorkHours else {
            // Stop tracking if compliance requirements are no longer met
            stopTrackingWithCompliance()
            return
        }
        
        session.addLocationPoint(location, distance: distance)
        try? modelContext?.save()
    }
    
    /// Check if GPS tracking is legally allowed for current user and time
    func canTrackLegally() -> Bool {
        return hasUserConsent && isWithinWorkHours && !trackingReason.isEmpty
    }
    
    /// Get compliance status summary
    func getComplianceStatus() -> (consent: Bool, workHours: Bool, reason: String) {
        return (hasUserConsent, isWithinWorkHours, trackingReason)
    }
}

// MARK: - CLLocationManagerDelegate

extension AppleGPSTrackingManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        Task { @MainActor in
            currentLocation = location
            currentSpeed = max(0, location.speed) // Ensure non-negative speed
            
            // Calculate distance if we have a previous location
            if let lastLoc = lastLocation {
                let distance = calculateDistance(from: lastLoc, to: location)
                totalDistance += distance
                
                // Check for speeding (optional alert)
                if location.speed > 0 {
                    sendSpeedingAlert(speed: location.speed)
                }
            }
            
            lastLocation = location
            
            // Send notification for long trips (every 50km)
            if totalDistance > 0 && Int(totalDistance) % 50000 == 0 {
                sendLowFuelNotification()
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            print("Location manager failed with error: \(error.localizedDescription)")
            
            // Handle specific errors
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    authorizationStatus = .denied
                case .locationUnknown:
                    // Continue trying to get location
                    break
                case .network:
                    // Network error, might be temporary
                    break
                default:
                    break
                }
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            authorizationStatus = status
            
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                // Permission granted, can start tracking if requested
                break
            case .denied, .restricted:
                // Permission denied, stop tracking
                if isTracking {
                    stopTracking()
                }
            case .notDetermined:
                // Permission not yet requested
                break
            @unknown default:
                break
            }
        }
    }
}

// MARK: - Vehicle Tracking Session Model (DEPRECATED)
// NOTE: VehicleTrackingSession and VehicleTrackingPoint models have been removed
// as they are not included in the production schema and were causing duplicate
// version checksum errors. GPS tracking functionality should be refactored to use
// a different approach or added to the main schema if needed. 