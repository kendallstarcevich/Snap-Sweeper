import SwiftUI
import Photos
import Foundation
import AVKit

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
                            Image(systemName: "shield.checkered").foregroundColor(.green)
                            Text("Protected Vault").fontWeight(.semibold)
                            Spacer()
                            Text("\(photoManager.protectedAssetIDs.count) items")
                                .font(.caption).foregroundColor(.secondary)
                            Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 15) {
                        Text("Smart Clean Actions").font(.title2).bold()
                        
                        LazyVGrid(columns: actionColumns, spacing: 15) {
                            NavigationLink(destination: ResultsView(assets: photoManager.screenshotAssets, photoManager: photoManager)) {
                                ActionCard(title: "Screenshots", count: photoManager.screenshotCount, icon: "iphone.gen1", color: .blue)
                            }
                            NavigationLink(destination: Text("Blurry Scan Coming Soon")) {
                                ActionCard(title: "Blurry Photos", count: 0, icon: "eye.slash.fill", color: .orange)
                            }
                            NavigationLink(destination: Text("Duplicate Scan Coming Soon")) {
                                ActionCard(title: "Duplicates", count: 0, icon: "square.on.square.fill", color: .purple)
                            }
                            NavigationLink(destination: VideoResultsView(photoManager: photoManager)) {
                                ActionCard(title: "Large Videos", count: photoManager.videoCount, icon: "video.fill", color: .green)
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

// MARK: - Video Results View
struct VideoResultsView: View {
    @ObservedObject var photoManager: PhotoManager
    @StateObject var selectionManager = SelectionManager()
    let columns = [GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4)]
    
    var formattedSize: String {
        let bytes = selectionManager.calculateTotalSize(assets: photoManager.videoAssets)
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    func updateThreshold(to seconds: Double) {
        photoManager.videoThreshold = seconds
        photoManager.fetchVideos()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Menu {
                    Section("Minimum Duration") {
                        Button("Over 30 Seconds") { updateThreshold(to: 30) }
                        Button("Over 2 Minutes") { updateThreshold(to: 120) }
                        Button("Over 5 Minutes") { updateThreshold(to: 300) }
                        Button("Over 10 Minutes") { updateThreshold(to: 600) }
                    }
                } label: { Label("Threshold", systemImage: "timer") }

                Menu {
                    ForEach(PhotoManager.SortStrategy.allCases, id: \.self) { strategy in
                        Button(strategy.rawValue) { photoManager.sortVideos(by: strategy) }
                    }
                } label: { Label("Sort", systemImage: "line.3.horizontal.decrease.circle") }
                
                Spacer()
                Button(selectionManager.selectedAssetIDs.count == photoManager.videoAssets.count ? "Deselect All" : "Select All") {
                    if selectionManager.selectedAssetIDs.count == photoManager.videoAssets.count { selectionManager.deselectAll() }
                    else { selectionManager.selectAll(assets: photoManager.videoAssets) }
                }
            }
            .padding().background(Color(UIColor.secondarySystemBackground))

            ScrollView {
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(photoManager.videoAssets, id: \.localIdentifier) { asset in
                        // Inside the ForEach in VideoResultsView:
                        NavigationLink(destination: PhotoDetailView(asset: asset, photoManager: photoManager, selectionManager: selectionManager, isFromVault: false)) {
                            VideoThumbnail(asset: asset)
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fill)
                                .clipped()
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        // ADD THIS OVERLAY
                        .overlay(alignment: .bottomTrailing) {
                            VideoBadge(asset: asset)
                        }
                        .overlay(alignment: .topTrailing) {
                            SelectionToggle(id: asset.localIdentifier, selectionManager: selectionManager)
                        }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.top, 4)
            }
            
            // Replace the SummaryBar block with this:
            if !selectionManager.selectedAssetIDs.isEmpty {
                VStack(spacing: 12) {
                    HStack(spacing: 15) {
                        // 1. THE KEEP (VAULT) BUTTON
                        Button(action: {
                            for id in selectionManager.selectedAssetIDs {
                                photoManager.toggleProtection(id: id)
                            }
                            selectionManager.deselectAll()
                            // Refresh video list after moving to vault
                            photoManager.fetchVideos()
                        }) {
                            VStack {
                                Image(systemName: "shield.fill")
                                Text("Keep \(selectionManager.selectedAssetIDs.count)")
                                    .font(.caption).bold()
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }

                        // 2. THE DELETE BUTTON
                        Button(action: {
                            photoManager.deleteAssets(ids: selectionManager.selectedAssetIDs) { _ in
                                selectionManager.deselectAll()
                            }
                        }) {
                            VStack {
                                Image(systemName: "trash.fill")
                                Text("Delete \(selectionManager.selectedAssetIDs.count)")
                                    .font(.caption).bold()
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }
                    
                    Text("You will save \(Text(formattedSize).bold()) of space.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, y: -5)
            }        }
        .navigationTitle("Large Videos")
        .onAppear { photoManager.fetchVideos() }
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
                .font(.caption2).bold()
                .foregroundColor(.white)
                .padding(4)
                .background(Color.black.opacity(0.6))
                .cornerRadius(4)
                .padding(4)
        }
    }
}

// MARK: - Screenshot Results View
struct ResultsView: View {
    let assets: [PHAsset]
    @ObservedObject var photoManager: PhotoManager
    @StateObject var selectionManager = SelectionManager()
    @State private var hasInitialSelected = false
    let columns = [GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4)]
    
    var formattedSize: String {
        let bytes = selectionManager.calculateTotalSize(assets: assets)
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Menu {
                    ForEach(PhotoManager.SortStrategy.allCases, id: \.self) { strategy in
                        Button(strategy.rawValue) { photoManager.sortAssets(by: strategy) }
                    }
                } label: { Label("Sort", systemImage: "line.3.horizontal.decrease.circle") }
                Spacer()
                Button(selectionManager.selectedAssetIDs.count == assets.count ? "Deselect All" : "Select All") {
                    if selectionManager.selectedAssetIDs.count == assets.count { selectionManager.deselectAll() }
                    else { selectionManager.selectAll(assets: assets) }
                }
            }
            .padding().background(Color(UIColor.secondarySystemBackground))

            ScrollView {
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(assets, id: \.localIdentifier) { asset in
                        NavigationLink(destination: PhotoDetailView(asset: asset, photoManager: photoManager, selectionManager: selectionManager)) {
                            PhotoThumbnail(asset: asset)
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fill)
                                .clipped()
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        .overlay(alignment: .topTrailing) {
                            SelectionToggle(id: asset.localIdentifier, selectionManager: selectionManager)
                        }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.top, 4)
            }
            
            if !selectionManager.selectedAssetIDs.isEmpty {
                VStack(spacing: 12) {
                    HStack(spacing: 15) {
                        // NEW: BULK VAULT BUTTON FOR VIDEOS
                        Button(action: {
                            for id in selectionManager.selectedAssetIDs {
                                photoManager.toggleProtection(id: id)
                            }
                            selectionManager.deselectAll()
                        }) {
                            VStack {
                                Image(systemName: "shield.fill")
                                Text("Keep \(selectionManager.selectedAssetIDs.count)")
                                    .font(.caption).bold()
                            }
                            .frame(maxWidth: .infinity).padding()
                            .background(Color.green).foregroundColor(.white).cornerRadius(12)
                        }

                        // EXISTING DELETE BUTTON
                        Button(action: {
                            photoManager.deleteAssets(ids: selectionManager.selectedAssetIDs) { _ in
                                selectionManager.deselectAll()
                            }
                        }) {
                            VStack {
                                Image(systemName: "trash.fill")
                                Text("Delete \(selectionManager.selectedAssetIDs.count)")
                                    .font(.caption).bold()
                            }
                            .frame(maxWidth: .infinity).padding()
                            .background(Color.red).foregroundColor(.white).cornerRadius(12)
                        }
                    }
                    Text("You will save \(Text(formattedSize).bold()) of space.")
                        .font(.caption2).foregroundColor(.secondary)
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, y: -5)
            }
        }
        .navigationTitle("Review")
        .onAppear {
            if !hasInitialSelected {
                selectionManager.selectAll(assets: assets)
                hasInitialSelected = true
            }
        }
    }
}

struct VaultResultsView: View {
    let assets: [PHAsset]
    @ObservedObject var photoManager: PhotoManager
    @StateObject var selectionManager = SelectionManager()
    let columns = [GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4)]
    
    var formattedSize: String {
        let bytes = selectionManager.calculateTotalSize(assets: assets)
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // --- ADDED HEADER SECTION ---
            HStack {
                Menu {
                    ForEach(PhotoManager.SortStrategy.allCases, id: \.self) { strategy in
                        Button(strategy.rawValue) {
                            photoManager.sortVault(by: strategy)
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "line.3.horizontal.decrease.circle")
                }
                
                Spacer()
                
                Button(selectionManager.selectedAssetIDs.count == assets.count && !assets.isEmpty ? "Deselect All" : "Select All") {
                    if selectionManager.selectedAssetIDs.count == assets.count {
                        selectionManager.deselectAll()
                    } else {
                        selectionManager.selectAll(assets: assets)
                    }
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            // --- END HEADER SECTION ---

            ScrollView {
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(assets, id: \.localIdentifier) { asset in
                        NavigationLink(destination: PhotoDetailView(asset: asset, photoManager: photoManager, selectionManager: selectionManager, isFromVault: true)) {
                            PhotoThumbnail(asset: asset)
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fill)
                                .clipped()
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        .overlay(alignment: .bottomTrailing) {
                            VideoBadge(asset: asset)
                        }
                        .overlay(alignment: .topTrailing) {
                            SelectionToggle(id: asset.localIdentifier, selectionManager: selectionManager)
                        }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.top, 4)
            }
            
            if !selectionManager.selectedAssetIDs.isEmpty {
                SummaryBar(label: "Permanently Delete \(selectionManager.selectedAssetIDs.count) Items", size: formattedSize) {
                    photoManager.deleteAssets(ids: selectionManager.selectedAssetIDs) { _ in
                        selectionManager.deselectAll()
                    }
                }
            }
        }
    }
}

// MARK: - Standardized Reusable Components

struct SelectionToggle: View {
    let id: String
    @ObservedObject var selectionManager: SelectionManager
    var body: some View {
        Image(systemName: selectionManager.selectedAssetIDs.contains(id) ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 22))
            .foregroundStyle(selectionManager.selectedAssetIDs.contains(id) ? .blue : .white)
            .shadow(radius: 3)
            .padding(8)
            .contentShape(Rectangle())
            .onTapGesture {
                selectionManager.toggleSelection(id: id)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
    }
}

struct SummaryBar: View {
    let label: String; let size: String; let action: () -> Void
    var body: some View {
        VStack(spacing: 12) {
            Button(action: action) {
                Text(label).bold().frame(maxWidth: .infinity).padding().background(Color.red).foregroundColor(.white).cornerRadius(12)
            }
            Text("You will save \(Text(size).bold()) of space.").font(.caption2).foregroundColor(.secondary)
        }
        .padding().background(Color(UIColor.systemBackground)).shadow(color: .black.opacity(0.1), radius: 10, y: -5)
    }
}

struct VideoThumbnail: View {
    let asset: PHAsset
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            PhotoThumbnail(asset: asset)
            VideoBadge(asset: asset) // Reusing the same component!
        }
    }
}

struct PhotoThumbnail: View {
    let asset: PHAsset
    @State private var image: UIImage? = nil
    var body: some View {
        Group {
            if let image = image { Image(uiImage: image).resizable().aspectRatio(contentMode: .fill) }
            else { Color.gray.opacity(0.2) }
        }
        .onAppear {
            PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 300, height: 300), contentMode: .aspectFill, options: nil) { img, _ in self.image = img }
        }
    }
}

struct StorageGaugeView: View {
    let usedBytes: Int64; let totalBytes: Int64; let deletedBytes: Int64
    var usedPercentage: Double { totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) : 0 }
    var body: some View {
        VStack(spacing: 20) {
            Gauge(value: usedPercentage, in: 0...1) { Text("Storage Used") } currentValueLabel: { Text("\(Int(usedPercentage * 100))%") }
            .gaugeStyle(.accessoryLinear).tint(Gradient(colors: [.blue, .purple, .red]))
            HStack {
                VStack(alignment: .leading) {
                    Text("Cleaned to Date").font(.caption).foregroundColor(.secondary)
                    Text(ByteCountFormatter.string(fromByteCount: deletedBytes, countStyle: .file)).font(.title3).bold().foregroundColor(.green)
                }
                Spacer(); Image(systemName: "leaf.fill").foregroundColor(.green).font(.title)
            }
            .padding().background(Color.green.opacity(0.1)).cornerRadius(12)
        }
        .padding()
    }
}

struct ActionCard: View {
    let title: String; let count: Int; let icon: String; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Image(systemName: icon).font(.title2).foregroundColor(color); Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary) }
            VStack(alignment: .leading, spacing: 4) { Text(title).font(.headline).foregroundColor(.primary); Text(count > 0 ? "\(count) items" : "Scan to start").font(.caption).foregroundColor(.secondary) }
        }
        .padding().frame(maxWidth: .infinity, alignment: .leading).background(Color(UIColor.secondarySystemBackground)).cornerRadius(15)
    }
}

struct ProtectedPhotosView: View {
    @ObservedObject var photoManager: PhotoManager
    var body: some View {
        VaultResultsView(assets: photoManager.protectedAssets, photoManager: photoManager)
            .navigationTitle("Vault").onAppear { photoManager.fetchProtectedAssets() }
    }
}

struct PhotoDetailView: View {
    let asset: PHAsset
    let photoManager: PhotoManager
    @Environment(\.dismiss) var dismiss
    @ObservedObject var selectionManager: SelectionManager
    @State private var fullImage: UIImage? = nil
    var isFromVault: Bool = false
    @State private var player: AVPlayer? = nil
    @State private var showVideoPlayer = false
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                if let img = fullImage { Image(uiImage: img).resizable().aspectRatio(contentMode: .fit).padding() }
                else { ProgressView() }
                if asset.mediaType == .video {
                    Button(action: prepareAndPlayVideo) {
                        Image(systemName: "play.circle.fill").font(.system(size: 70)).foregroundColor(.white.opacity(0.8)).shadow(radius: 10)
                    }
                }
            }
            .sheet(isPresented: $showVideoPlayer) {
                if let player = player { VideoPlayer(player: player).onAppear { player.play() } }
            }
            
            VStack(spacing: 15) {
                VStack(spacing: 4) {
                    Text(asset.creationDate?.formatted(date: .abbreviated, time: .shortened) ?? "Unknown Date").font(.headline)
                    Text(ByteCountFormatter.string(fromByteCount: photoManager.getSize(for: asset), countStyle: .file)).font(.subheadline).foregroundColor(.secondary)
                }
                if !isFromVault {
                    Button(action: { photoManager.toggleProtection(id: asset.localIdentifier); dismiss() }) {
                        Label("Do Not Delete", systemImage: "shield.fill").font(.headline).foregroundColor(.white).padding().frame(maxWidth: .infinity).background(Color.green).cornerRadius(10)
                    }
                }
                Button(action: {
                    selectionManager.toggleSelection(id: asset.localIdentifier)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }) {
                    Label(selectionManager.selectedAssetIDs.contains(asset.localIdentifier) ? "Selected for Deletion" : "Mark for Deletion", systemImage: selectionManager.selectedAssetIDs.contains(asset.localIdentifier) ? "checkmark.circle.fill" : "circle")
                    .font(.headline).foregroundColor(.white).padding().frame(maxWidth: .infinity)
                    .background(selectionManager.selectedAssetIDs.contains(asset.localIdentifier) ? Color.red : Color.gray).cornerRadius(10)
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 30)
        }
        .onAppear { loadFullImage() }
    }
    func loadFullImage() { PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: nil) { img, _ in self.fullImage = img } }
    func prepareAndPlayVideo() {
        PHImageManager.default().requestAVAsset(forVideo: asset, options: nil) { avAsset, _, _ in
            if let urlAsset = avAsset as? AVURLAsset { DispatchQueue.main.async { self.player = AVPlayer(url: urlAsset.url); self.showVideoPlayer = true } }
        }
    }
}
