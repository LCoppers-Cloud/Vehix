import Foundation
import SwiftData

// This typealias is ONLY defined in ModelConfiguration.swift
// DO NOT UNCOMMENT THIS - it would cause duplicate declarations
// typealias AppVendor = Vehix.Vendor

// Extension to add Vendor model to the Vehix namespace if not already defined
extension Vehix {
    // If the Vendor model isn't defined in VehicleModels.swift, uncomment this:
    /*
    @Model
    final class Vendor {
        var id: String = UUID().uuidString
        var name: String = ""
        var email: String = ""
        var phone: String?
        var address: String?
        var isActive: Bool = true
        var serviceTitanId: String?
        var syncedWithServiceTitan: Bool = false
        var createdAt: Date = Date()
        var updatedAt: Date = Date()
        
        init(
            id: String = UUID().uuidString,
            name: String,
            email: String,
            phone: String? = nil,
            address: String? = nil,
            isActive: Bool = true,
            serviceTitanId: String? = nil,
            syncedWithServiceTitan: Bool = false
        ) {
            self.id = id
            self.name = name
            self.email = email
            self.phone = phone
            self.address = address
            self.isActive = isActive
            self.serviceTitanId = serviceTitanId
            self.syncedWithServiceTitan = syncedWithServiceTitan
            self.createdAt = Date()
            self.updatedAt = Date()
        }
    }
    */
}

/*
HOW TO USE THIS NAMESPACE:

1. In your view files with Vendor ambiguity errors, use the AppVendor typealias:

   // Change from:
   @Query var vendors: [Vendor]
   
   // To:
   @Query var vendors: [AppVendor]

2. For function parameters and return types:

   // Change from:
   func processVendor(_ vendor: Vendor) -> Vendor
   
   // To:
   func processVendor(_ vendor: AppVendor) -> AppVendor

3. For createing new instances:

   // Change from:
   let vendor = Vendor(name: "Acme Supplies", email: "info@acme.com")
   
   // To:
   let vendor = AppVendor(name: "Acme Supplies", email: "info@acme.com")

This approach allows us to progressively migrate the app while maintaining 
compatibility with existing code.
*/ 