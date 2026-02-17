import Photos
import SwiftUI
import Combine

class PhotoManager: ObservableObject {
    @Published var photoCount = 0
    @Published var screenshotCount = 0
    @Published var isAuthorized = false
    @Published var screenshotAssets: [PHAsset] = [] // Holds the actual photo objects

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
        // Fetch all photos to get the total count
        let allPhotos = PHAsset.fetchAssets(with: .image, options: nil)
        self.photoCount = allPhotos.count

        // Setup options to specifically find screenshots
        let screenshotOptions = PHFetchOptions()
        screenshotOptions.predicate = NSPredicate(format: "mediaSubtype == %d", PHAssetMediaSubtype.photoScreenshot.rawValue)
        
        let results = PHAsset.fetchAssets(with: .image, options: screenshotOptions)
        
        // Convert the "FetchResult" into a standard Swift Array so the UI can use it easily
        var tempAssets: [PHAsset] = []
        results.enumerateObjects { (asset, _, _) in
            tempAssets.append(asset)
        }

        self.screenshotAssets = tempAssets
        self.screenshotCount = tempAssets.count
    }
}
// DO NOT PUT THE PHOTO THUMBNAIL STRUCT INSIDE THE CLASS ABOVE
