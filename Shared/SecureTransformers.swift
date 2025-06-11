import Foundation
import CoreLocation

// MARK: - IntArrayTransformer
@objc(IntArrayTransformer)
public final class IntArrayTransformer: NSSecureUnarchiveFromDataTransformer {
    
    public static let name = NSValueTransformerName(rawValue: String(describing: IntArrayTransformer.self))
    
    public override static var allowedTopLevelClasses: [AnyClass] {
        return [NSArray.self, NSNumber.self]
    }
    
    public static func register() {
        let transformer = IntArrayTransformer()
        ValueTransformer.setValueTransformer(transformer, forName: name)
    }
}

// MARK: - StringArrayTransformer
@objc(StringArrayTransformer)
public final class StringArrayTransformer: NSSecureUnarchiveFromDataTransformer {
    
    public static let name = NSValueTransformerName(rawValue: String(describing: StringArrayTransformer.self))
    
    public override static var allowedTopLevelClasses: [AnyClass] {
        return [NSArray.self, NSString.self]
    }
    
    public static func register() {
        let transformer = StringArrayTransformer()
        ValueTransformer.setValueTransformer(transformer, forName: name)
    }
}

// MARK: - CLLocationCoordinate2DTransformer
@objc(CLLocationCoordinate2DTransformer)
public final class CLLocationCoordinate2DTransformer: NSSecureUnarchiveFromDataTransformer {
    
    public static let name = NSValueTransformerName(rawValue: String(describing: CLLocationCoordinate2DTransformer.self))
    
    public override static var allowedTopLevelClasses: [AnyClass] {
        return [NSDictionary.self, NSNumber.self, NSString.self]
    }
    
    public override func transformedValue(_ value: Any?) -> Any? {
        guard let coordinate = value as? CLLocationCoordinate2D else { return nil }
        
        let dict: [String: Double] = [
            "latitude": coordinate.latitude,
            "longitude": coordinate.longitude
        ]
        
        return try? NSKeyedArchiver.archivedData(withRootObject: dict, requiringSecureCoding: true)
    }
    
    public override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else { return nil }
        
        do {
            let dict = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSDictionary.self, from: data) as? [String: Double]
            guard let latitude = dict?["latitude"], let longitude = dict?["longitude"] else {
                return nil
            }
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        } catch {
            print("Error transforming CLLocationCoordinate2D: \(error)")
            return nil
        }
    }
    
    public static func register() {
        let transformer = CLLocationCoordinate2DTransformer()
        ValueTransformer.setValueTransformer(transformer, forName: name)
    }
}

// MARK: - ExtendedDataTransformer
@objc(ExtendedDataTransformer)
public final class ExtendedDataTransformer: NSSecureUnarchiveFromDataTransformer {
    
    public static let name = NSValueTransformerName(rawValue: String(describing: ExtendedDataTransformer.self))
    
    public override static var allowedTopLevelClasses: [AnyClass] {
        return [NSDictionary.self, NSArray.self, NSString.self, NSNumber.self, NSDate.self, NSData.self]
    }
    
    public static func register() {
        let transformer = ExtendedDataTransformer()
        ValueTransformer.setValueTransformer(transformer, forName: name)
    }
} 