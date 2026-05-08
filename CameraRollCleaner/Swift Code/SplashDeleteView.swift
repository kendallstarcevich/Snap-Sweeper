//
//  SplashDeleteView.swift
//  Snap Sweeper
//
//  Created by Carla Segura on 5/7/26.
//

import SwiftUI
struct SplashDeleteView: View {
    let deletedCount: Int
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 34))
                .foregroundColor(AppPalette.brightBlue)
            Text("Sweep Complete")
                .font(.headline.bold())
            Text("\(deletedCount) items removed")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 24)
        .background(.ultraThinMaterial)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
        )
        .shadow(
            color: AppPalette.brightBlue.opacity(0.18),
            radius: 16,
            y: 8
        )
        .transition(.scale.combined(with: .opacity))
    }
}
