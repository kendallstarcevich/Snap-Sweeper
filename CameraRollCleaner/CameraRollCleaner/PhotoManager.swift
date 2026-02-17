import Photos
import SwiftUI
import Combine

class PhotoManager: ObservableObject {
    @Published var photoCount = 0
    @Published var screenshotCount = 0
    @Published var isAuthorized = false
    @Published var screenshotAssets: [PHAsset] = [] // Holds the actual photo objects
    
    func deleteAssets(ids: Set<String>, completion: @escaping (Bool) -> Void) {
        // 1. Fetch the actual objects using the IDs
        let assetsToDelete = PHAsset.fetchAssets(withLocalIdentifiers: Array(ids), options: nil)
        
        // 2. Ask the system to perform the change
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(assetsToDelete)
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    // 3. Refresh our local data so the deleted photos disappear
                    self.fetchMetadata()
                    completion(true)
                } else {
                    print("Error deleting: \(String(describing: error))")
                    completion(false)
                }
            }
        }
    }
    
    // Add this to your PhotoManager class
    func getSize(for asset: PHAsset) -> Int64 {
        let resources = PHAssetResource.assetResources(for: asset)
        return resources.first?.value(forKey: "fileSize") as? Int64 ?? 0
    }

    func sortAssets(by strategy: SortStrategy) {
        switch strategy {
        case .oldest:
            screenshotAssets.sort { ($0.creationDate ?? Date()) < ($1.creationDate ?? Date()) }
        case .largest:
            screenshotAssets.sort { getSize(for: $0) > getSize(for: $1) }
        case .newest:
            screenshotAssets.sort { ($0.creationDate ?? Date()) > ($1.creationDate ?? Date()) }
        }
    }

    enum SortStrategy: String, CaseIterable {
        case newest = "Newest First"
        case oldest = "Oldest First"
        case largest = "Largest Size"
    }

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
