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
    let apiCarbsPercentage: Double?
    let apiCarbsLevel: CarbsLevel?

    init(carbsPercentage: Double, carbsLevel: CarbsLevel, apiCarbsPercentage: Double? = nil, apiCarbsLevel: CarbsLevel? = nil) {
        self.carbsPercentage = carbsPercentage
        self.carbsLevel = carbsLevel
        self.apiCarbsPercentage = apiCarbsPercentage
        self.apiCarbsLevel = apiCarbsLevel
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header with Carbs label
            HStack {
                Text("Carbs")
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .trailing)

                Spacer()
            }
            .padding(.horizontal)

            VStack(spacing: 16) {
                // Linear progress bars
                VStack(spacing: 8) {
                // API meter (if available and different)
                if let apiCarbs = apiCarbsPercentage, let apiLevel = apiCarbsLevel, abs(carbsPercentage - apiCarbs) > 0.1 {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 20)
                                .cornerRadius(10)

                            // API value with correct color
                            Rectangle()
                                .fill(apiLevel.color)
                                .frame(width: geometry.size.width * min(apiCarbs / 20.0, 1.0), height: 20)
                                .cornerRadius(10)
                                .animation(.easeInOut(duration: 0.8), value: apiCarbs)
                        }
                    }
                    .frame(height: 20)
                    .padding(.horizontal)

                    // API status
                    HStack(spacing: 8) {
                        Image(systemName: "cloud")
                            .font(.caption)
                            .foregroundColor(apiLevel.color)

                        Text("\(apiLevel.description) • \(apiCarbs > 20 ? "> 20" : String(format: "%.1f", apiCarbs))%")
                            .font(.headline)
                            .foregroundColor(apiLevel.color)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(apiLevel.color.opacity(0.1))
                    )

                    // Vertical arrow
                    Image(systemName: "arrow.down")
                        .foregroundColor(.green)
                        .fontWeight(.bold)

                    // Scanned meter
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 20)
                                .cornerRadius(10)

                            // Scanned value
                            Rectangle()
                                .fill(carbsLevel.color)
                                .frame(width: geometry.size.width * min(carbsPercentage / 20.0, 1.0), height: 20)
                                .cornerRadius(10)
                                .animation(.easeInOut(duration: 0.8), value: carbsPercentage)
                        }
                    }
                    .frame(height: 20)
                    .padding(.horizontal)
                } else {
                    // Single meter
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 20)
                                .cornerRadius(10)

                            // Scanned value
                            Rectangle()
                                .fill(carbsLevel.color)
                                .frame(width: geometry.size.width * min(carbsPercentage / 20.0, 1.0), height: 20)
                                .cornerRadius(10)
                                .animation(.easeInOut(duration: 0.8), value: carbsPercentage)
                        }
                    }
                    .frame(height: 20)
                    .padding(.horizontal)
                }

                // Scanned status
                HStack(spacing: 8) {
                    Image(systemName: "camera")
                        .font(.caption)
                        .foregroundColor(carbsLevel.color)

                    Text("\(carbsLevel.description) • \(carbsPercentage > 20 ? "> 20" : String(format: "%.1f", carbsPercentage))%")
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
            }
            .padding()
            .background(Color(uiColor: .systemGray6))
            .cornerRadius(12)
        }
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
