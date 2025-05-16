import Foundation
import SwiftData

@Model
final class VehicleAssignment: Identifiable {
    @Attribute(.unique) var id: String
    var vehicleId: String
    var userId: String
    var startDate: Date
    var endDate: Date? // nil = currently assigned
    var createdAt: Date
    var updatedAt: Date
    
    // Relationships (optional, for convenience)
    @Relationship(deleteRule: .nullify) var vehicle: AppVehicle?
    @Relationship(deleteRule: .nullify) var user: AuthUser?
    
    init(
        id: String = UUID().uuidString,
        vehicleId: String,
        userId: String,
        startDate: Date = Date(),
        endDate: Date? = nil,
        vehicle: AppVehicle? = nil,
        user: AuthUser? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.vehicleId = vehicleId
        self.userId = userId
        self.startDate = startDate
        self.endDate = endDate
        self.vehicle = vehicle
        self.user = user
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
} 