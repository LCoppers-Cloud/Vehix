import SwiftUI

/// A reusable component for displaying a label-value pair in a detail view
public struct DetailRow: View {
    var label: String
    var value: String
    var icon: String? = nil
    var iconColor: Color? = nil
    
    public init(label: String, value: String, icon: String? = nil, iconColor: Color? = nil) {
        self.label = label
        self.value = value
        self.icon = icon
        self.iconColor = iconColor
    }
    
    public var body: some View {
        HStack(alignment: .top) {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundColor(iconColor ?? .secondary)
                    .frame(width: 20, alignment: .center)
                    .padding(.trailing, 4)
            }
            
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 4)
    }
} 