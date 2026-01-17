//
//  MainView.swift
//  FitCat
//
//  Root navigation view
//

import SwiftUI

struct MainView: View {
    @State private var scannerResetTrigger = 0

    var body: some View {
        ScannerView(resetTrigger: $scannerResetTrigger)
    }
}

#Preview {
    MainView()
}
