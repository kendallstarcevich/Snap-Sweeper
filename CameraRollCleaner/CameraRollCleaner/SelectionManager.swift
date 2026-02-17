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
