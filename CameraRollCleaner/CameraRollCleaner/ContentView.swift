import SwiftUI
import Photos

struct ContentView: View {
    @StateObject var photoManager = PhotoManager()

    var body: some View {
        NavigationStack {
            VStack(spacing: 25) {
                Text("AI Photo Cleaner")
                    .font(.largeTitle).bold()
                
                HStack(spacing: 40) {
                    StatView(label: "Total", value: photoManager.photoCount)
                    StatView(label: "Screenshots", value: photoManager.screenshotCount, color: .red)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(15)

                if !photoManager.isAuthorized {
                    Button("Grant Library Access") {
                        photoManager.requestAccessAndFetch()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    NavigationLink(destination: ResultsView(assets: photoManager.screenshotAssets)) {
                        Text("Review \(photoManager.screenshotCount) Screenshots")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
            }
            .padding()
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        photoManager.requestAccessAndFetch()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views
struct StatView: View {
    var label: String
    var value: Int
    var color: Color = .primary
    
    var body: some View {
        VStack {
            Text("\(value)")
                .font(.title).bold()
                .foregroundColor(color)
            Text(label)
                .font(.caption)
        }
    }
}

struct ResultsView: View {
    let assets: [PHAsset]
    @StateObject var selectionManager = SelectionManager()
    
    let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header with Selection Controls
            HStack {
                Text("\(selectionManager.selectedAssetIDs.count) selected")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Button(selectionManager.selectedAssetIDs.count == assets.count ? "Deselect All" : "Select All") {
                    if selectionManager.selectedAssetIDs.count == assets.count {
                        selectionManager.deselectAll()
                    } else {
                        selectionManager.selectAll(assets: assets)
                    }
                }
                .font(.subheadline)
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))

            ScrollView {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(assets, id: \.localIdentifier) { asset in
                        ZStack(alignment: .topTrailing) {
                            // 1. THE MAIN LINK (Tapping photo opens detail)
                            NavigationLink(destination: PhotoDetailView(asset: asset)) {
                                PhotoThumbnail(asset: asset)
                                    .frame(minWidth: 0, maxWidth: .infinity)
                                    .aspectRatio(1, contentMode: .fill)
                                    .frame(height: 120)
                                    .clipped()
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)

                            // 2. THE SELECTION OVERLAY (Tapping icon selects)
                            Button(action: {
                                selectionManager.toggleSelection(id: asset.localIdentifier)
                            }) {
                                Image(systemName: selectionManager.selectedAssetIDs.contains(asset.localIdentifier) ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 24))
                                    .foregroundStyle(selectionManager.selectedAssetIDs.contains(asset.localIdentifier) ? .blue : .white)
                                    .shadow(radius: 2)
                                    .padding(8)
                            }
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
            
            // The Big Delete Button
            if !selectionManager.selectedAssetIDs.isEmpty {
                Button(action: {
                    print("Deleting \(selectionManager.selectedAssetIDs.count) photos...")
                    // Later: photoManager.deleteSelectedPhotos(ids: selectionManager.selectedAssetIDs)
                }) {
                    Text("Delete Selected Photos")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding()
                .transition(.move(edge: .bottom))
            }
        }
        .navigationTitle("Clean Up")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectionManager.selectAll(assets: assets)
        }
    }
}

struct PhotoThumbnail: View {
    let asset: PHAsset
    @State private var image: UIImage? = nil
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.gray.opacity(0.2)
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    func loadImage() {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        
        manager.requestImage(for: asset,
                             targetSize: CGSize(width: 250, height: 250),
                             contentMode: .aspectFill,
                             options: options) { result, _ in
            self.image = result
        }
    }
}

struct PhotoDetailView: View {
    let asset: PHAsset
    @State private var fullImage: UIImage? = nil
    
    var body: some View {
        VStack {
            if let img = fullImage {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding()
            } else {
                ProgressView("Loading high-res...")
            }
        }
        .navigationTitle("Preview")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadFullImage()
        }
    }
    
    func loadFullImage() {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        
        manager.requestImage(for: asset,
                             targetSize: PHImageManagerMaximumSize,
                             contentMode: .aspectFit,
                             options: options) { result, _ in
            self.fullImage = result
        }
    }
}

#Preview {
    ContentView()
}
