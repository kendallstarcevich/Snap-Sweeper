
import SwiftUI
import Photos

// MARK: - Blur Scan Result Model
struct BlurryResult: Identifiable {
    let id = UUID()
    let asset: PHAsset
    let score: Double
    let image: UIImage
}

// MARK: - Main Blurry Photos Grid View
struct BlurryPhotosView: View {
    @ObservedObject var photoManager: PhotoManager
    let refreshTrigger: UUID?

    @StateObject var selectionManager = SelectionManager()

    init(photoManager: PhotoManager, refreshTrigger: UUID? = nil) {
        self.photoManager = photoManager
        self.refreshTrigger = refreshTrigger
    }

    @State private var dragLocation: CGPoint = .zero
    @State private var results: [BlurryResult] = []
    @State private var isScanning = false
    @State private var hasScanned = false
    @State private var sortMostBlurryFirst = true

    private let blurManager = BlurModelManager()
    private let imageManager = PHCachingImageManager()

    private let theme = CleanupTheme(
        accentColor: AppPalette.darkLemon,
        headerTint: AppPalette.blurryHeader,
        buttonTextColor: AppPalette.titleColor,
        title: "Blurry",
        subtitle: "You can't see it anyways... say goodbye.",
        icon: "sparkles.tv"
    )

    let columns = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4)
    ]

    var selectedResults: [BlurryResult] {
        results.filter { selectionManager.selectedAssetIDs.contains($0.asset.localIdentifier) }
    }

    var sortedResults: [BlurryResult] {
        results.sorted {
            sortMostBlurryFirst ? $0.score > $1.score : $0.score < $1.score
        }
    }

    var formattedSize: String {
        let bytes = selectedResults.reduce(Int64(0)) { sum, result in
            sum + photoManager.getSize(for: result.asset)
        }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    var body: some View {
        ZStack {
            AppPalette.pageBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        ContentView.FloatingBackButton()
                            .padding(.leading, 16)

                        ContentView.ThemedPageHeader(
                            theme: theme,
                            countText: results.isEmpty ? nil : "\(results.count) items scanned"
                        )
                        .padding(.horizontal, 16)

                        HStack {

                            Button(action: {
                                sortMostBlurryFirst.toggle()
                            }) {
                                ContentView.HeaderPillLabel(
                                    text: sortMostBlurryFirst ? "Blurry ↓" : "Sharp ↑",
                                    systemImage: "arrow.up.arrow.down",
                                    tint: theme.accentColor
                                )
                            }

                            Spacer()

                            Button(selectionManager.selectedAssetIDs.count == sortedResults.count && !sortedResults.isEmpty ? "Deselect All" : "Select All") {
                                if selectionManager.selectedAssetIDs.count == sortedResults.count {
                                    selectionManager.deselectAll()
                                } else {
                                    selectionManager.selectAll(assets: sortedResults.map { $0.asset })
                                }
                            }
                            .foregroundColor(theme.accentColor)
                            .font(.subheadline.weight(.semibold))
                        }
                        .padding(.horizontal, 16)

                        if results.isEmpty && !isScanning {
                            VStack(spacing: 14) {
                                Spacer(minLength: 80)

                                ZStack {
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .fill(theme.headerTint)
                                        .frame(width: 96, height: 96)

                                    Image(systemName: "eye.slash")
                                        .font(.system(size: 36))
                                        .foregroundColor(theme.accentColor)
                                }

                                Text(hasScanned ? "No blurry photos found in this batch" : "Tap Scan to check library photos")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                    .frame(maxWidth: .infinity)

                                Spacer(minLength: 120)
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            LazyVGrid(columns: columns, spacing: 4) {
                                ForEach(Array(sortedResults.enumerated()), id: \.element.id) { index, result in
                                    NavigationLink(
                                        destination: BlurryPhotoPagerView(
                                            results: sortedResults,
                                            startIndex: index,
                                            photoManager: photoManager,
                                            selectionManager: selectionManager
                                        )
                                    ) {
                                        BlurryThumbnail(image: result.image)
                                            .frame(minWidth: 0, maxWidth: .infinity)
                                            .aspectRatio(1, contentMode: .fill)
                                            .clipped()
                                            .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                    .background(
                                        GeometryReader { geo in
                                            Color.clear.onChange(of: dragLocation) { _, newLoc in
                                                if geo.frame(in: .global).contains(newLoc) {
                                                    selectionManager.dragSelect(id: result.asset.localIdentifier)
                                                }
                                            }
                                        }
                                    )
                                    .overlay(alignment: .bottomTrailing) {
                                        BlurScoreBadge(score: result.score)
                                    }
                                    .overlay(alignment: .topTrailing) {
                                        ContentView.SelectionToggle(id: result.asset.localIdentifier, selectionManager: selectionManager)
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.bottom, selectionManager.selectedAssetIDs.isEmpty ? 30 : 140)
                        }
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
                                for id in selectionManager.selectedAssetIDs {
                                    photoManager.toggleProtection(id: id)
                                }
                                selectionManager.deselectAll()
                            }) {
                                VStack {
                                    Image(systemName: "shield.fill")
                                    Text("Keep \(selectionManager.selectedAssetIDs.count)")
                                        .font(.caption)
                                        .bold()
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(theme.accentColor)
                                .foregroundColor(AppPalette.titleColor)
                                .cornerRadius(12)
                            }

                            Button(action: {
                                photoManager.deleteAssets(ids: selectionManager.selectedAssetIDs) { _ in
                                    results.removeAll { selectionManager.selectedAssetIDs.contains($0.asset.localIdentifier) }
                                    selectionManager.deselectAll()
                                    photoManager.blurryCount = results.filter { $0.score >= 0.75 }.count
                                }
                            }) {
                                VStack {
                                    Image(systemName: "trash.fill")
                                    Text("Delete \(selectionManager.selectedAssetIDs.count)")
                                        .font(.caption)
                                        .bold()
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(theme.accentColor)
                                .foregroundColor(AppPalette.titleColor)
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
        .navigationTitle("Blurry")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if photoManager.allPhotoAssets.isEmpty {
                photoManager.fetchAllPhotos()
            }

            if !hasScanned {
                scanPhotos()
            }
        }
        .onChange(of: refreshTrigger) { _, newValue in
            guard newValue != nil else { return }
            photoManager.fetchAllPhotos()
            scanPhotos()
        }
    }

    private func scanPhotos() {
        isScanning = true
        hasScanned = true
        results.removeAll()
        selectionManager.deselectAll()

        let assetsToScan = photoManager.allPhotoAssets

        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = true
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.resizeMode = .exact

        var scannedResults: [BlurryResult] = []

        for asset in assetsToScan {
            let targetSize = CGSize(width: 224, height: 224)

            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: requestOptions
            ) { image, _ in
                guard let image = image,
                      let score = blurManager.predictBlurScore(from: image) else {
                    return
                }

                scannedResults.append(
                    BlurryResult(asset: asset, score: score, image: image)
                )
            }
        }

        results = scannedResults.sorted { $0.score > $1.score }
        photoManager.blurryCount = scannedResults.filter { $0.score >= 0.75 }.count
        isScanning = false
    }
}

// MARK: - Full Image Pager View
struct BlurryPhotoPagerView: View {
    @State var results: [BlurryResult]
    let startIndex: Int

    @ObservedObject var photoManager: PhotoManager
    @ObservedObject var selectionManager: SelectionManager

    @State private var currentIndex: Int = 0
    @Environment(\.dismiss) private var dismiss

    private let accentColor = AppPalette.darkLemon

    var body: some View {
        ZStack {
            AppPalette.pageBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if results.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()

                        Image(systemName: "photo.slash")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)

                        Text("No more blurry photos")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Spacer()
                    }
                } else {
                    VStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 18) {
                            ContentView.FloatingBackButton()
                                .padding(.leading, 16)

                            ContentView.ThemedPageHeader(
                                theme: CleanupTheme(
                                    accentColor: AppPalette.darkLemon,
                                    headerTint: AppPalette.blurryHeader,
                                    buttonTextColor: AppPalette.titleColor,
                                    title: "Blurry Photo",
                                    subtitle: "Review the fuzzy ones before they keep eating storage.",
                                    icon: "sparkles.tv"
                                ),
                                countText: "Image \(currentIndex + 1) of \(results.count)"
                            )
                        }
                        .padding(.top, 12)

                        TabView(selection: $currentIndex) {
                            ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                                VStack(spacing: 20) {
                                    Spacer()

                                    Image(uiImage: result.image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: .infinity, maxHeight: 450)
                                        .cornerRadius(16)
                                        .padding(.horizontal)

                                    VStack(spacing: 8) {
                                        Text("Blur Score: \(result.score, specifier: "%.3f")")
                                            .font(.headline)

                                        Text("Uses \(formattedSize(for: result))")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)

                                        Text(label(for: result.score))
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }

                                    HStack(spacing: 16) {
                                        Button(action: {
                                            toggleKeep(for: result)
                                        }) {
                                            VStack {
                                                Image(systemName: isProtected(result) ? "shield.checkered" : "shield.fill")
                                                Text(isProtected(result) ? "Protected" : "Keep")
                                                    .font(.caption)
                                                    .bold()
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(accentColor)
                                            .foregroundColor(AppPalette.titleColor)
                                            .cornerRadius(12)
                                        }

                                        Button(action: {
                                            deleteCurrentPhoto(result)
                                        }) {
                                            VStack {
                                                Image(systemName: "trash.fill")
                                                Text("Delete")
                                                    .font(.caption)
                                                    .bold()
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(accentColor)
                                            .foregroundColor(AppPalette.titleColor)
                                            .cornerRadius(12)
                                        }
                                    }
                                    .padding(.horizontal)

                                    Spacer()
                                }
                                .tag(index)
                                .padding(.bottom)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .automatic))
                    }
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            currentIndex = min(startIndex, max(results.count - 1, 0))
        }
    }

    private func formattedSize(for result: BlurryResult) -> String {
        let bytes = photoManager.getSize(for: result.asset)
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func label(for score: Double) -> String {
        if score >= 0.75 {
            return "This image appears blurry"
        } else if score >= 0.50 {
            return "This image might be slightly blurry"
        } else {
            return "This image appears sharp"
        }
    }

    private func isProtected(_ result: BlurryResult) -> Bool {
        photoManager.protectedAssetIDs.contains(result.asset.localIdentifier)
    }

    private func toggleKeep(for result: BlurryResult) {
        photoManager.toggleProtection(id: result.asset.localIdentifier)
    }

    private func deleteCurrentPhoto(_ result: BlurryResult) {
        let id = result.asset.localIdentifier

        photoManager.deleteAssets(ids: [id]) { success in
            if success {
                DispatchQueue.main.async {
                    if let removeIndex = results.firstIndex(where: { $0.asset.localIdentifier == id }) {
                        results.remove(at: removeIndex)

                        if results.isEmpty {
                            dismiss()
                        } else if currentIndex >= results.count {
                            currentIndex = results.count - 1
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Thumbnail Cell
struct BlurryThumbnail: View {
    let image: UIImage

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
    }
}

// MARK: - Blur Score Badge
struct BlurScoreBadge: View {
    let score: Double

    var body: some View {
        Text(String(format: "%.2f", score))
            .font(.caption2)
            .bold()
            .foregroundColor(AppPalette.titleColor)
            .padding(6)
            .background(AppPalette.darkLemon.opacity(0.92))
            .cornerRadius(6)
            .padding(4)
    }
}
