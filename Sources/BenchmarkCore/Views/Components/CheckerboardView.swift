import SwiftUI

public struct CheckerboardView: View {
    public var squareSize: CGFloat = 16.0
    public var lightColor: Color = Color(white: 0.16)
    public var darkColor: Color = Color(white: 0.11)
    
    public init(
        squareSize: CGFloat = 16.0,
        lightColor: Color = Color(white: 0.16),
        darkColor: Color = Color(white: 0.11)
    ) {
        self.squareSize = squareSize
        self.lightColor = lightColor
        self.darkColor = darkColor
    }
    
    public var body: some View {
        Canvas { context, size in
            let cols = Int(ceil(size.width / squareSize))
            let rows = Int(ceil(size.height / squareSize))
            
            // Fill background with darkColor
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(darkColor))
            
            // Draw alternating light squares
            for row in 0..<rows {
                for col in 0..<cols {
                    if (row + col) % 2 == 0 {
                        let rect = CGRect(
                            x: CGFloat(col) * squareSize,
                            y: CGFloat(row) * squareSize,
                            width: squareSize,
                            height: squareSize
                        )
                        context.fill(Path(rect), with: .color(lightColor))
                    }
                }
            }
        }
    }
}
