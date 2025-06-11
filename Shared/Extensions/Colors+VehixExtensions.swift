import SwiftUI

extension Color {
    // Additional Vehix colors not defined in assets
    static var vehixText: Color {
        return Color.primary
    }
    
    static var vehixSecondaryText: Color {
        return Color.secondary
    }
    
    static var vehixBackground: Color {
        return Color(.systemBackground)
    }
    
    static var vehixSecondaryBackground: Color {
        return Color(.secondarySystemBackground)
    }
    
    // UI color variants
    static var vehixUIBlue: Color {
        return Color("vehix-ui-blue") 
    }
    
    static var vehixUIGreen: Color {
        return Color("vehix-ui-green")
    }
    
    static var vehixUIOrange: Color {
        return Color("vehix-ui-orange")
    }
    
    static var vehixUIYellow: Color {
        return Color("vehix-ui-yellow")
    }
} 