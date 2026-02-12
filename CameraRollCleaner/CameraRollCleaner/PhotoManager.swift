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
        let options = PHFetchOptions()
        
        // Sort by creation date (newest first)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        // Note: PHFetchResult doesn't have a "limit" property,
        // but we can limit our iteration later.
        // However, we can set a fetch limit to save memory:
        options.fetchLimit = 50

        let allPhotos = PHAsset.fetchAssets(with: .image, options: options)
        
        self.photoCount = allPhotos.count
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
