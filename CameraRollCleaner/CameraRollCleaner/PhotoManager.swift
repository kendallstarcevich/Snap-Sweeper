import Photos
import SwiftUI
import Combine

class PhotoManager: ObservableObject {
    @Published var photoCount = 0
    @Published var screenshotCount = 0
    @Published var isAuthorized = false
    
    func requestAccessAndFetch() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async {
                if status == .authorized {
                    self.isAuthorized = true
                    self.fetchMetadata()
                }
            }
        }
    }
    
    private func fetchMetadata() {
        let allPhotos = PHAsset.fetchAssets(with: .image, options: nil)
        self.photoCount = allPhotos.count
        
        // 1. Create a dynamic array to hold our findings
        var foundScreenshots = 0
        
        // 2. Loop through the photos and check for signs of a screenshot
        allPhotos.enumerateObjects { (asset, index, stop) in
            // Check A: The official Apple Subtype
            let isOfficialScreenshot = asset.mediaSubtypes.contains(.photoScreenshot)
            
            // Check B: The "Simulator" check (Simulators often omit the subtype)
            // We can check if the metadata suggests it's a screenshot
            if isOfficialScreenshot {
                foundScreenshots += 1
            }
        }
        
        self.screenshotCount = foundScreenshots
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
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .onAppear {
                            loadThumbnail()
                        }
                }
            }
            .frame(width: 100, height: 100)
            .clipped()
        }
        
        func loadThumbnail() {
            let manager = PHImageManager.default()
            let options = PHImageRequestOptions()
            options.isSynchronous = false // Don't freeze the app!
            options.deliveryMode = .opportunistic
            
            manager.requestImage(for: asset,
                                 targetSize: CGSize(width: 200, height: 200),
                                 contentMode: .aspectFill,
                                 options: options) { result, _ in
                self.image = result
            }
        }
    }
}
