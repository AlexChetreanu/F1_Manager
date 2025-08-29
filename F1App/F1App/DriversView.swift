//
//  DriversView.swift
//  F1App
//
//  Created by Alexandru Chetreanu
//

import SwiftUI

struct DriversView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Lista piloților")
                    .titleL()
                    .foregroundStyle(AppColors.textPri)
                    .padding()
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.bg)
            .navigationTitle("Piloți")
            .navigationBarTitleDisplayMode(.inline)
            .background(AppColors.bg.ignoresSafeArea())
        }
    }
}
