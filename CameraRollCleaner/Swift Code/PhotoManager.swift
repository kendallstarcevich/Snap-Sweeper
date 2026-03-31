import Photos
import SwiftUI
import Combine

class PhotoManager: ObservableObject {
    @Published var photoCount = 0
    @Published var screenshotCount = 0
    @Published var isAuthorized = false
    @Published var screenshotAssets: [PHAsset] = []
    @Published var protectedAssets: [PHAsset] = []
    @Published var videoAssets: [PHAsset] = []
    @Published var videoCount = 0
    @Published var allPhotoAssets: [PHAsset] = []
    @Published var blurryCount: Int = 0

    func fetchAllPhotos() {
       var assets: [PHAsset] = []
      
       let options = PHFetchOptions()
       options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
      
       let result = PHAsset.fetchAssets(with: .image, options: options)
       result.enumerateObjects { asset, _, _ in
           assets.append(asset)
       }
      
       DispatchQueue.main.async {
           self.allPhotoAssets = assets
       }
    }
    
    @Published var totalBytesDeleted: Int64 = UserDefaults.standard.value(forKey: "bytesDeleted") as? Int64 ?? 0
    
    @Published var protectedAssetIDs: Set<String> = {
        let saved = UserDefaults.standard.stringArray(forKey: "protectedAssets") ?? []
        return Set(saved)
    }()

    enum SortStrategy: String, CaseIterable {
        case newest = "Newest First"
        case oldest = "Oldest First"
        case largest = "Largest Size"
    }

    func sortVault(by strategy: SortStrategy) {
        switch strategy {
        case .oldest:
            protectedAssets.sort { ($0.creationDate ?? Date()) < ($1.creationDate ?? Date()) }
        case .largest:
            protectedAssets.sort { getSize(for: $0) > getSize(for: $1) }
        case .newest:
            protectedAssets.sort { ($0.creationDate ?? Date()) > ($1.creationDate ?? Date()) }
        }
    }
    
    func toggleProtection(id: String) {
        if protectedAssetIDs.contains(id) {
            protectedAssetIDs.remove(id)
        } else {
            protectedAssetIDs.insert(id)
        }
        UserDefaults.standard.set(Array(protectedAssetIDs), forKey: "protectedAssets")
        fetchMetadata()
        fetchProtectedAssets()
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
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                // Fetch everything
                let allPhotos = PHAsset.fetchAssets(with: .image, options: nil)
                var tempAll: [PHAsset] = []
                allPhotos.enumerateObjects { (asset, _, _) in
                    tempAll.append(asset)
                }
                
                DispatchQueue.main.async {
                    self.allPhotosAssets = tempAll
                    self.fetchMetadata()
                    self.fetchProtectedAssets()
                    self.fetchVideos()
                    self.fetchAllPhotos()
                }
            }
        }
    }
    
    // Inside PhotoManager class:

    // Stores the threshold in seconds (default to 120s / 2 minutes)
    @AppStorage("videoThreshold") var videoThreshold: Double = 120

    func fetchVideos() {
        let videoOptions = PHFetchOptions()
        
        // Use the dynamic threshold from the user's settings
        videoOptions.predicate = NSPredicate(format: "mediaType = %d AND duration > %f",
                                             PHAssetMediaType.video.rawValue,
                                             videoThreshold)
        
        let results = PHAsset.fetchAssets(with: .video, options: videoOptions)
        
        var tempVideos: [PHAsset] = []
        results.enumerateObjects { (asset, _, _) in
            if !self.protectedAssetIDs.contains(asset.localIdentifier) {
                tempVideos.append(asset)
            }
        }
        self.videoAssets = tempVideos
        self.videoCount = tempVideos.count
    }

    func sortVideos(by strategy: SortStrategy) {
        switch strategy {
        case .largest:
            videoAssets.sort { getSize(for: $0) > getSize(for: $1) }
        case .oldest:
            videoAssets.sort { ($0.creationDate ?? Date()) < ($1.creationDate ?? Date()) }
        case .newest:
            videoAssets.sort { ($0.creationDate ?? Date()) > ($1.creationDate ?? Date()) }
        }
    }
    
    @Published var duplicateGroups: [[PHAsset]] = []
    @Published var allPhotosAssets: [PHAsset] = []
    
    
    func scanForDuplicates() {
        // 1. Move the whole operation to a background thread so the UI doesn't freeze
        DispatchQueue.global(qos: .userInitiated).async {
            let allAssets = self.allPhotosAssets.filter { !self.protectedAssetIDs.contains($0.localIdentifier) }
            print("SCAN DEBUG: Total photos in pool: \(allAssets.count)")
            
            var groups: [[PHAsset]] = []
            var processedIDs = Set<String>()
            let sorted = allAssets.sorted { ($0.creationDate ?? Date()) < ($1.creationDate ?? Date()) }
            
            let dispatchGroup = DispatchGroup()

            for i in 0..<sorted.count {
                let rootAsset = sorted[i]
                if processedIDs.contains(rootAsset.localIdentifier) { continue }
                
                var currentGroup: [PHAsset] = [rootAsset]
                
                for j in i+1..<sorted.count {
                    let comparisonAsset = sorted[j]
                    if processedIDs.contains(comparisonAsset.localIdentifier) { continue }
                    
                    let timeGap = comparisonAsset.creationDate!.timeIntervalSince(rootAsset.creationDate!)
                    if timeGap > 600 { break }
                    
                    dispatchGroup.enter()
                    computeSimilarity(asset1: rootAsset, asset2: comparisonAsset) { distance in
                        if distance < 25.0 {
                            currentGroup.append(comparisonAsset)
                            processedIDs.insert(comparisonAsset.localIdentifier)
                        }
                        dispatchGroup.leave()
                    }
                }
                
                // This waits on the BACKGROUND thread, so the UI stays smooth
                dispatchGroup.wait()
                
                if currentGroup.count > 1 {
                    groups.append(currentGroup)
                    processedIDs.insert(rootAsset.localIdentifier)
                }
            }
            
            // 2. Switch back to the Main Thread ONLY to update the UI
            DispatchQueue.main.async {
                print("SCAN COMPLETE: Found \(groups.count) groups")
                self.duplicateGroups = groups
                // Give the user a haptic "thump" to let them know the scan finished
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }
    
    func fetchMetadata() {
        let allPhotos = PHAsset.fetchAssets(with: .image, options: nil)
        self.photoCount = allPhotos.count
        
        var tempAll: [PHAsset] = []
        
        allPhotos.enumerateObjects { (asset, _, _) in
            tempAll.append(asset)
        }
        self.allPhotosAssets = tempAll


        let screenshotOptions = PHFetchOptions()
        screenshotOptions.predicate = NSPredicate(format: "mediaSubtype == %d", PHAssetMediaSubtype.photoScreenshot.rawValue)
        let results = PHAsset.fetchAssets(with: .image, options: screenshotOptions)
        
        var tempReviewAssets: [PHAsset] = []
        results.enumerateObjects { (asset, _, _) in
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
                    self.totalBytesDeleted += sizeOfDeletion
                    UserDefaults.standard.set(self.totalBytesDeleted, forKey: "bytesDeleted")
                    for id in ids { self.protectedAssetIDs.remove(id) }
                    UserDefaults.standard.set(Array(self.protectedAssetIDs), forKey: "protectedAssets")
                    self.fetchMetadata()
                    self.fetchProtectedAssets()
                    self.fetchVideos()
                    completion(true)
                } else {
                    completion(false)
                }
            }
        }
    }
}
