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
    @StateObject var selectionManager = SelectionManager()
    
    @State private var dragLocation: CGPoint = .zero
    @State private var results: [BlurryResult] = []
    @State private var isScanning = false
    @State private var hasScanned = false
    @State private var sortMostBlurryFirst = true
    
    private let blurManager = BlurModelManager()
    private let imageManager = PHCachingImageManager()
    
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
        VStack(spacing: 0) {
            // Top action bar
            HStack {
                Button(isScanning ? "Scanning..." : "Scan") {
                    scanPhotos()
                }
                .disabled(isScanning)
                
                Spacer()
                
                Button(action: { sortMostBlurryFirst.toggle() }) {
                    Text(sortMostBlurryFirst ? "Sort: Blurry ↓" : "Sort: Sharp ↑")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                Button(selectionManager.selectedAssetIDs.count == sortedResults.count && !sortedResults.isEmpty ? "Deselect All" : "Select All") {
                    if selectionManager.selectedAssetIDs.count == sortedResults.count {
                        selectionManager.deselectAll()
                    } else {
                        selectionManager.selectAll(assets: sortedResults.map { $0.asset })
                    }
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            
            if results.isEmpty && !isScanning {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "eye.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text(hasScanned ? "No blurry photos found" : "Tap Scan to start")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
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
                                ZStack {
                                    BlurryThumbnail(image: result.image)
                                        .frame(minWidth: 0, maxWidth: .infinity)
                                        .aspectRatio(1, contentMode: .fill)
                                        .clipped()
                                }
                                .aspectRatio(1, contentMode: .fit)
                                .cornerRadius(4)
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
                                SelectionToggle(id: result.asset.localIdentifier, selectionManager: selectionManager)
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.top, 4)
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 15, coordinateSpace: .global)
                        .onChanged { dragLocation = $0.location }
                        .onEnded { _ in dragLocation = .zero }
                )
            }
            
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
                            .frame(maxWidth: .infinity).padding().background(Color.green).foregroundColor(.white).cornerRadius(12)
                        }
                        
                        Button(action: {
                            photoManager.deleteAssets(ids: selectionManager.selectedAssetIDs) { _ in
                                results.removeAll { selectionManager.selectedAssetIDs.contains($0.asset.localIdentifier) }
                                selectionManager.deselectAll()
                            }
                        }) {
                            VStack {
                                Image(systemName: "trash.fill")
                                Text("Delete \(selectionManager.selectedAssetIDs.count)").font(.caption).bold()
                            }
                            .frame(maxWidth: .infinity).padding().background(Color.red).foregroundColor(.white).cornerRadius(12)
                        }
                    }
                    Text("You will save \(Text(formattedSize).bold()) of space.").font(.caption2).foregroundColor(.secondary)
                }
                .padding().background(Color(UIColor.systemBackground)).shadow(color: .black.opacity(0.1), radius: 10, y: -5)
            }
        }
        .navigationTitle("Blurry Photos")
        .onAppear {
            if photoManager.allPhotoAssets.isEmpty { photoManager.fetchAllPhotos() }
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
        
        var scannedResults: [BlurryResult] = []
        
        for asset in assetsToScan {
            let targetSize = CGSize(width: 224, height: 224)
            imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: requestOptions) { image, _ in
                guard let image = image, let score = blurManager.predictBlurScore(from: image) else { return }
                scannedResults.append(BlurryResult(asset: asset, score: score, image: image))
            }
        }
        
        results = scannedResults.sorted { $0.score > $1.score }
        isScanning = false
    }
}

// MARK: - Independent Subviews (Moved outside to fix errors)

struct BlurryPhotoPagerView: View {
    @State var results: [BlurryResult]
    let startIndex: Int
    @ObservedObject var photoManager: PhotoManager
    @ObservedObject var selectionManager: SelectionManager
    @State private var currentIndex: Int = 0
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            if results.isEmpty {
                Text("No more blurry photos").font(.headline).foregroundColor(.secondary)
            } else {
                TabView(selection: $currentIndex) {
                    ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                        VStack(spacing: 20) {
                            Text("Image \(index + 1) of \(results.count)").font(.subheadline).padding(.top, 12)
                            Spacer()
                            Image(uiImage: result.image).resizable().scaledToFit().frame(maxHeight: 450).cornerRadius(12).padding(.horizontal)
                            
                            VStack(spacing: 8) {
                                Text("Blur Score: \(result.score, specifier: "%.3f")").font(.headline)
                                Text("Uses \(ByteCountFormatter.string(fromByteCount: photoManager.getSize(for: result.asset), countStyle: .file))").font(.subheadline).foregroundColor(.secondary)
                            }
                            
                            HStack(spacing: 16) {
                                Button(action: { photoManager.toggleProtection(id: result.asset.localIdentifier) }) {
                                    Label(photoManager.protectedAssetIDs.contains(result.asset.localIdentifier) ? "Protected" : "Keep", systemImage: "shield.fill")
                                        .frame(maxWidth: .infinity).padding().background(Color.green).foregroundColor(.white).cornerRadius(12)
                                }
                                Button(action: { deleteCurrentPhoto(result) }) {
                                    Label("Delete", systemImage: "trash.fill")
                                        .frame(maxWidth: .infinity).padding().background(Color.red).foregroundColor(.white).cornerRadius(12)
                                }
                            }.padding(.horizontal)
                            Spacer()
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page)
            }
        }
        .onAppear { currentIndex = startIndex }
    }
    
    private func deleteCurrentPhoto(_ result: BlurryResult) {
        photoManager.deleteAssets(ids: [result.asset.localIdentifier]) { success in
            if success {
                results.removeAll { $0.asset.localIdentifier == result.asset.localIdentifier }
                if results.isEmpty { dismiss() }
            }
        }
    }
}

struct BlurryThumbnail: View {
    let image: UIImage
    var body: some View {
        Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
    }
}

struct BlurScoreBadge: View {
    let score: Double
    var body: some View {
        Text(String(format: "%.2f", score))
            .font(.caption2).bold().foregroundColor(.white).padding(4)
            .background(score >= 0.75 ? Color.red.opacity(0.8) : Color.orange.opacity(0.8))
            .cornerRadius(4).padding(4)
    }
}

struct SelectionToggle: View {
    let id: String
    @ObservedObject var selectionManager: SelectionManager
    var body: some View {
        Image(systemName: selectionManager.selectedAssetIDs.contains(id) ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 22))
            .foregroundStyle(selectionManager.selectedAssetIDs.contains(id) ? .blue : .white)
            .shadow(radius: 3).padding(8).contentShape(Rectangle())
            .onTapGesture {
                selectionManager.toggleSelection(id: id)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
    }
}
