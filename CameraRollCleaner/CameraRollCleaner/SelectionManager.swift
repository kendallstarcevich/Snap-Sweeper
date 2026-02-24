import SwiftUI
import Photos
import Combine

class SelectionManager: ObservableObject {
    @Published var selectedAssetIDs: Set<String> = []
    
    func selectAll(assets: [PHAsset]) {
        selectedAssetIDs = Set(assets.map { $0.localIdentifier })
    }
    
    func deselectAll() {
        selectedAssetIDs.removeAll()
    }
    
    func toggleSelection(id: String) {
        if selectedAssetIDs.contains(id) {
            selectedAssetIDs.remove(id)
        } else {
            selectedAssetIDs.insert(id)
        }
    }

    func calculateTotalSize(assets: [PHAsset]) -> Int64 {
        let selectedAssets = assets.filter { selectedAssetIDs.contains($0.localIdentifier) }
        var totalBytes: Int64 = 0
        for asset in selectedAssets {
            let resources = PHAssetResource.assetResources(for: asset)
            if let size = resources.first?.value(forKey: "fileSize") as? Int64 {
                totalBytes += size
            }
        }
        return totalBytes
    }
}
