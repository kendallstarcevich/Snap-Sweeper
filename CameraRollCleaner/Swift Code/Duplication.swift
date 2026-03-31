import SwiftUI
import Vision
import Photos

func computeSimilarity(asset1: PHAsset, asset2: PHAsset, completion: @escaping (Float) -> Void) {
    let manager = PHImageManager.default()
    let requestOptions = PHImageRequestOptions()
    
    requestOptions.isSynchronous = false // Change to false for better stability
    requestOptions.isNetworkAccessAllowed = true // Critical for missing resources
    requestOptions.deliveryMode = .highQualityFormat // Force it to find the real file
    
    manager.requestImage(for: asset1, targetSize: CGSize(width: 224, height: 224), contentMode: .aspectFill, options: requestOptions) { img1, _ in
        manager.requestImage(for: asset2, targetSize: CGSize(width: 224, height: 224), contentMode: .aspectFill, options: requestOptions) { img2, _ in
            
            // If the simulator fails to provide an image, we MUST exit early to avoid Vision crashes
            guard let ui1 = img1, let ui2 = img2,
                  let cg1 = ui1.cgImage, let cg2 = ui2.cgImage else {
                print("DEBUG: Image data missing for assets - skipping pair")
                completion(100.0)
                return
            }
            
            let requestHandler1 = VNImageRequestHandler(cgImage: cg1, options: [:])
            let requestHandler2 = VNImageRequestHandler(cgImage: cg2, options: [:])
            
            let request1 = VNGenerateImageFeaturePrintRequest()
            let request2 = VNGenerateImageFeaturePrintRequest()
            
            request1.revision = VNGenerateImageFeaturePrintRequestRevision1
            request2.revision = VNGenerateImageFeaturePrintRequestRevision1
            request1.usesCPUOnly = true
            request2.usesCPUOnly = true
            
            do {
                try requestHandler1.perform([request1])
                try requestHandler2.perform([request2])
                
                if let fp1 = request1.results?.first as? VNFeaturePrintObservation,
                   let fp2 = request2.results?.first as? VNFeaturePrintObservation {
                    var distance: Float = 0
                    try fp1.computeDistance(&distance, to: fp2)
                    print("SIMILARITY LOG: Found match with distance \(distance)")
                    completion(distance)
                }
            } catch {
                completion(100.0)
            }
        }
    }
}
