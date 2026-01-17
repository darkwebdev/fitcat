//
//  HomeView.swift
//  FitCat
//
//  Home screen - welcome message and instructions
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 80))
                    .foregroundColor(.accentColor)

                Text("Welcome to FitCat")
                    .font(.title)
                    .fontWeight(.bold)

                VStack(spacing: 16) {
                    InstructionRow(
                        icon: "barcode.viewfinder",
                        title: "Scan Barcode",
                        description: "Point camera at barcode to search Open Pet Food Facts"
                    )

                    InstructionRow(
                        icon: "doc.text.viewfinder",
                        title: "Scan Nutrition Label",
                        description: "OCR automatically reads protein, fat, fiber, moisture, and ash"
                    )

                    InstructionRow(
                        icon: "arrow.up.circle.fill",
                        title: "Share with Community",
                        description: "New products are automatically uploaded to Open Pet Food Facts"
                    )
                }
                .padding(.horizontal)

                Spacer()

                VStack(spacing: 8) {
                    Text("Healthy cat food should have:")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 20) {
                        CarbsGoalView(label: "Ideal", value: "≤5%", color: .green)
                        CarbsGoalView(label: "Acceptable", value: "≤10%", color: .orange)
                    }
                }
                .padding()
                .background(Color(uiColor: .systemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 40)
            .navigationTitle("FitCat")
        }
    }
}

struct InstructionRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

struct CarbsGoalView: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
    }
}

#Preview {
    HomeView()
}
