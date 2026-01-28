//
//  FoodCanOverlay.swift
//  FitCat
//
//  Semi-transparent food can outline with barcode overlay for camera view
//

import SwiftUI

struct FoodCanOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            let canWidth = min(geometry.size.width * 0.6, 200.0)
            let canHeight = canWidth * 1.5
            let verticalOffset = -geometry.size.height * 0.1

            // Corner guides (like a camera viewfinder)
            ZStack {
                // Top left
                CornerGuide()
                    .frame(width: canWidth * 0.2, height: canWidth * 0.2)
                    .position(x: (geometry.size.width - canWidth) / 2,
                            y: (geometry.size.height - canHeight) / 2 + verticalOffset)

                // Top right
                CornerGuide()
                    .rotation3DEffect(.degrees(90), axis: (x: 0, y: 0, z: 1))
                    .frame(width: canWidth * 0.2, height: canWidth * 0.2)
                    .position(x: (geometry.size.width + canWidth) / 2,
                            y: (geometry.size.height - canHeight) / 2 + verticalOffset)

                // Bottom left
                CornerGuide()
                    .rotation3DEffect(.degrees(-90), axis: (x: 0, y: 0, z: 1))
                    .frame(width: canWidth * 0.2, height: canWidth * 0.2)
                    .position(x: (geometry.size.width - canWidth) / 2,
                            y: (geometry.size.height + canHeight) / 2 + verticalOffset)

                // Bottom right
                CornerGuide()
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 0, z: 1))
                    .frame(width: canWidth * 0.2, height: canWidth * 0.2)
                    .position(x: (geometry.size.width + canWidth) / 2,
                            y: (geometry.size.height + canHeight) / 2 + verticalOffset)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .allowsHitTesting(false)
    }
}

struct CornerGuide: View {
    var body: some View {
        GeometryReader { geometry in
            let lineWidth: CGFloat = 3
            let cornerRadius: CGFloat = 24

            Path { path in
                // Start at top-left corner (with rounded inner corner)
                path.move(to: CGPoint(x: 0, y: cornerRadius))

                // Arc for inner rounded corner
                path.addArc(
                    center: CGPoint(x: cornerRadius, y: cornerRadius),
                    radius: cornerRadius,
                    startAngle: .degrees(180),
                    endAngle: .degrees(270),
                    clockwise: false
                )

                // Top horizontal line
                path.addLine(to: CGPoint(x: geometry.size.width, y: 0))
                path.addLine(to: CGPoint(x: geometry.size.width, y: lineWidth))
                path.addLine(to: CGPoint(x: cornerRadius, y: lineWidth))

                // Inner arc for thickness
                path.addArc(
                    center: CGPoint(x: cornerRadius, y: cornerRadius),
                    radius: cornerRadius - lineWidth,
                    startAngle: .degrees(270),
                    endAngle: .degrees(180),
                    clockwise: true
                )

                // Left vertical line
                path.addLine(to: CGPoint(x: lineWidth, y: geometry.size.height))
                path.addLine(to: CGPoint(x: 0, y: geometry.size.height))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [.white.opacity(0.9), .white.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }
}

#Preview {
    ZStack {
        Color.black
        FoodCanOverlay()
    }
}
