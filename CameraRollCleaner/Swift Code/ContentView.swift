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

// MARK: - Main Dashboard
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
                    // 1. Storage Gauge
                    StorageGaugeView(
                        usedBytes: storageInfo.usedBytes,
                        totalBytes: storageInfo.totalBytes,
                        deletedBytes: photoManager.totalBytesDeleted
                    )
                    .padding(.top)
                    
                    // 2. Protected Vault Link
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
                    
                    // 3. NEW POSITION: Manual Review (All Media)
                    NavigationLink(destination: ManualReviewView(photoManager: photoManager)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("All Media").font(.headline)
                                Text("Manual sort by size, date, or type").font(.subheadline)
                            }
                            Spacer()
                            Image(systemName: "slider.horizontal.3")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // 4. Smart Clean Actions
                    // 4. Smart Clean Actions
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Smart Clean Actions").font(.title2).bold()
                        
                        LazyVGrid(columns: actionColumns, spacing: 15) {
                            NavigationLink(destination: ResultsView(assets: photoManager.screenshotAssets, photoManager: photoManager)) {
                                ActionCard(title: "Screenshots", count: photoManager.screenshotCount, icon: "iphone.gen1", color: .blue)
                            }
                            NavigationLink(destination: BlurryPhotosView(photoManager: photoManager)) {
                                ActionCard(title: "Blurry Photos", count: photoManager.blurryCount, icon: "eye.slash.fill", color: .orange)
                            }
                            NavigationLink(destination: DuplicatesView(photoManager: photoManager)) {
                                ActionCard(title: "Similarity Score", count: photoManager.duplicateGroups.count, icon: "square.on.square.fill", color: .purple)
                            }
                            NavigationLink(destination: VideoResultsView(photoManager: photoManager)) {
                                ActionCard(title: "Large Videos", count: photoManager.videoCount, icon: "video.fill", color: .green)
                            }
                            
                            // --- ADD THE MAP SWEEPER HERE ---
                            NavigationLink(destination: MapSweeperView(photoManager: photoManager)) {
                                ActionCard(
                                    title: "Map Sweeper",
                                    count: photoManager.localizedAssets.count,
                                    icon: "map.fill",
                                    color: .red
                                )
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
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                photoManager.scanForDuplicates()
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                        
                        .onAppear {
                            photoManager.fetchLocalizedAssets() // Updates the Map Sweeper count
                            storageInfo = StorageManager.getStorageInfo()
                        }
                    }
                }
            }
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
        // Default to 10 years to capture everything
        @State private var startDate = Calendar.current.date(byAdding: .year, value: -10, to: Date()) ?? Date()
        @State private var endDate = Date()
        
        @State private var region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.0902, longitude: -95.7129),
            span: MKCoordinateSpan(latitudeDelta: 120, longitudeDelta: 120)
        )
        
        struct LocationKey: Hashable {
            let latitude: Double
            let longitude: Double
        }
        
        var annotations: [PhotoAnnotation] {
            let filtered = photoManager.localizedAssets.filter { asset in
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
            VStack(spacing: 0) {
                // 1. DATE FILTER HEADER
                HStack {
                    DatePicker("", selection: $startDate, displayedComponents: .date).labelsHidden()
                    Text("to")
                    DatePicker("", selection: $endDate, displayedComponents: .date).labelsHidden()
                }
                .padding().background(Color(UIColor.secondarySystemBackground))

                // 2. THE INTERACTIVE MAP
                Map(coordinateRegion: $region, annotationItems: annotations) { annotation in
                    MapAnnotation(coordinate: annotation.coordinate) {
                        // This now leads to the Group View instead of just one photo
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
                                        .padding(2).background(Color.black.opacity(0.6))
                                        .foregroundColor(.white).cornerRadius(4)
                                }
                                
                                if annotation.count > 1 {
                                    Text("\(annotation.count)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white).padding(5)
                                        .background(Color.blue).clipShape(Circle())
                                        .offset(x: 5, y: -5)
                                }
                            }
                        }
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    // ZOOM CONTROLS
                    VStack(spacing: 12) {
                        Button(action: { withAnimation { region.span.latitudeDelta /= 4; region.span.longitudeDelta /= 4 } }) {
                            Image(systemName: "plus.magnifyingglass").padding().background(.ultraThinMaterial).clipShape(Circle())
                        }
                        Button(action: { withAnimation { region.span.latitudeDelta = min(region.span.latitudeDelta * 4, 120); region.span.longitudeDelta = min(region.span.longitudeDelta * 4, 120) } }) {
                            Image(systemName: "minus.magnifyingglass").padding().background(.ultraThinMaterial).clipShape(Circle())
                        }
                    }.padding().padding(.bottom, 20)
                }
            }
            .navigationTitle("Map Sweeper")
            .onAppear { photoManager.fetchLocalizedAssets() }
        }
    }
    
    // MARK: - Video Results View
    struct VideoResultsView: View {
        @ObservedObject var photoManager: PhotoManager
        @StateObject var selectionManager = SelectionManager()
        @State private var dragLocation: CGPoint = .zero // Drag selection state
        
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
                            Button("Over 30s") { updateThreshold(to: 30) }
                            Button("Over 2m") { updateThreshold(to: 120) }
                            Button("Over 5m") { updateThreshold(to: 300) }
                        }
                    } label: { Label("Limit", systemImage: "timer") }
                    
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
                    LazyVGrid(columns: columns, spacing: 2) { // Spacing set to 2 for a tighter grid
                        ForEach(photoManager.videoAssets, id: \.localIdentifier) { asset in
                            NavigationLink(destination: PhotoDetailView(asset: asset, photoManager: photoManager, selectionManager: selectionManager, isFromVault: false)) {
                                PhotoThumbnail(asset: asset)
                                    .cornerRadius(4)
                                
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
                                SelectionToggle(id: asset.localIdentifier, selectionManager: selectionManager)
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.top, 4)
                }            .simultaneousGesture(
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
                                VStack { Image(systemName: "shield.fill"); Text("Keep \(selectionManager.selectedAssetIDs.count)").font(.caption).bold() }
                                    .frame(maxWidth: .infinity).padding().background(Color.green).foregroundColor(.white).cornerRadius(12)
                            }
                            Button(action: {
                                photoManager.deleteAssets(ids: selectionManager.selectedAssetIDs) { _ in selectionManager.deselectAll() }
                            }) {
                                VStack { Image(systemName: "trash.fill"); Text("Delete \(selectionManager.selectedAssetIDs.count)").font(.caption).bold() }
                                    .frame(maxWidth: .infinity).padding().background(Color.red).foregroundColor(.white).cornerRadius(12)
                            }
                        }
                        Text("You will save \(Text(formattedSize).bold()) of space.").font(.caption2).foregroundColor(.secondary)
                    }
                    .padding().background(Color(UIColor.systemBackground)).shadow(color: .black.opacity(0.1), radius: 10, y: -5)
                }
            }
            .navigationTitle("Large Videos")
            .onAppear { photoManager.fetchVideos() }
        }
    }
    
    // MARK: - Screenshot Results View
    struct ResultsView: View {
        let assets: [PHAsset]
        @ObservedObject var photoManager: PhotoManager
        @StateObject var selectionManager = SelectionManager()
        @State private var dragLocation: CGPoint = .zero
        
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
                    LazyVGrid(columns: columns, spacing: 2) { // 2px spacing to match manual review
                        ForEach(assets, id: \.localIdentifier) { asset in
                            NavigationLink(destination: PhotoDetailView(asset: asset, photoManager: photoManager, selectionManager: selectionManager)) {
                                PhotoThumbnail(asset: asset)
                                    .cornerRadius(4)
                                
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
                                SelectionToggle(id: asset.localIdentifier, selectionManager: selectionManager)
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
                
                
                if !selectionManager.selectedAssetIDs.isEmpty {
                    VStack(spacing: 12) {
                        HStack(spacing: 15) {
                            Button(action: {
                                for id in selectionManager.selectedAssetIDs { photoManager.toggleProtection(id: id) }
                                selectionManager.deselectAll()
                            }) {
                                VStack { Image(systemName: "shield.fill"); Text("Keep \(selectionManager.selectedAssetIDs.count)").font(.caption).bold() }
                                    .frame(maxWidth: .infinity).padding().background(Color.green).foregroundColor(.white).cornerRadius(12)
                            }
                            Button(action: {
                                photoManager.deleteAssets(ids: selectionManager.selectedAssetIDs) { _ in selectionManager.deselectAll() }
                            }) {
                                VStack { Image(systemName: "trash.fill"); Text("Delete \(selectionManager.selectedAssetIDs.count)").font(.caption).bold() }
                                    .frame(maxWidth: .infinity).padding().background(Color.red).foregroundColor(.white).cornerRadius(12)
                            }
                        }
                        Text("You will save \(Text(formattedSize).bold()) of space.").font(.caption2).foregroundColor(.secondary)
                    }
                    .padding().background(Color(UIColor.systemBackground)).shadow(color: .black.opacity(0.1), radius: 10, y: -5)
                }
            }
            .navigationTitle("Review")
        }
    }
    
    // MARK: - Vault View
    struct VaultResultsView: View {
        let assets: [PHAsset]
        @ObservedObject var photoManager: PhotoManager
        @StateObject var selectionManager = SelectionManager()
        @State private var dragLocation: CGPoint = .zero
        
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
                            Button(strategy.rawValue) { photoManager.sortVault(by: strategy) }
                        }
                    } label: { Label("Sort", systemImage: "line.3.horizontal.decrease.circle") }
                    Spacer()
                    Button(selectionManager.selectedAssetIDs.count == assets.count && !assets.isEmpty ? "Deselect All" : "Select All") {
                        if selectionManager.selectedAssetIDs.count == assets.count { selectionManager.deselectAll() }
                        else { selectionManager.selectAll(assets: assets) }
                    }
                }
                .padding().background(Color(UIColor.secondarySystemBackground))
                
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) { // Standardizing to 2px spacing
                        ForEach(assets, id: \.localIdentifier) { asset in
                            NavigationLink(destination: PhotoDetailView(asset: asset, photoManager: photoManager, selectionManager: selectionManager, isFromVault: true)) {
                                PhotoThumbnail(asset: asset)
                                    .cornerRadius(4)
                                
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
                                SelectionToggle(id: asset.localIdentifier, selectionManager: selectionManager)
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
                
                if !selectionManager.selectedAssetIDs.isEmpty {
                    SummaryBar(label: "Permanently Delete \(selectionManager.selectedAssetIDs.count) Items", size: formattedSize) {
                        photoManager.deleteAssets(ids: selectionManager.selectedAssetIDs) { _ in selectionManager.deselectAll() }
                    }
                }
            }
        }
    }
    struct DuplicatesView: View {
        @ObservedObject var photoManager: PhotoManager
        // Track selected groups by their index in the array
        @State private var selectedGroupIndices = Set<Int>()
        
        var totalBulkSavings: Int64 {
            selectedGroupIndices.reduce(0) { sum, index in
                sum + calculatePotentialSavings(photoManager.duplicateGroups[index])
            }
        }
        
        var body: some View {
            VStack(spacing: 0) {
                List {
                    ForEach(0..<photoManager.duplicateGroups.count, id: \.self) { index in
                        let group = photoManager.duplicateGroups[index]
                        let isSelected = selectedGroupIndices.contains(index)
                        
                        HStack(spacing: 15) {
                            // Group Selection Toggle
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundColor(isSelected ? .purple : .secondary)
                                .onTapGesture {
                                    if isSelected { selectedGroupIndices.remove(index) }
                                    else { selectedGroupIndices.insert(index) }
                                }
                            
                            NavigationLink(destination: DuplicateGroupDetailView(group: group, photoManager: photoManager)) {
                                HStack {
                                    PhotoThumbnail(asset: group.first!)
                                        .frame(width: 55, height: 55).cornerRadius(8)
                                        .contentShape(Rectangle())
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Group \(index + 1)").font(.headline)
                                        Text("\(group.count) similar photos").font(.subheadline).foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Text("Save \(ByteCountFormatter.string(fromByteCount: calculatePotentialSavings(group), countStyle: .file))")
                                        .font(.caption2).bold()
                                        .padding(6).background(Color.purple.opacity(0.1)).foregroundColor(.purple).cornerRadius(6)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                
                // --- BULK ACTION BAR ---
                if !selectedGroupIndices.isEmpty {
                    VStack(spacing: 12) {
                        HStack(spacing: 15) {
                            // Bulk Vault
                            Button(action: { bulkVaultGroups() }) {
                                VStack { Image(systemName: "shield.fill"); Text("Vault Groups").font(.caption).bold() }
                                    .frame(maxWidth: .infinity).padding().background(Color.green).foregroundColor(.white).cornerRadius(12)
                            }
                            
                            // Bulk Delete
                            Button(action: { bulkDeleteGroups() }) {
                                VStack { Image(systemName: "trash.fill"); Text("Delete Groups").font(.caption).bold() }
                                    .frame(maxWidth: .infinity).padding().background(Color.red).foregroundColor(.white).cornerRadius(12)
                            }
                        }
                        Text("Bulk action will save \(Text(ByteCountFormatter.string(fromByteCount: totalBulkSavings, countStyle: .file)).bold())")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    .padding().background(Color(UIColor.systemBackground)).shadow(radius: 10)
                }
            }
            .navigationTitle("Similar Photos")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(selectedGroupIndices.count == photoManager.duplicateGroups.count ? "None" : "All") {
                        if selectedGroupIndices.count == photoManager.duplicateGroups.count { selectedGroupIndices.removeAll() }
                        else { selectedGroupIndices = Set(0..<photoManager.duplicateGroups.count) }
                    }
                }
            }
        }
        
        // --- HELPER LOGIC ---
        
        func calculatePotentialSavings(_ group: [PHAsset]) -> Int64 {
            guard group.count > 1 else { return 0 }
            let total = group.reduce(0) { $0 + photoManager.getSize(for: $1) }
            return total - photoManager.getSize(for: group.first!)
        }
        
        func bulkDeleteGroups() {
            var idsToDelete: [String] = []
            for index in selectedGroupIndices {
                let group = photoManager.duplicateGroups[index]
                // Keep the first (index 0), delete the rest
                let others = group.dropFirst().map { $0.localIdentifier }
                idsToDelete.append(contentsOf: others)
            }
            
            // Convert the Array to a Set here:
            photoManager.deleteAssets(ids: Set(idsToDelete)) { success in
                if success {
                    // Clear the UI state after a successful deletion
                    selectedGroupIndices.removeAll()
                    photoManager.scanForDuplicates()
                }
            }
        }
        
        func bulkVaultGroups() {
            for index in selectedGroupIndices {
                let group = photoManager.duplicateGroups[index]
                // Protect all photos in the selected groups
                for asset in group { photoManager.toggleProtection(id: asset.localIdentifier) }
            }
            selectedGroupIndices.removeAll()
            photoManager.scanForDuplicates()
        }
    }
    
    
    struct DuplicateGroupDetailView: View {
        let group: [PHAsset]
        @ObservedObject var photoManager: PhotoManager
        @StateObject var selectionManager = SelectionManager()
        @Environment(\.dismiss) var dismiss
        
        var formattedSelectionSize: String {
            let bytes = selectionManager.calculateTotalSize(assets: group.filter { selectionManager.selectedAssetIDs.contains($0.localIdentifier) })
            return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        }
        
        var body: some View {
            VStack(spacing: 0) {
                TabView {
                    ForEach(group, id: \.localIdentifier) { asset in
                        VStack {
                            PhotoThumbnail(asset: asset)
                                .aspectRatio(contentMode: .fit)
                                .cornerRadius(12).padding()
                                .contentShape(Rectangle())
                            
                            Text(ByteCountFormatter.string(fromByteCount: photoManager.getSize(for: asset), countStyle: .file))
                                .font(.subheadline).bold().foregroundColor(.secondary)
                            
                            Button(action: { selectionManager.toggleSelection(id: asset.localIdentifier) }) {
                                Label(selectionManager.selectedAssetIDs.contains(asset.localIdentifier) ? "Selected" : "Select to Delete",
                                      systemImage: selectionManager.selectedAssetIDs.contains(asset.localIdentifier) ? "checkmark.circle.fill" : "circle")
                                .font(.headline).padding().frame(maxWidth: .infinity)
                                .background(selectionManager.selectedAssetIDs.contains(asset.localIdentifier) ? Color.red : Color.gray.opacity(0.2))
                                .foregroundColor(selectionManager.selectedAssetIDs.contains(asset.localIdentifier) ? .white : .primary)
                                .cornerRadius(12)
                            }.padding(.horizontal, 40).padding(.top, 10)
                        }
                    }
                }.tabViewStyle(.page).indexViewStyle(.page(backgroundDisplayMode: .always))
                
                // THE ACTION BAR (Matching your Screenshot/Video UI)
                if !selectionManager.selectedAssetIDs.isEmpty {
                    VStack(spacing: 15) {
                        HStack(spacing: 15) {
                            // VAULT BUTTON
                            Button(action: {
                                for id in selectionManager.selectedAssetIDs { photoManager.toggleProtection(id: id) }
                                photoManager.scanForDuplicates()
                                dismiss()
                            }) {
                                VStack { Image(systemName: "shield.fill"); Text("Vault").font(.caption).bold() }
                                    .frame(maxWidth: .infinity).padding().background(Color.green).foregroundColor(.white).cornerRadius(12)
                            }
                            
                            // DELETE BUTTON
                            Button(action: {
                                photoManager.deleteAssets(ids: selectionManager.selectedAssetIDs) { _ in
                                    photoManager.scanForDuplicates()
                                    dismiss()
                                }
                            }) {
                                VStack { Image(systemName: "trash.fill"); Text("Delete").font(.caption).bold() }
                                    .frame(maxWidth: .infinity).padding().background(Color.red).foregroundColor(.white).cornerRadius(12)
                            }
                        }
                        Text("You will save \(Text(formattedSelectionSize).bold()) of space.").font(.caption2).foregroundColor(.secondary)
                    }
                    .padding().background(Color(UIColor.systemBackground)).shadow(radius: 10)
                }
            }
            .navigationTitle("Review Similar Photos")
            .onAppear {
                // Suggest deleting all but the first (usually the 'best') photo
                for i in 1..<group.count {
                    selectionManager.selectedAssetIDs.insert(group[i].localIdentifier)
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
                .foregroundStyle(selectionManager.selectedAssetIDs.contains(id) ? .blue : .white)
                .shadow(radius: 3).padding(8).contentShape(Rectangle())
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
            formatter.allowedUnits = [.minute, .second]; formatter.unitsStyle = .positional; formatter.zeroFormattingBehavior = .pad
            return formatter.string(from: asset.duration) ?? "0:00"
        }
        var body: some View {
            if asset.mediaType == .video {
                Text(durationString).font(.caption2).bold().foregroundColor(.white).padding(4).background(Color.black.opacity(0.6)).cornerRadius(4).padding(4)
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
                    .contentShape(Rectangle())
            }
        }
    }
    
    struct PhotoThumbnail: View {
        let asset: PHAsset
        @State private var image: UIImage? = nil
        
        var body: some View {
            // GeometryReader calculates the available width of the grid cell
            GeometryReader { geometry in
                Group {
                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill) // Fills the entire square
                            .frame(width: geometry.size.width, height: geometry.size.width) // Forces height to match width
                            .clipped() // Cuts off the horizontal or vertical overlap
                    } else {
                        Color.gray.opacity(0.2)
                    }
                }
            }
            // This keeps the "box" square even before the image loads
            .aspectRatio(1, contentMode: .fit)
            .onAppear {
                PHImageManager.default().requestImage(
                    for: asset,
                    targetSize: CGSize(width: 400, height: 400),
                    contentMode: .aspectFill,
                    options: nil
                ) { img, _ in self.image = img }
            }
        }
    }
    
    
    struct ManualReviewView: View {
        @ObservedObject var photoManager: PhotoManager
        @StateObject var selectionManager = SelectionManager()
        @State private var dragLocation: CGPoint = .zero
        
        // Filter & Sort States
        @State private var selectedSort: PhotoManager.SortStrategy = .newest
        @State private var filterPhotos = true
        @State private var filterVideos = true
        
        // Grid setup: 3 columns with 2px spacing to match Screenshots view
        let columns = [
            GridItem(.flexible(), spacing: 2),
            GridItem(.flexible(), spacing: 2),
            GridItem(.flexible(), spacing: 2)
        ]
        
        var processedAssets: [PHAsset] {
            var filtered = photoManager.allAssets.filter { asset in
                if asset.mediaType == .image && filterPhotos { return true }
                if asset.mediaType == .video && filterVideos { return true }
                return false
            }
            
            // Exclude already protected items
            filtered = filtered.filter { !photoManager.protectedAssetIDs.contains($0.localIdentifier) }
            
            switch selectedSort {
            case .newest: return filtered.sorted { ($0.creationDate ?? Date()) > ($1.creationDate ?? Date()) }
            case .oldest: return filtered.sorted { ($0.creationDate ?? Date()) < ($1.creationDate ?? Date()) }
            case .largest: return filtered.sorted { photoManager.getSize(for: $0) > photoManager.getSize(for: $1) }
            }
        }
        
        var formattedSize: String {
            let selectedAssets = processedAssets.filter { selectionManager.selectedAssetIDs.contains($0.localIdentifier) }
            let bytes = selectionManager.calculateTotalSize(assets: selectedAssets)
            return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        }
        
        var body: some View {
            VStack(spacing: 0) {
                // --- HEADER: TYPE FILTER & SEGMENTED SORT ---
                VStack(spacing: 12) {
                    HStack {
                        Text("Show:").font(.caption).bold().foregroundColor(.secondary)
                        Toggle("Photos", isOn: $filterPhotos).toggleStyle(.button)
                        Toggle("Videos", isOn: $filterVideos).toggleStyle(.button)
                        Spacer()
                        Button(selectionManager.selectedAssetIDs.count == processedAssets.count && !processedAssets.isEmpty ? "Deselect All" : "Select All") {
                            if selectionManager.selectedAssetIDs.count == processedAssets.count {
                                selectionManager.deselectAll()
                            } else {
                                selectionManager.selectAll(assets: processedAssets)
                            }
                        }.font(.caption).bold()
                    }
                    
                    Picker("Sort", selection: $selectedSort) {
                        ForEach(PhotoManager.SortStrategy.allCases, id: \.self) { strategy in
                            Text(strategy.rawValue).tag(strategy)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                
                // --- THE UNIFORM SQUARE GRID ---
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(processedAssets, id: \.localIdentifier) { asset in
                            NavigationLink(destination: PhotoDetailView(asset: asset, photoManager: photoManager, selectionManager: selectionManager)) {
                                // --- THIS BLOCK ENSURES PERFECT SQUARES ---
                                PhotoThumbnail(asset: asset)
                                    .cornerRadius(4)
                                
                            }
                            .buttonStyle(.plain)
                            .background(
                                GeometryReader { geo in
                                    Color.clear.onChange(of: dragLocation) { old, newLoc in
                                        if geo.frame(in: .global).contains(newLoc) {
                                            selectionManager.dragSelect(id: asset.localIdentifier)
                                        }
                                    }
                                }
                            )
                            .overlay(alignment: .bottomTrailing) { VideoBadge(asset: asset) }
                            .overlay(alignment: .topTrailing) {
                                SelectionToggle(id: asset.localIdentifier, selectionManager: selectionManager)
                            }
                        }
                    }
                    .padding(.top, 2)
                }
                .gesture(
                    DragGesture(minimumDistance: 15)
                        .onChanged { dragLocation = $0.location }
                        .onEnded { _ in dragLocation = .zero }
                )
                
                // --- DUAL ACTION BAR (VAULT & DELETE) ---
                if !selectionManager.selectedAssetIDs.isEmpty {
                    VStack(spacing: 15) {
                        HStack(spacing: 15) {
                            // MOVE TO VAULT
                            Button(action: {
                                for id in selectionManager.selectedAssetIDs { photoManager.toggleProtection(id: id) }
                                selectionManager.deselectAll()
                                photoManager.fetchAllAssets()
                            }) {
                                VStack { Image(systemName: "shield.fill"); Text("Keep").font(.caption).bold() }
                                    .frame(maxWidth: .infinity).padding().background(Color.green).foregroundColor(.white).cornerRadius(12)
                            }
                            
                            // DELETE
                            Button(action: {
                                photoManager.deleteAssets(ids: selectionManager.selectedAssetIDs) { _ in
                                    selectionManager.deselectAll()
                                    photoManager.fetchAllAssets()
                                }
                            }) {
                                VStack { Image(systemName: "trash.fill"); Text("Delete").font(.caption).bold() }
                                    .frame(maxWidth: .infinity).padding().background(Color.red).foregroundColor(.white).cornerRadius(12)
                            }
                        }
                        Text("Selected: \(selectionManager.selectedAssetIDs.count) items (\(formattedSize))")
                            .font(.caption2).foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 10, y: -5)
                }
            }
            .navigationTitle("Manual Review")
            .onAppear { photoManager.fetchAllAssets() }
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
        @StateObject private var authManager = AuthManager()
        
        var body: some View {
            Group {
                if authManager.isUnlocked {
                    // The actual Vault Content
                    VaultResultsView(assets: photoManager.protectedAssets, photoManager: photoManager)
                        .navigationTitle("Vault")
                        .onAppear { photoManager.fetchProtectedAssets() }
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Lock") { authManager.lock() }
                            }
                        }
                } else {
                    // The Locked "Gate" Screen
                    VStack(spacing: 20) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.green)
                        
                        Text("Vault is Locked")
                            .font(.title2).bold()
                        
                        Text("Use FaceID to access your protected media.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button(action: { authManager.authenticate() }) {
                            Label("Unlock Vault", systemImage: "faceid")
                                .font(.headline)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 40)
                    }
                    .onAppear {
                        // Automatically trigger FaceID when the view opens
                        authManager.authenticate()
                    }
                }
            }
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
}
struct LocationGroupView: View {
    let assets: [PHAsset]
    @ObservedObject var photoManager: PhotoManager
    @StateObject var selectionManager = SelectionManager()
    @State private var dragLocation: CGPoint = .zero
    
    let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    // Calculate size of currently selected photos in this group
    var formattedSelectionSize: String {
        let selected = assets.filter { selectionManager.selectedAssetIDs.contains($0.localIdentifier) }
        let bytes = selectionManager.calculateTotalSize(assets: selected)
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(assets, id: \.localIdentifier) { asset in
                        NavigationLink(destination: PhotoDetailView(asset: asset, photoManager: photoManager, selectionManager: selectionManager)) {
                            PhotoThumbnail(asset: asset)
                                .cornerRadius(4)
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
                        .overlay(alignment: .topTrailing) {
                            SelectionToggle(id: asset.localIdentifier, selectionManager: selectionManager)
                        }
                    }
                }
                .padding(.top, 2)
            }
            .gesture(
                DragGesture(minimumDistance: 15)
                    .onChanged { dragLocation = $0.location }
                    .onEnded { _ in dragLocation = .zero }
            )

            // --- THE SHARED ACTION BAR ---
            if !selectionManager.selectedAssetIDs.isEmpty {
                VStack(spacing: 12) {
                    HStack(spacing: 15) {
                        Button(action: {
                            for id in selectionManager.selectedAssetIDs { photoManager.toggleProtection(id: id) }
                            selectionManager.deselectAll()
                        }) {
                            VStack {
                                Image(systemName: "shield.fill")
                                Text("Keep").font(.caption).bold()
                            }
                            .frame(maxWidth: .infinity).padding().background(Color.green).foregroundColor(.white).cornerRadius(12)
                        }
                        
                        Button(action: {
                            photoManager.deleteAssets(ids: selectionManager.selectedAssetIDs) { success in
                                if success { selectionManager.deselectAll() }
                            }
                        }) {
                            VStack {
                                Image(systemName: "trash.fill")
                                Text("Delete").font(.caption).bold()
                            }
                            .frame(maxWidth: .infinity).padding().background(Color.red).foregroundColor(.white).cornerRadius(12)
                        }
                    }
                    Text("You will save \(Text(formattedSelectionSize).bold()) of space.")
                        .font(.caption2).foregroundColor(.secondary)
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, y: -5)
            }
        }
        .navigationTitle("Location Photos")
    }
}
// MARK: - Missing Thumbnail View
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
                targetSize: CGSize(width: 300, height: 300),
                contentMode: .aspectFill,
                options: nil
            ) { img, _ in self.image = img }
        }
    }
}

// MARK: - Missing Detail View
struct PhotoDetailView: View {
    let asset: PHAsset
    let photoManager: PhotoManager
    @ObservedObject var selectionManager: SelectionManager
    @Environment(\.dismiss) var dismiss
    @State private var fullImage: UIImage? = nil
    var isFromVault: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            // Image Display
            ZStack {
                if let img = fullImage {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding()
                } else {
                    ProgressView()
                }
            }
            
            // Metadata & Actions
            VStack(spacing: 15) {
                VStack(spacing: 4) {
                    Text(asset.creationDate?.formatted(date: .abbreviated, time: .shortened) ?? "Unknown Date")
                        .font(.headline)
                    Text(ByteCountFormatter.string(fromByteCount: photoManager.getSize(for: asset), countStyle: .file))
                        .font(.subheadline).foregroundColor(.secondary)
                }
                
                if !isFromVault {
                    Button(action: {
                        photoManager.toggleProtection(id: asset.localIdentifier)
                        dismiss()
                    }) {
                        Label("Do Not Delete", systemImage: "shield.fill")
                            .font(.headline).foregroundColor(.white)
                            .padding().frame(maxWidth: .infinity)
                            .background(Color.green).cornerRadius(10)
                    }
                }
                
                Button(action: {
                    selectionManager.toggleSelection(id: asset.localIdentifier)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }) {
                    let isSelected = selectionManager.selectedAssetIDs.contains(asset.localIdentifier)
                    Label(isSelected ? "Selected for Deletion" : "Mark for Deletion",
                          systemImage: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.headline).foregroundColor(.white)
                        .padding().frame(maxWidth: .infinity)
                        .background(isSelected ? Color.red : Color.gray)
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
        .onAppear { loadFullImage() }
    }

    func loadFullImage() {
        PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: nil) { img, _ in
            self.fullImage = img
        }
    }
}

