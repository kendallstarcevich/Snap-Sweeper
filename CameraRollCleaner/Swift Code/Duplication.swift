import SwiftUI
import Vision
import Photos

func computeSimilarity(asset1: PHAsset, asset2: PHAsset, completion: @escaping (Float) -> Void) {
    let manager = PHImageManager.default()
    let options = PHImageRequestOptions()
    options.isSynchronous = true
    options.deliveryMode = .fastFormat // Use fast format for analysis speed
    
    manager.requestImage(for: asset1, targetSize: CGSize(width: 224, height: 224), contentMode: .aspectFill, options: options) { img1, _ in
        manager.requestImage(for: asset2, targetSize: CGSize(width: 224, height: 224), contentMode: .aspectFill, options: options) { img2, _ in
            
            // Ensure both images exist and have underlying CGImages
            guard let cg1 = img1?.cgImage, let cg2 = img2?.cgImage else { return }
            
            let requestHandler1 = VNImageRequestHandler(cgImage: cg1, options: [:])
            let requestHandler2 = VNImageRequestHandler(cgImage: cg2, options: [:])
            
            let request1 = VNGenerateImageFeaturePrintRequest()
            let request2 = VNGenerateImageFeaturePrintRequest()
            
            do {
                try requestHandler1.perform([request1])
                try requestHandler2.perform([request2])
                
                if let fp1 = request1.results?.first as? VNFeaturePrintObservation,
                   let fp2 = request2.results?.first as? VNFeaturePrintObservation {
                    var distance: Float = 0
                    try fp1.computeDistance(&distance, to: fp2)
                    completion(distance)
                }
            } catch {
                print("Vision error: \(error)")
            }
        }
    }
}
