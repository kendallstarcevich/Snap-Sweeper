
import SwiftUI
import Photos
import Foundation
import AVKit
import MapKit

// MARK: - Storage Models
struct StorageInfo {
    let totalBytes: Int64
    let availableBytes: Int64
    var usedBytes: Int64 { totalBytes - availableBytes }
}

class StorageManager {
    static func getStorageInfo() -> StorageInfo {
        let fileURL = URL(fileURLWithPath: NSHomeDirectory())
        do {
            let values = try fileURL.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey])
            let total = Int64(values.volumeTotalCapacity ?? 0)
            let available = values.volumeAvailableCapacityForImportantUsage ?? 0
            return StorageInfo(totalBytes: total, availableBytes: available)
        } catch {
            return StorageInfo(totalBytes: 0, availableBytes: 0)
        }
    }
}

// MARK: - App Colors
struct AppPalette {
    static let pageBackground = Color(red: 0.95, green: 0.97, blue: 1.00)
    static let softBlue = Color(red: 0.90, green: 0.94, blue: 0.99)

    static let softGreen = Color(red: 217/255, green: 244/255, blue: 205/255)
    static let darkLemon = Color(red: 245/255, green: 220/255, blue: 130/255)
    static let softPurple = Color(red: 194/255, green: 205/255, blue: 255/255)
    static let softPink = Color(red: 255/255, green: 194/255, blue: 194/255)
    static let brightBlue = Color(red: 0/255, green: 129/255, blue: 204/255)
    static let lightVideoBlue = Color(red: 95/255, green: 178/255, blue: 245/255)
    static let softMap = Color(red: 255/255, green: 217/255, blue: 194/255) // #FFD9C2

    static let screenshotHeader = Color(red: 237/255, green: 241/255, blue: 255/255)
    static let blurryHeader = Color(red: 255/255, green: 248/255, blue: 224/255)
    static let similarHeader = Color(red: 255/255, green: 236/255, blue: 236/255)
    static let videoHeader = Color(red: 232/255, green: 244/255, blue: 255/255)
    static let vaultHeader = Color(red: 240/255, green: 251/255, blue: 235/255)
    static let mapHeader = Color(red: 255/255, green: 244/255, blue: 237/255)
    static let manualHeader = Color(red: 238/255, green: 248/255, blue: 255/255)

    static let titleColor = Color(red: 0.18, green: 0.24, blue: 0.34)
}

// MARK: - Reusable Theme
struct CleanupTheme {
    let accentColor: Color
    let headerTint: Color
    let buttonTextColor: Color
    let title: String
    let subtitle: String
    let icon: String
}

// MARK: - Main App
struct ContentView: View {
    @StateObject var photoManager = PhotoManager()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeDashboardView(photoManager: photoManager)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(0)

            CleanHubView(photoManager: photoManager, selectedTab: $selectedTab)
                .tabItem {
                    Image(systemName: "sparkles.rectangle.stack.fill")
                    Text("Clean")
                }
                .tag(1)

            NavigationStack {
                ProtectedPhotosView(photoManager: photoManager, selectedTab: $selectedTab)
            }
            .tabItem {
                Image(systemName: "lock.shield.fill")
                Text("Vault")
            }
            .tag(2)
        }
        .tint(AppPalette.brightBlue)
        .onAppear {
            photoManager.requestAccessAndFetch()
            photoManager.fetchAllPhotos()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                photoManager.scanForDuplicates()
            }
        }
    }

    // MARK: - Home Card Model
    struct HomeCategoryCard: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let subtitle: String
        let buttonTitle: String
        let count: Int
        let accentColor: Color
        let buttonTextColor: Color
        let destination: AnyView
    }

    // MARK: - Shared Themes
    static var screenshotTheme: CleanupTheme {
        CleanupTheme(
            accentColor: AppPalette.softPurple,
            headerTint: AppPalette.screenshotHeader,
            buttonTextColor: .white,
            title: "Screenshots",
            subtitle: "Be honest… you don’t need these.",
            icon: "iphone"
        )
    }

    static var blurryTheme: CleanupTheme {
        CleanupTheme(
            accentColor: AppPalette.darkLemon,
            headerTint: AppPalette.blurryHeader,
            buttonTextColor: AppPalette.titleColor,
            title: "Blurry",
            subtitle: "You can't see it anyways... say goodbye.",
            icon: "sparkles.tv"
        )
    }

    static var similarTheme: CleanupTheme {
        CleanupTheme(
            accentColor: AppPalette.softPink,
            headerTint: AppPalette.similarHeader,
            buttonTextColor: .white,
            title: "Similar",
            subtitle: "Same pic. Again. Again.",
            icon: "square.on.square"
        )
    }

    static var videoTheme: CleanupTheme {
        CleanupTheme(
            accentColor: AppPalette.lightVideoBlue,
            headerTint: AppPalette.videoHeader,
            buttonTextColor: .white,
            title: "Videos",
            subtitle: "Director's cut was unnecessary.",
            icon: "video.fill"
        )
    }

    static var mapTheme: CleanupTheme {
        CleanupTheme(
            accentColor: AppPalette.softMap,
            headerTint: AppPalette.mapHeader,
            buttonTextColor: AppPalette.titleColor,
            title: "Map",
            subtitle: "Travel through your camera roll.",
            icon: "map.fill"
        )
    }

    static var manualTheme: CleanupTheme {
        CleanupTheme(
            accentColor: AppPalette.brightBlue,
            headerTint: AppPalette.manualHeader,
            buttonTextColor: .white,
            title: "All Media",
            subtitle: "Everything. No filter.",
            icon: "slider.horizontal.3"
        )
    }

    static var vaultTheme: CleanupTheme {
        CleanupTheme(
            accentColor: AppPalette.softGreen,
            headerTint: AppPalette.vaultHeader,
            buttonTextColor: AppPalette.titleColor,
            title: "Vault",
            subtitle: "Locked down. No touchy.",
            icon: "lock.shield"
        )
    }

    // MARK: - Home Dashboard
    struct HomeDashboardView: View {
        @ObservedObject var photoManager: PhotoManager
        @State private var storageInfo = StorageManager.getStorageInfo()

        let columns = [
            GridItem(.flexible(), spacing: 18),
            GridItem(.flexible(), spacing: 18)
        ]

        var homeCleanupCards: [HomeCategoryCard] {
            [
                HomeCategoryCard(
                    icon: ContentView.screenshotTheme.icon,
                    title: ContentView.screenshotTheme.title,
                    subtitle: ContentView.screenshotTheme.subtitle,
                    buttonTitle: "Review",
                    count: photoManager.screenshotCount,
                    accentColor: ContentView.screenshotTheme.accentColor,
                    buttonTextColor: ContentView.screenshotTheme.buttonTextColor,
                    destination: AnyView(ResultsView(assets: photoManager.screenshotAssets, photoManager: photoManager))
                ),
                HomeCategoryCard(
                    icon: ContentView.blurryTheme.icon,
                    title: ContentView.blurryTheme.title,
                    subtitle: ContentView.blurryTheme.subtitle,
                    buttonTitle: "Review",
                    count: photoManager.blurryCount,
                    accentColor: ContentView.blurryTheme.accentColor,
                    buttonTextColor: ContentView.blurryTheme.buttonTextColor,
                    destination: AnyView(BlurryPhotosView(photoManager: photoManager))
                ),
                HomeCategoryCard(
                    icon: ContentView.similarTheme.icon,
                    title: ContentView.similarTheme.title,
                    subtitle: ContentView.similarTheme.subtitle,
                    buttonTitle: "Compare",
                    count: photoManager.duplicateGroups.count,
                    accentColor: ContentView.similarTheme.accentColor,
                    buttonTextColor: ContentView.similarTheme.buttonTextColor,
                    destination: AnyView(DuplicatesView(photoManager: photoManager))
                ),
                HomeCategoryCard(
                    icon: ContentView.videoTheme.icon,
                    title: ContentView.videoTheme.title,
                    subtitle: ContentView.videoTheme.subtitle,
                    buttonTitle: "Review",
                    count: photoManager.videoCount,
                    accentColor: ContentView.videoTheme.accentColor,
                    buttonTextColor: ContentView.videoTheme.buttonTextColor,
                    destination: AnyView(VideoResultsView(photoManager: photoManager))
                ),
                HomeCategoryCard(
                    icon: ContentView.mapTheme.icon,
                    title: ContentView.mapTheme.title,
                    subtitle: ContentView.mapTheme.subtitle,
                    buttonTitle: "Explore",
                    count: photoManager.allPhotoAssets.filter { $0.location != nil }.count,
                    accentColor: ContentView.mapTheme.accentColor,
                    buttonTextColor: ContentView.mapTheme.buttonTextColor,
                    destination: AnyView(MapSweeperView(photoManager: photoManager))
                )
            ]
        }

        var topTwoCleanupCards: [HomeCategoryCard] {
            Array(homeCleanupCards.sorted { $0.count > $1.count }.prefix(2))
        }

        var storageTrackerCards: [HomeCategoryCard] {
            homeCleanupCards.sorted { $0.count > $1.count }
        }

        func refreshAll() {
            photoManager.requestAccessAndFetch()
            photoManager.fetchAllPhotos()
            photoManager.fetchVideos()
            photoManager.fetchAllPhotos()
            photoManager.fetchProtectedAssets()
            photoManager.scanForDuplicates()
            storageInfo = StorageManager.getStorageInfo()
        }

        var body: some View {
            NavigationStack {
                ZStack {
                    AppPalette.pageBackground
                        .ignoresSafeArea()

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 22) {
                            HStack(alignment: .center) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("SNAP SWEEP")
                                        .font(.system(size: 30, weight: .bold, design: .rounded))
                                        .foregroundColor(AppPalette.titleColor)

                                    Text("Less mess. More memories.")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Button(action: refreshAll) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(AppPalette.brightBlue)
                                        .frame(width: 44, height: 44)
                                        .background(Color.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                        .shadow(color: AppPalette.brightBlue.opacity(0.12), radius: 8, y: 4)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 2)

                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Storage Tracker")
                                            .font(.headline)
                                            .foregroundColor(AppPalette.titleColor)

                                        Text("It’s not messy… just full of potential.")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "internaldrive")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(AppPalette.brightBlue)
                                        .padding(10)
                                        .background(AppPalette.brightBlue.opacity(0.10))
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }

                                HStack(spacing: 12) {
                                    ForEach(storageTrackerCards) { card in
                                        NavigationLink(destination: card.destination) {
                                            NumberCircleBadge(
                                                number: "\(card.count)",
                                                tint: card.accentColor
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }

                                StorageGaugeView(
                                    usedBytes: storageInfo.usedBytes,
                                    totalBytes: storageInfo.totalBytes,
                                    deletedBytes: photoManager.totalBytesDeleted
                                )
                            }
                            .padding(18)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                LinearGradient(
                                    colors: [Color.white, Color(red: 0.95, green: 0.98, blue: 1.00)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .shadow(color: AppPalette.brightBlue.opacity(0.08), radius: 10, y: 4)
                            .padding(.horizontal, 20)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Start Cleaning")
                                    .font(.system(size: 26, weight: .bold, design: .rounded))
                                    .foregroundColor(AppPalette.titleColor)

                                Text("Choose your chaos.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 20)

                            LazyVGrid(columns: columns, spacing: 18) {
                                ForEach(topTwoCleanupCards) { card in
                                    NavigationLink(destination: card.destination) {
                                        CleanActionCard(
                                            icon: card.icon,
                                            title: card.title,
                                            subtitle: card.subtitle,
                                            buttonTitle: card.buttonTitle,
                                            count: card.count,
                                            accentColor: card.accentColor,
                                            buttonTextColor: card.buttonTextColor
                                        )
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 20)

                            Spacer(minLength: 24)
                        }
                        .padding(.top, 12)
                        .padding(.bottom, 90)
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(.hidden, for: .navigationBar)
                .onAppear {
                    storageInfo = StorageManager.getStorageInfo()
                    photoManager.fetchAllPhotos()
                }
            }
        }
    }

    // MARK: - Clean Hub Tab
    struct CleanHubView: View {
        @ObservedObject var photoManager: PhotoManager
        @Binding var selectedTab: Int

        let columns = [
            GridItem(.flexible(), spacing: 18),
            GridItem(.flexible(), spacing: 18)
        ]

        var body: some View {
            NavigationStack {
                ZStack {
                    AppPalette.pageBackground
                        .ignoresSafeArea()

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 22) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("CLEAN HUB")
                                    .font(.system(size: 30, weight: .bold, design: .rounded))
                                    .foregroundColor(AppPalette.titleColor)

                                Text("Pick your cleanup mission.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 8)

                            LazyVGrid(columns: columns, spacing: 18) {
                                NavigationLink(destination: ResultsView(assets: photoManager.screenshotAssets, photoManager: photoManager)) {
                                    CleanActionCard(theme: ContentView.screenshotTheme, buttonTitle: "Review", count: photoManager.screenshotCount)
                                }

                                NavigationLink(destination: BlurryPhotosView(photoManager: photoManager)) {
                                    CleanActionCard(theme: ContentView.blurryTheme, buttonTitle: "Review", count: photoManager.blurryCount)
                                }

                                NavigationLink(destination: DuplicatesView(photoManager: photoManager)) {
                                    CleanActionCard(theme: ContentView.similarTheme, buttonTitle: "Compare", count: photoManager.duplicateGroups.count)
                                }

                                NavigationLink(destination: VideoResultsView(photoManager: photoManager)) {
                                    CleanActionCard(theme: ContentView.videoTheme, buttonTitle: "Review", count: photoManager.videoCount)
                                }

                                NavigationLink(destination: MapSweeperView(photoManager: photoManager)) {
                                    CleanActionCard(theme: ContentView.mapTheme, buttonTitle: "Explore", count: photoManager.allPhotoAssets.filter { $0.location != nil }.count)
                                }

                                NavigationLink(destination: ManualReviewView(photoManager: photoManager)) {
                                    CleanActionCard(theme: ContentView.manualTheme, buttonTitle: "Open", count: photoManager.allPhotoAssets.count)
                                }

                                NavigationLink(destination: ProtectedPhotosView(photoManager: photoManager, selectedTab: $selectedTab)) {
                                    CleanActionCard(theme: ContentView.vaultTheme, buttonTitle: "Open", count: photoManager.protectedAssets.count)
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 20)

                            Spacer(minLength: 24)
                        }
                        .padding(.vertical, 12)
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .principal) { Text("") } }
                .onAppear {
                    photoManager.fetchAllPhotos()
                }
            }
        }
    }

    // MARK: - New UI Components
    struct CleanActionCard: View {
        let icon: String
        let title: String
        let subtitle: String
        let buttonTitle: String
        let count: Int
        let accentColor: Color
        let buttonTextColor: Color

        init(icon: String, title: String, subtitle: String, buttonTitle: String, count: Int, accentColor: Color, buttonTextColor: Color) {
            self.icon = icon
            self.title = title
            self.subtitle = subtitle
            self.buttonTitle = buttonTitle
            self.count = count
            self.accentColor = accentColor
            self.buttonTextColor = buttonTextColor
        }

        init(theme: CleanupTheme, buttonTitle: String, count: Int) {
            self.icon = theme.icon
            self.title = theme.title
            self.subtitle = theme.subtitle
            self.buttonTitle = buttonTitle
            self.count = count
            self.accentColor = theme.accentColor
            self.buttonTextColor = theme.buttonTextColor
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(accentColor.opacity(0.28))
                            .frame(width: 52, height: 52)

                        Image(systemName: icon)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(accentColor)
                    }

                    Spacer()

                    Text("\(count)")
                        .font(.caption.weight(.bold))
                        .foregroundColor(AppPalette.titleColor)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.85))
                        .clipShape(Capsule())
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundColor(AppPalette.titleColor)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                Text(buttonTitle)
                    .font(.caption.weight(.bold))
                    .foregroundColor(buttonTextColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: accentColor.opacity(0.12), radius: 10, y: 5)
        }
    }

    struct WideFeatureCard: View {
        let theme: CleanupTheme
        let buttonTitle: String
        let countText: String

        var body: some View {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(theme.accentColor.opacity(0.20))
                        .frame(width: 56, height: 56)

                    Image(systemName: theme.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(theme.accentColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(theme.title)
                        .font(.headline)
                        .foregroundColor(AppPalette.titleColor)

                    Text(theme.subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(countText)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(buttonTitle)
                    .font(.caption.weight(.bold))
                    .foregroundColor(theme.buttonTextColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(theme.accentColor)
                    .clipShape(Capsule())
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: theme.accentColor.opacity(0.12), radius: 10, y: 4)
        }
    }

    struct NumberCircleBadge: View {
        let number: String
        let tint: Color

        var body: some View {
            Text(number)
                .font(.caption.weight(.bold))
                .foregroundColor(AppPalette.titleColor)
                .frame(width: 42, height: 42)
                .background(tint.opacity(0.75))
                .clipShape(Circle())
        }
    }


    // MARK: - Reusable Action Page Header
    struct FloatingBackButton: View {
        @Environment(\.dismiss) private var dismiss

        var body: some View {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppPalette.titleColor)
                    .frame(width: 62, height: 62)
                    .background(Color.white.opacity(0.92))
                    .clipShape(Circle())
                    .shadow(color: AppPalette.brightBlue.opacity(0.08), radius: 10, y: 4)
            }
        }
    }

    struct ThemedPageHeader: View {
        let theme: CleanupTheme
        let countText: String?

        var body: some View {
            VStack(alignment: .leading, spacing: 20) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(theme.accentColor.opacity(0.26))
                        .frame(width: 76, height: 76)

                    Image(systemName: theme.icon)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundColor(theme.accentColor)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(theme.title)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(AppPalette.titleColor)

                    Text(theme.subtitle)
                        .font(.system(size: 19, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let countText = countText {
                        Text(countText)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(AppPalette.titleColor)
                            .padding(.top, 2)
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.headerTint)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        }
    }

    struct HeaderPillLabel: View {
        let text: String
        let systemImage: String
        let tint: Color

        var body: some View {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))

                Text(text)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
            }
            .foregroundColor(AppPalette.titleColor)
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
            .background(tint.opacity(0.16))
            .clipShape(Capsule())
        }
    }

    // 1. Keep this outside so it's accessible to the whole view
    struct PhotoAnnotation: Identifiable {
        let id = UUID()
        let assets: [PHAsset] // This now holds the whole cluster
        let coordinate: CLLocationCoordinate2D
        var count: Int { assets.count }
    }
    
    struct MapSweeperView: View {
        @ObservedObject var photoManager: PhotoManager
        @State private var startDate = Calendar.current.date(byAdding: .year, value: -10, to: Date()) ?? Date()
        @State private var endDate = Date()
        @State private var searchText = ""
        @State private var region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.0902, longitude: -95.7129),
            span: MKCoordinateSpan(latitudeDelta: 120, longitudeDelta: 120)
        )

        let theme = ContentView.mapTheme

        func performSearch(query: String) {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.region = region

            let search = MKLocalSearch(request: request)
            search.start { response, error in
                guard let item = response?.mapItems.first else { return }

                withAnimation(.easeInOut) {
                    region = MKCoordinateRegion(
                        center: item.placemark.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
                    )
                }
            }
        }

        struct LocationKey: Hashable {
            let latitude: Double
            let longitude: Double
        }

        var annotations: [PhotoAnnotation] {
            let filtered = photoManager.allPhotoAssets.filter { asset in
                guard let date = asset.creationDate else { return false }
                return date >= startDate && date <= endDate
            }

            var clusterData: [LocationKey: [PHAsset]] = [:]

            for asset in filtered {
                if let loc = asset.location {
                    let roundedLat = (loc.coordinate.latitude * 1000).rounded() / 1000
                    let roundedLon = (loc.coordinate.longitude * 1000).rounded() / 1000
                    let key = LocationKey(latitude: roundedLat, longitude: roundedLon)
                    clusterData[key, default: []].append(asset)
                }
            }

            return clusterData.map { key, assets in
                PhotoAnnotation(
                    assets: assets,
                    coordinate: CLLocationCoordinate2D(latitude: key.latitude, longitude: key.longitude)
                )
            }
        }

        var body: some View {
            ZStack {
                AppPalette.pageBackground
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        FloatingBackButton()
                            .padding(.leading, 16)

                        ThemedPageHeader(
                            theme: theme,
                            countText: "\(annotations.count) spots"
                        )
                        .padding(.horizontal, 16)

                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)

                                TextField("Search for a location...", text: $searchText)
                                    .textFieldStyle(.plain)
                                    .onSubmit { performSearch(query: searchText) }

                                if !searchText.isEmpty {
                                    Button(action: { searchText = "" }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(12)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                            HStack {
                                DatePicker("", selection: $startDate, displayedComponents: .date)
                                    .labelsHidden()

                                Text("to")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                DatePicker("", selection: $endDate, displayedComponents: .date)
                                    .labelsHidden()

                                Spacer()

                                Text("\(photoManager.allPhotoAssets.filter { $0.location != nil }.count) photos")
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(AppPalette.titleColor)
                            }
                        }
                        .padding(.horizontal, 16)

                        Map(coordinateRegion: $region, annotationItems: annotations) { annotation in
                            MapAnnotation(coordinate: annotation.coordinate) {
                                NavigationLink(destination: LocationGroupView(assets: annotation.assets, photoManager: photoManager)) {
                                    ZStack(alignment: .topTrailing) {
                                        VStack(spacing: 4) {
                                            PhotoThumbnail(asset: annotation.assets.first!)
                                                .frame(width: 45, height: 45)
                                                .clipShape(Circle())
                                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                                .shadow(radius: 3)

                                            let totalSize = annotation.assets.reduce(0) { $0 + photoManager.getSize(for: $1) }
                                            Text(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                                                .font(.system(size: 8, weight: .bold))
                                                .padding(2)
                                                .background(Color.black.opacity(0.6))
                                                .foregroundColor(.white)
                                                .cornerRadius(4)
                                        }

                                        if annotation.count > 1 {
                                            Text("\(annotation.count)")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.white)
                                                .padding(5)
                                                .background(theme.accentColor)
                                                .clipShape(Circle())
                                                .offset(x: 5, y: -5)
                                        }
                                    }
                                }
                            }
                        }
                        .frame(height: 520)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .padding(.horizontal, 16)
                        .overlay(alignment: .bottomTrailing) {
                            VStack(spacing: 12) {
                                Button(action: {
                                    withAnimation {
                                        region.span.latitudeDelta /= 4
                                        region.span.longitudeDelta /= 4
                                    }
                                }) {
                                    Image(systemName: "plus.magnifyingglass")
                                        .padding()
                                        .background(.ultraThinMaterial)
                                        .clipShape(Circle())
                                }

                                Button(action: {
                                    withAnimation {
                                        region.span.latitudeDelta = min(region.span.latitudeDelta * 4, 120)
                                        region.span.longitudeDelta = min(region.span.longitudeDelta * 4, 120)
                                    }
                                }) {
                                    Image(systemName: "minus.magnifyingglass")
                                        .padding()
                                        .background(.ultraThinMaterial)
                                        .clipShape(Circle())
                                }
                            }
                            .padding(26)
                        }
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 30)
                }
            }
            .navigationBarBackButtonHidden(true)
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { photoManager.fetchAllPhotos() }
        }
    }


    
    // MARK: - Video Results View
    struct VideoResultsView: View {
        @ObservedObject var photoManager: PhotoManager
        @StateObject var selectionManager = SelectionManager()
        @State private var dragLocation: CGPoint = .zero

        let theme = ContentView.videoTheme

        let columns = [
            GridItem(.flexible(), spacing: 4),
            GridItem(.flexible(), spacing: 4),
            GridItem(.flexible(), spacing: 4)
        ]

        var formattedSize: String {
            let selectedAssets = photoManager.videoAssets.filter {
                selectionManager.selectedAssetIDs.contains($0.localIdentifier)
            }
            let bytes = selectionManager.calculateTotalSize(assets: selectedAssets)
            return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        }

        func updateThreshold(to seconds: Double) {
            photoManager.videoThreshold = seconds
            photoManager.fetchVideos()
        }

        var body: some View {
            ZStack {
                AppPalette.pageBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 18) {
                            FloatingBackButton()
                                .padding(.leading, 16)

                            ThemedPageHeader(
                                theme: theme,
                                countText: "\(photoManager.videoAssets.count) items"
                            )
                            .padding(.horizontal, 16)

                            HStack {
                                Menu {
                                    Section("Minimum Duration") {
                                        Button("Over 30s") { updateThreshold(to: 30) }
                                        Button("Over 2m") { updateThreshold(to: 120) }
                                        Button("Over 5m") { updateThreshold(to: 300) }
                                    }
                                } label: {
                                    HeaderPillLabel(text: "Limit", systemImage: "timer", tint: theme.accentColor)
                                }

                                Menu {
                                    ForEach(PhotoManager.SortStrategy.allCases, id: \.self) { strategy in
                                        Button(strategy.rawValue) { photoManager.sortVideos(by: strategy) }
                                    }
                                } label: {
                                    HeaderPillLabel(text: "Sort", systemImage: "arrow.up.arrow.down", tint: theme.accentColor)
                                }

                                Spacer()

                                Button(selectionManager.selectedAssetIDs.count == photoManager.videoAssets.count && !photoManager.videoAssets.isEmpty ? "Deselect All" : "Select All") {
                                    if selectionManager.selectedAssetIDs.count == photoManager.videoAssets.count {
                                        selectionManager.deselectAll()
                                    } else {
                                        selectionManager.selectAll(assets: photoManager.videoAssets)
                                    }
                                }
                                .foregroundColor(theme.accentColor)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                            }
                            .padding(.horizontal, 16)

                            LazyVGrid(columns: columns, spacing: 4) {
                                ForEach(photoManager.videoAssets, id: \.localIdentifier) { asset in
                                    NavigationLink(destination: PhotoDetailView(asset: asset, photoManager: photoManager, selectionManager: selectionManager, isFromVault: false)) {
                                        PhotoThumbnail(asset: asset)
                                            .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                    .background(
                                        GeometryReader { geo in
                                            Color.clear.onChange(of: dragLocation) { _, newLoc in
                                                if geo.frame(in: .global).contains(newLoc) {
                                                    selectionManager.dragSelect(id: asset.localIdentifier)
                                                }
                                            }
                                        }
                                    )
                                    .overlay(alignment: .bottomTrailing) { VideoBadge(asset: asset) }
                                    .overlay(alignment: .topTrailing) {
                                        ContentView.SelectionToggle(id: asset.localIdentifier, selectionManager: selectionManager)
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.bottom, selectionManager.selectedAssetIDs.isEmpty ? 30 : 140)
                        }
                        .padding(.top, 12)
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 15, coordinateSpace: .global)
                            .onChanged { dragLocation = $0.location }
                            .onEnded { _ in dragLocation = .zero }
                    )

                    if !selectionManager.selectedAssetIDs.isEmpty {
                        VStack(spacing: 12) {
                            HStack(spacing: 15) {
                                Button(action: {
                                    for id in selectionManager.selectedAssetIDs { photoManager.toggleProtection(id: id) }
                                    selectionManager.deselectAll()
                                    photoManager.fetchVideos()
                                }) {
                                    VStack {
                                        Image(systemName: "shield.fill")
                                        Text("Keep \(selectionManager.selectedAssetIDs.count)").font(.caption).bold()
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(theme.accentColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }

                                Button(action: {
                                    photoManager.deleteAssets(ids: selectionManager.selectedAssetIDs) { _ in
                                        selectionManager.deselectAll()
                                        photoManager.fetchVideos()
                                    }
                                }) {
                                    VStack {
                                        Image(systemName: "trash.fill")
                                        Text("Delete \(selectionManager.selectedAssetIDs.count)").font(.caption).bold()
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(theme.accentColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                            }

                            Text("You will save \(Text(formattedSize).bold()) of space.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.white)
                        .shadow(color: theme.accentColor.opacity(0.12), radius: 10, y: -5)
                    }
                }
            }
            .navigationBarBackButtonHidden(true)
            .navigationTitle("Videos")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { photoManager.fetchVideos() }
        }
    }


    
    // MARK: - Screenshot Results View
    struct ResultsView: View {
        let assets: [PHAsset]
        @ObservedObject var photoManager: PhotoManager
        @StateObject var selectionManager = SelectionManager()
        @State private var dragLocation: CGPoint = .zero

        let theme = ContentView.screenshotTheme

        let columns = [
            GridItem(.flexible(), spacing: 4),
            GridItem(.flexible(), spacing: 4),
            GridItem(.flexible(), spacing: 4)
        ]

        var formattedSize: String {
            let selectedAssets = assets.filter {
                selectionManager.selectedAssetIDs.contains($0.localIdentifier)
            }
            let bytes = selectionManager.calculateTotalSize(assets: selectedAssets)
            return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        }

        var body: some View {
            ZStack {
                AppPalette.pageBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 18) {
                            FloatingBackButton()
                                .padding(.leading, 16)

                            ThemedPageHeader(
                                theme: theme,
                                countText: "\(assets.count) items"
                            )
                            .padding(.horizontal, 16)

                            HStack {
                                Menu {
                                    ForEach(PhotoManager.SortStrategy.allCases, id: \.self) { strategy in
                                        Button(strategy.rawValue) { photoManager.sortAssets(by: strategy) }
                                    }
                                } label: {
                                    HeaderPillLabel(text: "Sort", systemImage: "arrow.up.arrow.down", tint: theme.accentColor)
                                }

                                Spacer()

                                Button(selectionManager.selectedAssetIDs.count == assets.count && !assets.isEmpty ? "Deselect All" : "Select All") {
                                    if selectionManager.selectedAssetIDs.count == assets.count {
                                        selectionManager.deselectAll()
                                    } else {
                                        selectionManager.selectAll(assets: assets)
                                    }
                                }
                                .foregroundColor(theme.accentColor)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                            }
                            .padding(.horizontal, 16)

                            LazyVGrid(columns: columns, spacing: 4) {
                                ForEach(assets, id: \.localIdentifier) { asset in
                                    NavigationLink(destination: PhotoDetailView(asset: asset, photoManager: photoManager, selectionManager: selectionManager)) {
                                        PhotoThumbnail(asset: asset)
                                            .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                    .background(
                                        GeometryReader { geo in
                                            Color.clear.onChange(of: dragLocation) { _, newLoc in
                                                if geo.frame(in: .global).contains(newLoc) {
                                                    selectionManager.dragSelect(id: asset.localIdentifier)
                                                }
                                            }
                                        }
                                    )
                                    .overlay(alignment: .bottomTrailing) { VideoBadge(asset: asset) }
                                    .overlay(alignment: .topTrailing) {
                                        ContentView.SelectionToggle(id: asset.localIdentifier, selectionManager: selectionManager)
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.bottom, selectionManager.selectedAssetIDs.isEmpty ? 30 : 140)
                        }
                        .padding(.top, 12)
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 15, coordinateSpace: .global)
                            .onChanged { dragLocation = $0.location }
                            .onEnded { _ in dragLocation = .zero }
                    )

                    if !selectionManager.selectedAssetIDs.isEmpty {
                        VStack(spacing: 12) {
                            HStack(spacing: 15) {
                                Button(action: {
                                    for id in selectionManager.selectedAssetIDs { photoManager.toggleProtection(id: id) }
                                    selectionManager.deselectAll()
                                }) {
                                    VStack {
                                        Image(systemName: "shield.fill")
                                        Text("Keep \(selectionManager.selectedAssetIDs.count)").font(.caption).bold()
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(theme.accentColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }

                                Button(action: {
                                    photoManager.deleteAssets(ids: selectionManager.selectedAssetIDs) { _ in
                                        selectionManager.deselectAll()
                                    }
                                }) {
                                    VStack {
                                        Image(systemName: "trash.fill")
                                        Text("Delete \(selectionManager.selectedAssetIDs.count)").font(.caption).bold()
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(theme.accentColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                            }

                            Text("You will save \(Text(formattedSize).bold()) of space.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.white)
                        .shadow(color: theme.accentColor.opacity(0.12), radius: 10, y: -5)
                    }
                }
            }
            .navigationBarBackButtonHidden(true)
            .navigationTitle("Screenshots")
            .navigationBarTitleDisplayMode(.inline)
        }
    }


    
    // MARK: - Vault View
    struct VaultResultsView: View {
        let assets: [PHAsset]
        @ObservedObject var photoManager: PhotoManager
        @StateObject var selectionManager = SelectionManager()
        @State private var dragLocation: CGPoint = .zero

        let theme = ContentView.vaultTheme

        let columns = [
            GridItem(.flexible(), spacing: 4),
            GridItem(.flexible(), spacing: 4),
            GridItem(.flexible(), spacing: 4)
        ]

        var formattedSize: String {
            let selectedAssets = assets.filter {
                selectionManager.selectedAssetIDs.contains($0.localIdentifier)
            }
            let bytes = selectionManager.calculateTotalSize(assets: selectedAssets)
            return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        }

        var body: some View {
            ZStack {
                AppPalette.pageBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 18) {
                            ThemedPageHeader(
                                theme: theme,
                                countText: "\(assets.count) protected items"
                            )
                            .padding(.horizontal, 16)

                            HStack {
                                Menu {
                                    ForEach(PhotoManager.SortStrategy.allCases, id: \.self) { strategy in
                                        Button(strategy.rawValue) { photoManager.sortVault(by: strategy) }
                                    }
                                } label: {
                                    HeaderPillLabel(text: "Sort", systemImage: "arrow.up.arrow.down", tint: theme.accentColor)
                                }

                                Spacer()

                                Button(selectionManager.selectedAssetIDs.count == assets.count && !assets.isEmpty ? "Deselect All" : "Select All") {
                                    if selectionManager.selectedAssetIDs.count == assets.count {
                                        selectionManager.deselectAll()
                                    } else {
                                        selectionManager.selectAll(assets: assets)
                                    }
                                }
                                .foregroundColor(theme.accentColor)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                            }
                            .padding(.horizontal, 16)

                            LazyVGrid(columns: columns, spacing: 4) {
                                ForEach(assets, id: \.localIdentifier) { asset in
                                    NavigationLink(destination: PhotoDetailView(asset: asset, photoManager: photoManager, selectionManager: selectionManager, isFromVault: true)) {
                                        PhotoThumbnail(asset: asset)
                                            .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                    .background(
                                        GeometryReader { geo in
                                            Color.clear.onChange(of: dragLocation) { _, newLoc in
                                                if geo.frame(in: .global).contains(newLoc) {
                                                    selectionManager.dragSelect(id: asset.localIdentifier)
                                                }
                                            }
                                        }
                                    )
                                    .overlay(alignment: .bottomTrailing) { VideoBadge(asset: asset) }
                                    .overlay(alignment: .topTrailing) {
                                        ContentView.SelectionToggle(id: asset.localIdentifier, selectionManager: selectionManager)
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.bottom, selectionManager.selectedAssetIDs.isEmpty ? 30 : 140)
                        }
                        .padding(.top, 12)
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 15, coordinateSpace: .global)
                            .onChanged { dragLocation = $0.location }
                            .onEnded { _ in dragLocation = .zero }
                    )

                    if !selectionManager.selectedAssetIDs.isEmpty {
                        SummaryBar(label: "Permanently Delete \(selectionManager.selectedAssetIDs.count) Items", size: formattedSize) {
                            photoManager.deleteAssets(ids: selectionManager.selectedAssetIDs) { _ in
                                selectionManager.deselectAll()
                                photoManager.fetchProtectedAssets()
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Vault")
            .navigationBarTitleDisplayMode(.inline)
        }
    }


    struct DuplicatesView: View {
        @ObservedObject var photoManager: PhotoManager
        @State private var selectedGroupIndices = Set<Int>()

        let theme = ContentView.similarTheme

        var totalBulkSavings: Int64 {
            selectedGroupIndices.reduce(0) { sum, index in
                sum + calculatePotentialSavings(photoManager.duplicateGroups[index])
            }
        }

        var body: some View {
            ZStack {
                AppPalette.pageBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 18) {
                            FloatingBackButton()
                                .padding(.leading, 16)

                            ThemedPageHeader(
                                theme: theme,
                                countText: "\(photoManager.duplicateGroups.count) groups"
                            )
                            .padding(.horizontal, 16)

                            HStack {
                                Button(selectedGroupIndices.count == photoManager.duplicateGroups.count && !photoManager.duplicateGroups.isEmpty ? "Deselect All" : "Select All") {
                                    if selectedGroupIndices.count == photoManager.duplicateGroups.count {
                                        selectedGroupIndices.removeAll()
                                    } else {
                                        selectedGroupIndices = Set(0..<photoManager.duplicateGroups.count)
                                    }
                                }
                                .foregroundColor(theme.accentColor)
                                .font(.system(size: 17, weight: .bold, design: .rounded))

                                Spacer()
                            }
                            .padding(.horizontal, 16)

                            VStack(spacing: 12) {
                                ForEach(0..<photoManager.duplicateGroups.count, id: \.self) { index in
                                    let group = photoManager.duplicateGroups[index]
                                    let isSelected = selectedGroupIndices.contains(index)

                                    HStack(spacing: 15) {
                                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                            .font(.title2)
                                            .foregroundColor(isSelected ? theme.accentColor : .secondary)
                                            .onTapGesture {
                                                if isSelected {
                                                    selectedGroupIndices.remove(index)
                                                } else {
                                                    selectedGroupIndices.insert(index)
                                                }
                                            }

                                        NavigationLink(destination: DuplicateGroupDetailView(group: group, photoManager: photoManager)) {
                                            HStack {
                                                PhotoThumbnail(asset: group.first!)
                                                    .frame(width: 55, height: 55)
                                                    .cornerRadius(8)
                                                    .contentShape(Rectangle())

                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text("Group \(index + 1)")
                                                        .font(.headline)
                                                        .foregroundColor(AppPalette.titleColor)

                                                    Text("\(group.count) similar photos")
                                                        .font(.subheadline)
                                                        .foregroundColor(.secondary)
                                                }

                                                Spacer()

                                                Text("Save \(ByteCountFormatter.string(fromByteCount: calculatePotentialSavings(group), countStyle: .file))")
                                                    .font(.caption2)
                                                    .bold()
                                                    .padding(6)
                                                    .background(theme.accentColor.opacity(0.14))
                                                    .foregroundColor(AppPalette.titleColor)
                                                    .cornerRadius(6)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(14)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .shadow(color: theme.accentColor.opacity(0.08), radius: 8, y: 4)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, selectedGroupIndices.isEmpty ? 30 : 140)
                        }
                        .padding(.top, 12)
                    }

                    if !selectedGroupIndices.isEmpty {
                        VStack(spacing: 12) {
                            HStack(spacing: 15) {
                                Button(action: { bulkVaultGroups() }) {
                                    VStack {
                                        Image(systemName: "shield.fill")
                                        Text("Vault Groups").font(.caption).bold()
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(theme.accentColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }

                                Button(action: { bulkDeleteGroups() }) {
                                    VStack {
                                        Image(systemName: "trash.fill")
                                        Text("Delete Groups").font(.caption).bold()
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(theme.accentColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                            }

                            Text("Bulk action will save \(Text(ByteCountFormatter.string(fromByteCount: totalBulkSavings, countStyle: .file)).bold())")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.white)
                        .shadow(color: theme.accentColor.opacity(0.12), radius: 10, y: -5)
                    }
                }
            }
            .navigationBarBackButtonHidden(true)
            .navigationTitle("Similar")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                photoManager.scanForDuplicates()
            }
        }

        func calculatePotentialSavings(_ group: [PHAsset]) -> Int64 {
            guard group.count > 1 else { return 0 }
            let total = group.reduce(0) { $0 + photoManager.getSize(for: $1) }
            return total - photoManager.getSize(for: group.first!)
        }

        func bulkDeleteGroups() {
            var idsToDelete: [String] = []
            for index in selectedGroupIndices {
                let group = photoManager.duplicateGroups[index]
                let others = group.dropFirst().map { $0.localIdentifier }
                idsToDelete.append(contentsOf: others)
            }

            photoManager.deleteAssets(ids: Set(idsToDelete)) { success in
                if success {
                    selectedGroupIndices.removeAll()
                    photoManager.scanForDuplicates()
                }
            }
        }

        func bulkVaultGroups() {
            for index in selectedGroupIndices {
                let group = photoManager.duplicateGroups[index]
                for asset in group {
                    photoManager.toggleProtection(id: asset.localIdentifier)
                }
            }
            selectedGroupIndices.removeAll()
            photoManager.scanForDuplicates()
        }
    }
    

    // MARK: - Duplicate Group Detail View
    struct DuplicateGroupDetailView: View {
        let group: [PHAsset]
        @ObservedObject var photoManager: PhotoManager
        @StateObject var selectionManager = SelectionManager()
        @Environment(\.dismiss) var dismiss

        var formattedSelectionSize: String {
            let selectedAssets = group.filter {
                selectionManager.selectedAssetIDs.contains($0.localIdentifier)
            }
            let bytes = selectionManager.calculateTotalSize(assets: selectedAssets)
            return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        }

        var body: some View {
            ZStack {
                AppPalette.pageBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    TabView {
                        ForEach(group, id: \.localIdentifier) { asset in
                            VStack(spacing: 18) {
                                Spacer()

                                PhotoThumbnail(asset: asset)
                                    .aspectRatio(contentMode: .fit)
                                    .cornerRadius(16)
                                    .padding(.horizontal)

                                Text(ByteCountFormatter.string(fromByteCount: photoManager.getSize(for: asset), countStyle: .file))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.secondary)

                                Button(action: {
                                    selectionManager.toggleSelection(id: asset.localIdentifier)
                                }) {
                                    Label(
                                        selectionManager.selectedAssetIDs.contains(asset.localIdentifier) ? "Selected" : "Select to Delete",
                                        systemImage: selectionManager.selectedAssetIDs.contains(asset.localIdentifier) ? "checkmark.circle.fill" : "circle"
                                    )
                                    .font(.headline)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(selectionManager.selectedAssetIDs.contains(asset.localIdentifier) ? ContentView.similarTheme.accentColor : Color.gray.opacity(0.18))
                                    .foregroundColor(selectionManager.selectedAssetIDs.contains(asset.localIdentifier) ? .white : AppPalette.titleColor)
                                    .cornerRadius(14)
                                }
                                .padding(.horizontal, 40)

                                Spacer()
                            }
                        }
                    }
                    .tabViewStyle(.page)
                    .indexViewStyle(.page(backgroundDisplayMode: .always))

                    if !selectionManager.selectedAssetIDs.isEmpty {
                        VStack(spacing: 15) {
                            HStack(spacing: 15) {
                                Button(action: {
                                    for id in selectionManager.selectedAssetIDs {
                                        photoManager.toggleProtection(id: id)
                                    }
                                    photoManager.scanForDuplicates()
                                    dismiss()
                                }) {
                                    VStack {
                                        Image(systemName: "shield.fill")
                                        Text("Vault")
                                            .font(.caption)
                                            .bold()
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(ContentView.similarTheme.accentColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }

                                Button(action: {
                                    photoManager.deleteAssets(ids: selectionManager.selectedAssetIDs) { _ in
                                        photoManager.scanForDuplicates()
                                        dismiss()
                                    }
                                }) {
                                    VStack {
                                        Image(systemName: "trash.fill")
                                        Text("Delete")
                                            .font(.caption)
                                            .bold()
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(ContentView.similarTheme.accentColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                            }

                            Text("You will save \(Text(formattedSelectionSize).bold()) of space.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.white)
                        .shadow(color: ContentView.similarTheme.accentColor.opacity(0.12), radius: 10, y: -5)
                    }
                }
            }
            .navigationTitle("Review Similar")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if group.count > 1 {
                    for i in 1..<group.count {
                        selectionManager.selectedAssetIDs.insert(group[i].localIdentifier)
                    }
                }
            }
        }
    }

    // MARK: - Core Supporting Views
    struct SelectionToggle: View {
        let id: String
        @ObservedObject var selectionManager: SelectionManager

        var body: some View {
            Image(systemName: selectionManager.selectedAssetIDs.contains(id) ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundStyle(selectionManager.selectedAssetIDs.contains(id) ? AppPalette.brightBlue : .white)
                .shadow(radius: 3)
                .padding(8)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectionManager.toggleSelection(id: id)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
        }
    }

    struct VideoBadge: View {
        let asset: PHAsset

        var durationString: String {
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.minute, .second]
            formatter.unitsStyle = .positional
            formatter.zeroFormattingBehavior = .pad
            return formatter.string(from: asset.duration) ?? "0:00"
        }

        var body: some View {
            if asset.mediaType == .video {
                Text(durationString)
                    .font(.caption2)
                    .bold()
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(4)
                    .padding(4)
            }
        }
    }

    struct SummaryBar: View {
        let label: String
        let size: String
        let action: () -> Void

        var body: some View {
            VStack(spacing: 12) {
                Button(action: action) {
                    Text(label)
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }

                Text("You will save \(Text(size).bold()) of space.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.white)
            .shadow(color: .black.opacity(0.1), radius: 10, y: -5)
        }
    }

    struct VideoThumbnail: View {
        let asset: PHAsset

        var body: some View {
            ZStack(alignment: .bottomTrailing) {
                PhotoThumbnail(asset: asset)
                    .contentShape(Rectangle())

                VideoBadge(asset: asset)
            }
        }
    }

    struct PhotoThumbnail: View {
        let asset: PHAsset
        @State private var image: UIImage? = nil

        var body: some View {
            GeometryReader { geometry in
                Group {
                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.width)
                            .clipped()
                    } else {
                        Color.gray.opacity(0.2)
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .onAppear {
                PHImageManager.default().requestImage(
                    for: asset,
                    targetSize: CGSize(width: 400, height: 400),
                    contentMode: .aspectFill,
                    options: nil
                ) { img, _ in
                    self.image = img
                }
            }
        }
    }

    // MARK: - Manual Review View
    struct ManualReviewView: View {
        @ObservedObject var photoManager: PhotoManager
        @StateObject var selectionManager = SelectionManager()
        @State private var dragLocation: CGPoint = .zero

        @State private var selectedSort: PhotoManager.SortStrategy = .newest
        @State private var filterPhotos = true
        @State private var filterVideos = true

        let theme = ContentView.manualTheme

        let columns = [
            GridItem(.flexible(), spacing: 4),
            GridItem(.flexible(), spacing: 4),
            GridItem(.flexible(), spacing: 4)
        ]

        var processedAssets: [PHAsset] {
            var filtered = photoManager.allPhotoAssets.filter { asset in
                if asset.mediaType == .image && filterPhotos { return true }
                if asset.mediaType == .video && filterVideos { return true }
                return false
            }

            filtered = filtered.filter { !photoManager.protectedAssetIDs.contains($0.localIdentifier) }

            switch selectedSort {
            case .newest:
                return filtered.sorted { ($0.creationDate ?? Date()) > ($1.creationDate ?? Date()) }
            case .oldest:
                return filtered.sorted { ($0.creationDate ?? Date()) < ($1.creationDate ?? Date()) }
            case .largest:
                return filtered.sorted { photoManager.getSize(for: $0) > photoManager.getSize(for: $1) }
            }
        }

        var formattedSize: String {
            let selectedAssets = processedAssets.filter {
                selectionManager.selectedAssetIDs.contains($0.localIdentifier)
            }
            let bytes = selectionManager.calculateTotalSize(assets: selectedAssets)
            return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        }

        var body: some View {
            ZStack {
                AppPalette.pageBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 18) {
                            FloatingBackButton()
                                .padding(.leading, 16)

                            ThemedPageHeader(
                                theme: theme,
                                countText: "\(processedAssets.count) items"
                            )
                            .padding(.horizontal, 16)

                            VStack(spacing: 12) {
                                HStack {
                                    Text("Show:")
                                        .font(.caption)
                                        .bold()
                                        .foregroundColor(.secondary)

                                    Toggle("Photos", isOn: $filterPhotos)
                                        .toggleStyle(.button)

                                    Toggle("Videos", isOn: $filterVideos)
                                        .toggleStyle(.button)

                                    Spacer()

                                    Button(selectionManager.selectedAssetIDs.count == processedAssets.count && !processedAssets.isEmpty ? "Deselect All" : "Select All") {
                                        if selectionManager.selectedAssetIDs.count == processedAssets.count {
                                            selectionManager.deselectAll()
                                        } else {
                                            selectionManager.selectAll(assets: processedAssets)
                                        }
                                    }
                                    .foregroundColor(theme.accentColor)
                                    .font(.caption.bold())
                                }

                                Picker("Sort", selection: $selectedSort) {
                                    ForEach(PhotoManager.SortStrategy.allCases, id: \.self) { strategy in
                                        Text(strategy.rawValue).tag(strategy)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                            .padding(.horizontal, 16)

                            LazyVGrid(columns: columns, spacing: 4) {
                                ForEach(processedAssets, id: \.localIdentifier) { asset in
                                    NavigationLink(destination: PhotoDetailView(asset: asset, photoManager: photoManager, selectionManager: selectionManager)) {
                                        PhotoThumbnail(asset: asset)
                                            .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                    .background(
                                        GeometryReader { geo in
                                            Color.clear.onChange(of: dragLocation) { _, newLoc in
                                                if geo.frame(in: .global).contains(newLoc) {
                                                    selectionManager.dragSelect(id: asset.localIdentifier)
                                                }
                                            }
                                        }
                                    )
                                    .overlay(alignment: .bottomTrailing) {
                                        VideoBadge(asset: asset)
                                    }
                                    .overlay(alignment: .topTrailing) {
                                        ContentView.SelectionToggle(id: asset.localIdentifier, selectionManager: selectionManager)
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.bottom, selectionManager.selectedAssetIDs.isEmpty ? 30 : 140)
                        }
                        .padding(.top, 12)
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 15, coordinateSpace: .global)
                            .onChanged { dragLocation = $0.location }
                            .onEnded { _ in dragLocation = .zero }
                    )

                    if !selectionManager.selectedAssetIDs.isEmpty {
                        VStack(spacing: 15) {
                            HStack(spacing: 15) {
                                Button(action: {
                                    for id in selectionManager.selectedAssetIDs {
                                        photoManager.toggleProtection(id: id)
                                    }
                                    selectionManager.deselectAll()
                                    photoManager.fetchAllPhotos()
                                }) {
                                    VStack {
                                        Image(systemName: "shield.fill")
                                        Text("Keep")
                                            .font(.caption)
                                            .bold()
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(theme.accentColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }

                                Button(action: {
                                    photoManager.deleteAssets(ids: selectionManager.selectedAssetIDs) { _ in
                                        selectionManager.deselectAll()
                                        photoManager.fetchAllPhotos()
                                    }
                                }) {
                                    VStack {
                                        Image(systemName: "trash.fill")
                                        Text("Delete")
                                            .font(.caption)
                                            .bold()
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(theme.accentColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                            }

                            Text("Selected: \(selectionManager.selectedAssetIDs.count) items (\(formattedSize))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.white)
                        .shadow(color: theme.accentColor.opacity(0.12), radius: 10, y: -5)
                    }
                }
            }
            .navigationBarBackButtonHidden(true)
            .navigationTitle("All Media")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                photoManager.fetchAllPhotos()
            }
        }
    }

    // MARK: - Storage Gauge
    struct StorageGaugeView: View {
        let usedBytes: Int64
        let totalBytes: Int64
        let deletedBytes: Int64

        var usedPercentage: Double {
            totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) : 0
        }

        var clampedUsedPercentage: Double {
            min(max(usedPercentage, 0), 1)
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 16) {
                        Text("\(Int(usedPercentage * 100))%")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(AppPalette.titleColor)

                        VStack(alignment: .leading, spacing: 7) {
                            GeometryReader { geo in
                                let markerX = max(8, min(geo.size.width - 8, geo.size.width * clampedUsedPercentage))

                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    AppPalette.softGreen,
                                                    AppPalette.darkLemon,
                                                    AppPalette.softMap,
                                                    AppPalette.softPink,
                                                    AppPalette.softPurple,
                                                    AppPalette.brightBlue
                                                ],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )

                                    Circle()
                                        .fill(Color.white.opacity(0.95))
                                        .frame(width: 14, height: 14)
                                        .shadow(color: AppPalette.titleColor.opacity(0.08), radius: 2, y: 1)
                                        .offset(x: markerX - 7)
                                }
                            }
                            .frame(height: 12)

                            Text("Space is tight… we can fix that.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Cleaned so far")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(ByteCountFormatter.string(fromByteCount: deletedBytes, countStyle: .file))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(AppPalette.brightBlue.opacity(0.72))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }

                    Spacer()

                    Image(systemName: "sparkles")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundColor(AppPalette.brightBlue)
                        .frame(width: 58, height: 58)
                        .background(AppPalette.softGreen.opacity(0.75))
                        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppPalette.softBlue.opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .padding(.top, 4)
        }
    }

    struct ActionCard: View {
        let title: String
        let count: Int
        let icon: String
        let color: Color

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(count > 0 ? "\(count) items" : "Scan to start")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(15)
        }
    }

    // MARK: - Protected Photos / Vault
    struct ProtectedPhotosView: View {
        @ObservedObject var photoManager: PhotoManager
        @Binding var selectedTab: Int
        @StateObject private var authManager = AuthManager()

        var body: some View {
            Group {
                if authManager.isUnlocked {
                    VaultResultsView(assets: photoManager.protectedAssets, photoManager: photoManager)
                        .onAppear {
                            photoManager.fetchProtectedAssets()
                        }
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Lock") {
                                    authManager.lock()
                                    selectedTab = 1
                                }
                            }
                        }
                } else {
                    ZStack {
                        AppPalette.pageBackground
                            .ignoresSafeArea()

                        VStack(spacing: 22) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .fill(ContentView.vaultTheme.headerTint)
                                    .frame(width: 120, height: 120)

                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: 58, weight: .semibold))
                                    .foregroundColor(ContentView.vaultTheme.accentColor)
                            }

                            Text("Vault is Locked")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(AppPalette.titleColor)

                            Text("Use Face ID to access your protected media.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)

                            Button(action: {
                                authManager.authenticate()
                            }) {
                                Label("Unlock Vault", systemImage: "faceid")
                                    .font(.headline)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(ContentView.vaultTheme.accentColor)
                                    .foregroundColor(AppPalette.titleColor)
                                    .cornerRadius(16)
                            }
                            .padding(.horizontal, 40)
                        }
                    }
                    .onAppear {
                        authManager.authenticate()
                    }
                }
            }
        }
    }

    // MARK: - Photo Detail
    struct PhotoDetailView: View {
        let asset: PHAsset
        let photoManager: PhotoManager
        @ObservedObject var selectionManager: SelectionManager
        var isFromVault: Bool = false

        @Environment(\.dismiss) var dismiss
        @State private var fullImage: UIImage? = nil
        @State private var player: AVPlayer? = nil
        @State private var showVideoPlayer = false

        var body: some View {
            ZStack {
                AppPalette.pageBackground
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    ZStack {
                        if let img = fullImage {
                            Image(uiImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .padding()
                        } else {
                            ProgressView()
                        }

                        if asset.mediaType == .video {
                            Button(action: prepareAndPlayVideo) {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 70))
                                    .foregroundColor(.white.opacity(0.85))
                                    .shadow(radius: 10)
                            }
                        }
                    }
                    .sheet(isPresented: $showVideoPlayer) {
                        if let player = player {
                            VideoPlayer(player: player)
                                .onAppear {
                                    player.play()
                                }
                        }
                    }

                    VStack(spacing: 15) {
                        VStack(spacing: 4) {
                            Text(asset.creationDate?.formatted(date: .abbreviated, time: .shortened) ?? "Unknown Date")
                                .font(.headline)

                            Text(ByteCountFormatter.string(fromByteCount: photoManager.getSize(for: asset), countStyle: .file))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        if !isFromVault {
                            Button(action: {
                                photoManager.toggleProtection(id: asset.localIdentifier)
                                dismiss()
                            }) {
                                Label("Do Not Delete", systemImage: "shield.fill")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.green)
                                    .cornerRadius(10)
                            }
                        }

                        Button(action: {
                            selectionManager.toggleSelection(id: asset.localIdentifier)
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }) {
                            let isSelected = selectionManager.selectedAssetIDs.contains(asset.localIdentifier)
                            Label(
                                isSelected ? "Selected for Deletion" : "Mark for Deletion",
                                systemImage: isSelected ? "checkmark.circle.fill" : "circle"
                            )
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(isSelected ? Color.red : Color.gray)
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadFullImage()
            }
        }

        func loadFullImage() {
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: nil
            ) { img, _ in
                self.fullImage = img
            }
        }

        func prepareAndPlayVideo() {
            let options = PHVideoRequestOptions()
            options.deliveryMode = .automatic

            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                guard let avAsset = avAsset else { return }

                DispatchQueue.main.async {
                    self.player = AVPlayer(playerItem: AVPlayerItem(asset: avAsset))
                    self.showVideoPlayer = true
                }
            }
        }
    }

    // MARK: - Location Group View
    struct LocationGroupView: View {
        let assets: [PHAsset]
        @ObservedObject var photoManager: PhotoManager
        @StateObject var selectionManager = SelectionManager()
        @State private var dragLocation: CGPoint = .zero

        let columns = [
            GridItem(.flexible(), spacing: 4),
            GridItem(.flexible(), spacing: 4),
            GridItem(.flexible(), spacing: 4)
        ]

        var formattedSelectionSize: String {
            let selectedAssets = assets.filter {
                selectionManager.selectedAssetIDs.contains($0.localIdentifier)
            }
            let bytes = selectionManager.calculateTotalSize(assets: selectedAssets)
            return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        }

        var body: some View {
            ZStack {
                AppPalette.pageBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVGrid(columns: columns, spacing: 4) {
                            ForEach(assets, id: \.localIdentifier) { asset in
                                NavigationLink(destination: PhotoDetailView(asset: asset, photoManager: photoManager, selectionManager: selectionManager)) {
                                    PhotoThumbnail(asset: asset)
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                                .background(
                                    GeometryReader { geo in
                                        Color.clear.onChange(of: dragLocation) { _, newLoc in
                                            if geo.frame(in: .global).contains(newLoc) {
                                                selectionManager.dragSelect(id: asset.localIdentifier)
                                            }
                                        }
                                    }
                                )
                                .overlay(alignment: .bottomTrailing) {
                                    VideoBadge(asset: asset)
                                }
                                .overlay(alignment: .topTrailing) {
                                    ContentView.SelectionToggle(id: asset.localIdentifier, selectionManager: selectionManager)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        .padding(.bottom, selectionManager.selectedAssetIDs.isEmpty ? 30 : 140)
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 15, coordinateSpace: .global)
                            .onChanged { dragLocation = $0.location }
                            .onEnded { _ in dragLocation = .zero }
                    )

                    if !selectionManager.selectedAssetIDs.isEmpty {
                        VStack(spacing: 12) {
                            HStack(spacing: 15) {
                                Button(action: {
                                    for id in selectionManager.selectedAssetIDs {
                                        photoManager.toggleProtection(id: id)
                                    }
                                    selectionManager.deselectAll()
                                }) {
                                    VStack {
                                        Image(systemName: "shield.fill")
                                        Text("Keep")
                                            .font(.caption)
                                            .bold()
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(ContentView.mapTheme.accentColor)
                                    .foregroundColor(AppPalette.titleColor)
                                    .cornerRadius(12)
                                }

                                Button(action: {
                                    photoManager.deleteAssets(ids: selectionManager.selectedAssetIDs) { success in
                                        if success {
                                            selectionManager.deselectAll()
                                        }
                                    }
                                }) {
                                    VStack {
                                        Image(systemName: "trash.fill")
                                        Text("Delete")
                                            .font(.caption)
                                            .bold()
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(ContentView.mapTheme.accentColor)
                                    .foregroundColor(AppPalette.titleColor)
                                    .cornerRadius(12)
                                }
                            }

                            Text("You will save \(Text(formattedSelectionSize).bold()) of space.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.white)
                        .shadow(color: ContentView.mapTheme.accentColor.opacity(0.12), radius: 10, y: -5)
                    }
                }
            }
            .navigationTitle("Location Photos")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
