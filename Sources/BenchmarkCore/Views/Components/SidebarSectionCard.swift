import SwiftUI

public struct SidebarSectionCard<Content: View>: View {
    public let title: String
    public let systemImage: String
    @ViewBuilder public let content: () -> Content
    
    public init(
        title: String,
        systemImage: String,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.content = content
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(hex: "#60A5FA"))
                
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.white)
                
                Spacer()
            }
            .padding(.bottom, 2)
            
            content()
        }
        .padding(12)
        .background(Color(white: 0.12))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
