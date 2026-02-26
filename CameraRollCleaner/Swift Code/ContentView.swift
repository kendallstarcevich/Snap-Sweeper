import SwiftUI
import Photos
import Foundation

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

// MARK: - Main Dashboard
struct ContentView: View {
    @StateObject var photoManager = PhotoManager()
    @State private var storageInfo = StorageManager.getStorageInfo()

    let actionColumns = [
        GridItem(.flexible(), spacing: 15),
        GridItem(.flexible(), spacing: 15)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 25) {
                    
                    StorageGaugeView(
                        usedBytes: storageInfo.usedBytes,
                        totalBytes: storageInfo.totalBytes,
                        deletedBytes: photoManager.totalBytesDeleted
                    )
                    .padding(.top)
                    
                    NavigationLink(destination: ProtectedPhotosView(photoManager: photoManager)) {
                            HStack {
                                Image(systemName: "shield.checkered")
                                    .foregroundColor(.green)
                                Text("Protected Vault")
                                    .fontWeight(.semibold)
                                Spacer()
                                Text("\(photoManager.protectedAssetIDs.count) items")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 15) {
                        Text("Smart Clean Actions")
                            .font(.title2).bold()
                        
                        LazyVGrid(columns: actionColumns, spacing: 15) {
                            
                            NavigationLink(destination: ResultsView(assets: photoManager.screenshotAssets, photoManager: photoManager)) {
                                ActionCard(
                                    title: "Screenshots",
                                    count: photoManager.screenshotCount,
                                    icon: "iphone.gen1",
                                    color: .blue
                                )
                            }
                
                            
                            NavigationLink(destination: Text("Blurry Scan Coming Soon")) {
                                ActionCard(
                                    title: "Blurry Photos",
                                    count: 0,
                                    icon: "eye.slash.fill",
                                    color: .orange
                                )
                            }
                            
                            NavigationLink(destination: Text("Duplicate Scan Coming Soon")) {
                                ActionCard(
                                    title: "Duplicates",
                                    count: 0,
                                    icon: "square.on.square.fill",
                                    color: .purple
                                )
                            }
                            
                            NavigationLink(destination: Text("Video Scan Coming Soon")) {
                                ActionCard(
                                    title: "Large Videos",
                                    count: 0,
                                    icon: "video.fill",
                                    color: .green
                                )
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Snap Sweep")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        photoManager.requestAccessAndFetch()
                        storageInfo = StorageManager.getStorageInfo()
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
    @ObservedObject var photoManager: PhotoManager
    @StateObject var selectionManager = SelectionManager()
    @State private var hasInitialSelected = false
    @State private var currentSort: PhotoManager.SortStrategy = .newest

    let columns = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4)
    ]
    
    var formattedSize: String {
        let bytes = selectionManager.calculateTotalSize(assets: assets)
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Menu {
                    ForEach(PhotoManager.SortStrategy.allCases, id: \.self) { strategy in
                        Button(strategy.rawValue) {
                            currentSort = strategy
                            photoManager.sortAssets(by: strategy)
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "line.3.horizontal.decrease.circle")
                }
                
                Spacer()
                
                Button(selectionManager.selectedAssetIDs.count == assets.count ? "Deselect All" : "Select All") {
                    if selectionManager.selectedAssetIDs.count == assets.count {
                        selectionManager.deselectAll()
                    } else {
                        selectionManager.selectAll(assets: assets)
                    }
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))

            ScrollView {
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(assets, id: \.localIdentifier) { asset in
                        ZStack(alignment: .topTrailing) {
                            NavigationLink(destination: PhotoDetailView(asset: asset, photoManager: photoManager, selectionManager: selectionManager)) {
                                PhotoThumbnail(asset: asset)
                                    .frame(minWidth: 0, maxWidth: .infinity)
                                    .aspectRatio(1, contentMode: .fill)
                                    .frame(height: 120)
                                    .clipped()
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                            .zIndex(0)

                            Image(systemName: selectionManager.selectedAssetIDs.contains(asset.localIdentifier) ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 24))
                                .foregroundStyle(selectionManager.selectedAssetIDs.contains(asset.localIdentifier) ? .blue : .white)
                                .shadow(radius: 2)
                                .padding(8)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectionManager.toggleSelection(id: asset.localIdentifier)
                                }
                                .zIndex(1)
                        }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.top, 4)
            }
            
            if !selectionManager.selectedAssetIDs.isEmpty {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "info.circle")
                        Text("You will save \(Text(formattedSize).bold()) of space.")
                    }
                    .font(.footnote)
                    .foregroundColor(.secondary)

                    Button(action: {
                        photoManager.deleteAssets(ids: selectionManager.selectedAssetIDs) { success in
                            if success { selectionManager.deselectAll() }
                        }
                    }) {
                        Text("Delete \(selectionManager.selectedAssetIDs.count) Photos")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, y: -5)
                .transition(.move(edge: .bottom))
            }
        }
        .navigationTitle("Clean Up")
        .onAppear {
            if !hasInitialSelected {
                selectionManager.selectAll(assets: assets)
                hasInitialSelected = true
            }
        }
    }
}

struct PhotoThumbnail: View {
    let asset: PHAsset
    @State private var image: UIImage? = nil
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                Color.gray.opacity(0.2)
            }
        }
        .onAppear {
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 250, height: 250), contentMode: .aspectFill, options: options) { result, _ in
                self.image = result
            }
        }
    }
}

struct StorageGaugeView: View {
    let usedBytes: Int64
    let totalBytes: Int64
    let deletedBytes: Int64
    
    var usedPercentage: Double {
        totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) : 0
    }

    var body: some View {
        VStack(spacing: 20) {
            Gauge(value: usedPercentage, in: 0...1) {
                Text("Storage Used")
            } currentValueLabel: {
                Text("\(Int(usedPercentage * 100))%")
            } minimumValueLabel: {
                Text("0")
            } maximumValueLabel: {
                Text("100")
            }
            .gaugeStyle(.accessoryLinear)
            .tint(Gradient(colors: [.blue, .purple, .red]))
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Cleaned to Date")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(ByteCountFormatter.string(fromByteCount: deletedBytes, countStyle: .file))
                        .font(.title3).bold()
                        .foregroundColor(.green)
                }
                Spacer()
                Image(systemName: "leaf.fill")
                    .foregroundColor(.green)
                    .font(.title)
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
        }
        .padding()
    }
}

struct PhotoDetailView: View {
    let asset: PHAsset
    let photoManager: PhotoManager
    @ObservedObject var selectionManager: SelectionManager
    @State private var fullImage: UIImage? = nil
    
    var body: some View {
        VStack(spacing: 20) {
            if let img = fullImage {
                Image(uiImage: img).resizable().aspectRatio(contentMode: .fit).padding()
            } else {
                ProgressView()
            }
            
            VStack(spacing: 15) {
                VStack(spacing: 4) {
                    Text(asset.creationDate?.formatted(date: .abbreviated, time: .shortened) ?? "Unknown Date")
                        .font(.headline)
                    Text(ByteCountFormatter.string(fromByteCount: photoManager.getSize(for: asset), countStyle: .file))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Button(action: {
                    photoManager.toggleProtection(id: asset.localIdentifier)
                }) {
                    Label(
                        photoManager.protectedAssetIDs.contains(asset.localIdentifier) ? "Move to Review" : "Do Not Delete",
                        systemImage: photoManager.protectedAssetIDs.contains(asset.localIdentifier) ? "arrow.uturn.backward" : "shield.fill"
                    )
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(photoManager.protectedAssetIDs.contains(asset.localIdentifier) ? Color.orange : Color.green)
                    .cornerRadius(10)
                }

                Button(action: {
                    selectionManager.toggleSelection(id: asset.localIdentifier)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }) {
                    Label(
                        selectionManager.selectedAssetIDs.contains(asset.localIdentifier) ? "Selected for Deletion" : "Mark for Deletion",
                        systemImage: selectionManager.selectedAssetIDs.contains(asset.localIdentifier) ? "checkmark.circle.fill" : "circle"
                    )
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(selectionManager.selectedAssetIDs.contains(asset.localIdentifier) ? Color.blue : Color.gray)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 30)
        }
        .onAppear {
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options) { result, _ in
                self.fullImage = result
            }
        }
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
                Image(systemName: icon).font(.title2).foregroundColor(color)
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).foregroundColor(.primary)
                Text(count > 0 ? "\(count) items found" : "Scan to start").font(.caption).foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(15)
    }
}

struct ProtectedPhotosView: View {
    @ObservedObject var photoManager: PhotoManager
    
    var body: some View {
        ResultsView(assets: photoManager.protectedAssets, photoManager: photoManager)
            .navigationTitle("Protected Items")
            .onAppear {
                photoManager.fetchProtectedAssets()
            }
    }
}

#Preview {
    PhotoDetailView(asset: PHAsset(), photoManager: PhotoManager(), selectionManager: SelectionManager())
}
