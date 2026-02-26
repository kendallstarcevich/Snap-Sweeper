import Photos
import SwiftUI
import Combine

class PhotoManager: ObservableObject {
    @Published var photoCount = 0
    @Published var screenshotCount = 0
    @Published var isAuthorized = false
    @Published var screenshotAssets: [PHAsset] = []
    @Published var protectedAssets: [PHAsset] = []
    
    // Use UserDefaults for persistence in a Class
    @Published var totalBytesDeleted: Int64 = UserDefaults.standard.value(forKey: "bytesDeleted") as? Int64 ?? 0
    
    @Published var protectedAssetIDs: Set<String> = {
            let saved = UserDefaults.standard.stringArray(forKey: "protectedAssets") ?? []
            return Set(saved)
        }()

        // NEW: Function to protect/unprotect a photo
        func toggleProtection(id: String) {
            if protectedAssetIDs.contains(id) {
                protectedAssetIDs.remove(id)
            } else {
                protectedAssetIDs.insert(id)
            }
            // Save to disk immediately
            UserDefaults.standard.set(Array(protectedAssetIDs), forKey: "protectedAssets")
            
            // REFRESH: This is the "AI" part—re-run the scan to hide the protected photo
            fetchMetadata()
        }
    
    enum SortStrategy: String, CaseIterable {
        case newest = "Newest First"
        case oldest = "Oldest First"
        case largest = "Largest Size"
    }
    
    func fetchProtectedAssets() {
        let options = PHFetchOptions()
        let results = PHAsset.fetchAssets(withLocalIdentifiers: Array(self.protectedAssetIDs), options: options)
        
        var temp: [PHAsset] = []
        var validIDs: Set<String> = []
        
        results.enumerateObjects { (asset, _, _) in
            temp.append(asset)
            validIDs.insert(asset.localIdentifier)
        }
        
        // THE FIX: If our count of real photos is less than our saved IDs,
        // it means some photos were deleted outside the app or ghosted.
        if validIDs.count != protectedAssetIDs.count {
            self.protectedAssetIDs = validIDs
            UserDefaults.standard.set(Array(self.protectedAssetIDs), forKey: "protectedAssets")
        }

        self.protectedAssets = temp
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
                    self.fetchProtectedAssets() // Add this here!
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
        
        var tempReviewAssets: [PHAsset] = []
        
        results.enumerateObjects { (asset, _, _) in
            // IF it is NOT protected, put it in the Review list
            if !self.protectedAssetIDs.contains(asset.localIdentifier) {
                tempReviewAssets.append(asset)
            }
        }
        
        self.screenshotAssets = tempReviewAssets
        self.screenshotCount = tempReviewAssets.count
        self.sortAssets(by: .newest)
    }

    func deleteAssets(ids: Set<String>, completion: @escaping (Bool) -> Void) {
        let assetsToDelete = PHAsset.fetchAssets(withLocalIdentifiers: Array(ids), options: nil)
        
        var sizeOfDeletion: Int64 = 0
        assetsToDelete.enumerateObjects { (asset, _, _) in
            sizeOfDeletion += self.getSize(for: asset)
        }
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(assetsToDelete)
        }) { success, _ in
            DispatchQueue.main.async {
                if success {
                    // 1. Update the lifetime stats
                    self.totalBytesDeleted += sizeOfDeletion
                    UserDefaults.standard.set(self.totalBytesDeleted, forKey: "bytesDeleted")
                    
                    // 2. Clean up the protected IDs set
                    // This removes the deleted IDs from your "Do Not Delete" list
                    for id in ids {
                        self.protectedAssetIDs.remove(id)
                    }
                    UserDefaults.standard.set(Array(self.protectedAssetIDs), forKey: "protectedAssets")
                    
                    // 3. REFRESH BOTH LISTS
                    self.fetchMetadata()          // Refreshes the Screenshot Review
                    self.fetchProtectedAssets()   // Refreshes the "Do Not Delete" Vault
                    
                    completion(true)
                } else {
                    completion(false)
                }
            }
        }
    }
}
