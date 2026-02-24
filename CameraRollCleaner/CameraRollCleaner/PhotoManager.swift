import Photos
import SwiftUI
import Combine

class PhotoManager: ObservableObject {
    @Published var photoCount = 0
    @Published var screenshotCount = 0
    @Published var isAuthorized = false
    @Published var screenshotAssets: [PHAsset] = []
    
    // Use UserDefaults for persistence in a Class
    @Published var totalBytesDeleted: Int64 = UserDefaults.standard.value(forKey: "bytesDeleted") as? Int64 ?? 0

    enum SortStrategy: String, CaseIterable {
        case newest = "Newest First"
        case oldest = "Oldest First"
        case largest = "Largest Size"
    }

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

    func requestAccessAndFetch() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            if status == .authorized {
                DispatchQueue.main.async {
                    self.isAuthorized = true
                    self.fetchMetadata()
                }
            }
        }
    }

    func fetchMetadata() {
        let allPhotos = PHAsset.fetchAssets(with: .image, options: nil)
        self.photoCount = allPhotos.count

        let screenshotOptions = PHFetchOptions()
        screenshotOptions.predicate = NSPredicate(format: "mediaSubtype == %d", PHAssetMediaSubtype.photoScreenshot.rawValue)
        let results = PHAsset.fetchAssets(with: .image, options: screenshotOptions)
        
        var tempAssets: [PHAsset] = []
        results.enumerateObjects { (asset, _, _) in tempAssets.append(asset) }
        
        self.screenshotAssets = tempAssets
        self.screenshotCount = tempAssets.count
        self.sortAssets(by: .newest)
    }

    func deleteAssets(ids: Set<String>, completion: @escaping (Bool) -> Void) {
        // 1. Fetch the assets first
        let assetsToDelete = PHAsset.fetchAssets(withLocalIdentifiers: Array(ids), options: nil)
        
        // 2. Calculate the size of what we are about to delete
        var sizeOfDeletion: Int64 = 0
        assetsToDelete.enumerateObjects { (asset, _, _) in
            sizeOfDeletion += self.getSize(for: asset)
        }
        
        // 3. Perform the system change
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(assetsToDelete)
        }) { success, _ in
            DispatchQueue.main.async {
                if success {
                    // Update our lifetime deleted stat
                    self.totalBytesDeleted += sizeOfDeletion
                    UserDefaults.standard.set(self.totalBytesDeleted, forKey: "bytesDeleted")
                    
                    self.fetchMetadata()
                    completion(true)
                } else {
                    completion(false)
                }
            }
        }
    }
}
