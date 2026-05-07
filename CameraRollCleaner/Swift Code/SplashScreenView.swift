//
//  SplashScreenView.swift
//  Snap Sweeper
//
//  Created by Carla Segura on 5/6/26.
//
import SwiftUI

struct SplashScreenView: View {

    @State private var isActive = false
    @State private var scale: CGFloat = 0.85
    @State private var opacity = 0.5
    @State private var progress = 0.0
    @State private var isFloating = false
    
    var body: some View {
        if isActive {
            ContentView()
        } else {
            ZStack {
                AppPalette.pageBackground
                    .ignoresSafeArea()
                VStack {
                    Image("SnapSweeperLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 170, height: 170)
                    .offset(y: isFloating ? -6 : 6)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 38,
                            style: .continuous)
                    )
                    .shadow(
                        color: AppPalette.brightBlue.opacity(0.18),
                        radius: 12,
                        y: 6
                    )
                    Text("SNAP SWEEPER")
                        .font(
                        .system(
                            size: 34,
                            weight: .bold,
                            design: .rounded
                        )
                        )
                        .foregroundColor(AppPalette.titleColor)
                    Text("Less mess. More memories.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 8) {
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.gray.opacity(0.15))
                                .frame(width:210, height: 10)
                            
                            RoundedRectangle(cornerRadius: 10)
                                .fill(AppPalette.brightBlue)
                                .frame(width: 210 * progress, height: 10)
                        }
                        Text("Loading memories...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                }
                .scaleEffect(scale)
                .opacity(opacity)
                .onAppear {
                    withAnimation(
                        .easeInOut(duration: 2.0)
                            .repeatForever(autoreverses: true)
                    ){
                        isFloating = true
                    }
                    withAnimation(.easeInOut(duration: 1.2)) {
                            scale = 1.0
                            opacity = 1.0
                        }
                    withAnimation(.linear(duration: 2.0)) {
                        progress = 1.0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                        withAnimation {
                            isActive = true
                        }
                    }
                }
            }
        }
    }
}
