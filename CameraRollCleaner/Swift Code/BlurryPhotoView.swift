import SwiftUI
import Photos


// MARK: - Blur Scan Result Model
struct BlurryResult: Identifiable {
    let id = UUID()
    let asset: PHAsset
    let score: Double
    let image: UIImage
}


// MARK: - Main View
struct BlurryPhotosView: View {
    
    @ObservedObject var photoManager: PhotoManager
    let refreshTrigger: UUID?
    
    @StateObject var selectionManager = SelectionManager()
    
    @State private var dragLocation: CGPoint = .zero
    @State private var sortMostBlurryFirst = true
    
    private let blurManager = BlurModelManager()
    
    let columns = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4)
    ]
    
    init(photoManager: PhotoManager, refreshTrigger: UUID? = nil) {
        self.photoManager = photoManager
        self.refreshTrigger = refreshTrigger
    }
    
    var sortedResults: [BlurryResult] {
        photoManager.blurryResults.sorted {
            sortMostBlurryFirst ? $0.score > $1.score : $0.score < $1.score
        }
    }
    
    var body: some View {
        ZStack {
            AppPalette.pageBackground
                .ignoresSafeArea()
            
            VStack {
                
                // HEADER
                HStack {
                    Button("Sort") {
                        sortMostBlurryFirst.toggle()
                    }
                    
                    Spacer()
                    
                    Button(
                        selectionManager.selectedAssetIDs.count == sortedResults.count && !sortedResults.isEmpty
                        ? "Deselect All"
                        : "Select All"
                    ) {
                        if selectionManager.selectedAssetIDs.count == sortedResults.count {
                            selectionManager.deselectAll()
                        } else {
                            selectionManager.selectAll(assets: sortedResults.map { $0.asset })
                        }
                    }
                }
                .padding()
                
                // GRID
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
                                BlurryGridItemView(
                                    result: result,
                                    selectionManager: selectionManager
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
        }
        .onAppear {
            if photoManager.allPhotoAssets.isEmpty {
                photoManager.fetchAllPhotos()
            }
            
            if !photoManager.hasScannedBlurry {
                photoManager.scanForBlurryPhotos(using: blurManager)
            }
        }
        .onChange(of: refreshTrigger) { _, newValue in
            guard newValue != nil else { return }
            
            photoManager.fetchAllPhotos()
            photoManager.hasScannedBlurry = false
            photoManager.scanForBlurryPhotos(using: blurManager)
        }
    }
}

// MARK: - Grid Item View (FIXES compiler crash)
struct BlurryGridItemView: View {
    
    let result: BlurryResult
    let selectionManager: SelectionManager
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            
            BlurryThumbnail(image: result.image)
                .aspectRatio(1, contentMode: .fill)
                .clipped()
                .cornerRadius(8)
            
            // Top right selection
            ContentView.SelectionToggle(
                id: result.asset.localIdentifier,
                selectionManager: selectionManager
            )
            
            // Bottom right score
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    BlurScoreBadge(score: result.score)
                }
            }
        }
    }
}




struct BlurryThumbnail: View {
    let image: UIImage
    
    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
    }
}


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

// MARK: - Pager View
struct BlurryPhotoPagerView: View {
    
    @State var results: [BlurryResult]
    let startIndex: Int
    
    @ObservedObject var photoManager: PhotoManager
    @ObservedObject var selectionManager: SelectionManager
    
    @State private var currentIndex: Int = 0
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            AppPalette.pageBackground
                .ignoresSafeArea()
            
            if results.isEmpty {
                VStack {
                    Spacer()
                    Text("No more blurry photos")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                TabView(selection: $currentIndex) {
                    
                    ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                        
                        VStack(spacing: 20) {
                            
                            Spacer()
                            
                            Image(uiImage: result.image)
                                .resizable()
                                .scaledToFit()
                                .cornerRadius(12)
                                .padding()
                            
                            Text("Blur Score: \(result.score, specifier: "%.3f")")
                                .font(.headline)
                            
                            HStack(spacing: 16) {
                                
                                Button("Keep") {
                                    photoManager.toggleProtection(id: result.asset.localIdentifier)
                                }
                                
                                Button("Delete") {
                                    let id = result.asset.localIdentifier
                                    photoManager.deleteAssets(ids: [id]) { success in
                                        if success {
                                            if let i = results.firstIndex(where: { $0.asset.localIdentifier == id }) {
                                                results.remove(at: i)
                                                
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
                            
                            Spacer()
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page)
            }
        }
        .onAppear {
            currentIndex = min(startIndex, max(results.count - 1, 0))
        }
    }
}
