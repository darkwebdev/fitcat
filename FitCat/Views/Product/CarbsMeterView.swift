//
//  CarbsMeterView.swift
//  FitCat
//
//  Visual carbs meter with color coding (Green/Yellow/Red)
//

import SwiftUI

struct CarbsMeterView: View {
    let carbsPercentage: Double
    let carbsLevel: CarbsLevel

    var body: some View {
        VStack(spacing: 16) {
            // Circular meter (scaled to 20% max)
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                    .frame(width: 200, height: 200)

                // Colored arc (scaled to 20% max)
                Circle()
                    .trim(from: 0, to: min(carbsPercentage / 20.0, 1.0))
                    .stroke(
                        carbsLevel.color,
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.8), value: carbsPercentage)

                // Center content
                VStack(spacing: 8) {
                    // Cat face SVG
                    CatFaceIcon(level: carbsLevel)
                        .frame(width: 60, height: 60)

                    Text("\(carbsPercentage, specifier: "%.1f")%")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(carbsLevel.color)

                    Text("Carbs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Status indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(carbsLevel.color)
                    .frame(width: 12, height: 12)

                Text(carbsLevel.description)
                    .font(.headline)
                    .foregroundColor(carbsLevel.color)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(carbsLevel.color.opacity(0.1))
            )
        }
        .padding()
    }
}

// MARK: - Cat Face Icon
struct CatFaceIcon: View {
    let level: CarbsLevel

    var body: some View {
        Canvas { context, size in
            let width = size.width
            let height = size.height

            // Head (circle)
            let headPath = Circle().path(in: CGRect(x: width * 0.15, y: height * 0.25, width: width * 0.7, height: width * 0.7))
            context.fill(headPath, with: .color(level.color.opacity(0.2)))
            context.stroke(headPath, with: .color(level.color), lineWidth: 2)

            // Left ear (rounded triangle)
            let leftEarPath = Circle().path(in: CGRect(x: width * 0.05, y: height * 0.08, width: width * 0.25, height: width * 0.25))
            context.fill(leftEarPath, with: .color(level.color.opacity(0.2)))
            context.stroke(leftEarPath, with: .color(level.color), lineWidth: 2)

            // Right ear (rounded triangle)
            let rightEarPath = Circle().path(in: CGRect(x: width * 0.7, y: height * 0.08, width: width * 0.25, height: width * 0.25))
            context.fill(rightEarPath, with: .color(level.color.opacity(0.2)))
            context.stroke(rightEarPath, with: .color(level.color), lineWidth: 2)

            // Eyes
            let leftEye = Circle().path(in: CGRect(x: width * 0.3, y: height * 0.4, width: width * 0.08, height: width * 0.08))
            let rightEye = Circle().path(in: CGRect(x: width * 0.62, y: height * 0.4, width: width * 0.08, height: width * 0.08))
            context.fill(leftEye, with: .color(level.color))
            context.fill(rightEye, with: .color(level.color))

            // Mouth based on level
            var mouthPath = Path()
            switch level {
            case .good:
                // Happy smile (arc up)
                mouthPath.move(to: CGPoint(x: width * 0.35, y: height * 0.6))
                mouthPath.addQuadCurve(
                    to: CGPoint(x: width * 0.65, y: height * 0.6),
                    control: CGPoint(x: width * 0.5, y: height * 0.7)
                )
            case .moderate:
                // Neutral smile (slight arc)
                mouthPath.move(to: CGPoint(x: width * 0.35, y: height * 0.65))
                mouthPath.addQuadCurve(
                    to: CGPoint(x: width * 0.65, y: height * 0.65),
                    control: CGPoint(x: width * 0.5, y: height * 0.68)
                )
            case .high:
                // Sad frown (arc down)
                mouthPath.move(to: CGPoint(x: width * 0.35, y: height * 0.7))
                mouthPath.addQuadCurve(
                    to: CGPoint(x: width * 0.65, y: height * 0.7),
                    control: CGPoint(x: width * 0.5, y: height * 0.6)
                )
            }
            context.stroke(mouthPath, with: .color(level.color), lineWidth: 2)

            // Nose (small triangle)
            var nose = Path()
            nose.move(to: CGPoint(x: width * 0.5, y: height * 0.52))
            nose.addLine(to: CGPoint(x: width * 0.47, y: height * 0.58))
            nose.addLine(to: CGPoint(x: width * 0.53, y: height * 0.58))
            nose.closeSubpath()
            context.fill(nose, with: .color(level.color))

            // Whiskers
            // Left whiskers
            var leftWhisker1 = Path()
            leftWhisker1.move(to: CGPoint(x: width * 0.28, y: height * 0.55))
            leftWhisker1.addLine(to: CGPoint(x: width * 0.05, y: height * 0.5))
            context.stroke(leftWhisker1, with: .color(level.color), lineWidth: 1.5)

            var leftWhisker2 = Path()
            leftWhisker2.move(to: CGPoint(x: width * 0.28, y: height * 0.6))
            leftWhisker2.addLine(to: CGPoint(x: width * 0.05, y: height * 0.6))
            context.stroke(leftWhisker2, with: .color(level.color), lineWidth: 1.5)

            var leftWhisker3 = Path()
            leftWhisker3.move(to: CGPoint(x: width * 0.28, y: height * 0.65))
            leftWhisker3.addLine(to: CGPoint(x: width * 0.05, y: height * 0.68))
            context.stroke(leftWhisker3, with: .color(level.color), lineWidth: 1.5)

            // Right whiskers
            var rightWhisker1 = Path()
            rightWhisker1.move(to: CGPoint(x: width * 0.72, y: height * 0.55))
            rightWhisker1.addLine(to: CGPoint(x: width * 0.95, y: height * 0.5))
            context.stroke(rightWhisker1, with: .color(level.color), lineWidth: 1.5)

            var rightWhisker2 = Path()
            rightWhisker2.move(to: CGPoint(x: width * 0.72, y: height * 0.6))
            rightWhisker2.addLine(to: CGPoint(x: width * 0.95, y: height * 0.6))
            context.stroke(rightWhisker2, with: .color(level.color), lineWidth: 1.5)

            var rightWhisker3 = Path()
            rightWhisker3.move(to: CGPoint(x: width * 0.72, y: height * 0.65))
            rightWhisker3.addLine(to: CGPoint(x: width * 0.95, y: height * 0.68))
            context.stroke(rightWhisker3, with: .color(level.color), lineWidth: 1.5)
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        CarbsMeterView(carbsPercentage: 3.33, carbsLevel: .good)
        CarbsMeterView(carbsPercentage: 7.5, carbsLevel: .moderate)
        CarbsMeterView(carbsPercentage: 23.33, carbsLevel: .high)
    }
}
