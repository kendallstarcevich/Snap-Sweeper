import SwiftUI
import Photos
import Combine

class SelectionManager: ObservableObject {
    // We store the IDs of the photos selected for deletion
    @Published var selectedAssetIDs: Set<String> = []
    
    // 1. Function to Select All
    func selectAll(assets: [PHAsset]) {
        let allIDs = assets.map { $0.localIdentifier }
        selectedAssetIDs = Set(allIDs)
    }
    
    // 2. Function to Deselect All
    func deselectAll() {
        selectedAssetIDs.removeAll()
    }
    
    // 3. Toggle a single photo
    func toggleSelection(id: String) {
        if selectedAssetIDs.contains(id) {
            selectedAssetIDs.remove(id)
        } else {
            selectedAssetIDs.insert(id)
        }
    }
}


extension SelectionManager {
    func calculateTotalSize(assets: [PHAsset]) -> Int64 {
        let selectedAssets = assets.filter { selectedAssetIDs.contains($0.localIdentifier) }
        var totalBytes: Int64 = 0
        
        for asset in selectedAssets {
            let resources = PHAssetResource.assetResources(for: asset)
            for resource in resources {
                if let unsignedBytes = resource.value(forKey: "fileSize") as? Int64 {
                    totalBytes += unsignedBytes
                }
            }
        }
        return totalBytes
    }
}
