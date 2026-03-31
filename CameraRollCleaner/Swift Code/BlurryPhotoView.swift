//
//  BlurryPhotoView.swift
//  Snap Sweeper
//
//  Created by Carla Segura on 3/26/26.
//  Description: Displays the blurry photo scan screen in the app.
//  Fetches images from PhotoManager, runs the blur model on each image,
//  and shows the results sorted by blur score.
//  This connects the UI with the ML model and photo data.


import SwiftUI
import Photos

// Stores blur scan result so we can show the image and its score in the UI
struct BlurryResult: Identifiable {
   let id = UUID()
   let asset: PHAsset
   let score: Double
   let image: UIImage
}

struct BlurryPhotosView: View {
   @ObservedObject var photoManager: PhotoManager
   @State private var results: [BlurryResult] = []
   @State private var isScanning = false
  
   private let blurManager = BlurModelManager()
   private let imageManager = PHCachingImageManager()
  
   var body: some View {
       ScrollView {
           VStack(spacing: 20) {
               Text("Blurry Photos")
                   .font(.largeTitle)
                   .bold()
              
               // Button starts a blur scan on a small set of images
               // Right now this is meant as a working prototype, not a full-library scan
               Button(action: {
                   scanPhotos()
               }) {
                   Text(isScanning ? "Scanning..." : "Scan Library Photos")
                       .fontWeight(.semibold)
                       .padding()
                       .frame(maxWidth: .infinity)
                       .background(Color.orange)
                       .foregroundColor(.white)
                       .cornerRadius(12)
               }
               .disabled(isScanning)
              
               if results.isEmpty && !isScanning {
                   Text("No blurry scan results yet")
                       .foregroundColor(.secondary)
               }
               // Show the scan results sorted by blur score
               // Higher score = blurrier image
               ForEach(results) { result in
                   VStack(alignment: .leading, spacing: 10) {
                       Image(uiImage: result.image)
                           .resizable()
                           .scaledToFit()
                           .frame(maxWidth: .infinity)
                           .cornerRadius(12)
                      
                       Text("Blur Score: \(result.score, specifier: "%.3f")")
                           .font(.headline)
                      
                       Text(label(for: result.score))
                           .font(.subheadline)
                           .foregroundColor(.orange)
                   }
                   .padding()
                   .background(Color(.systemGray6))
                   .cornerRadius(14)
               }
           }
           .padding()
       }
       .onAppear {
           // If the app has not fetched photos yet, fetch them when this screen opens
           if photoManager.allPhotoAssets.isEmpty {
               photoManager.fetchAllPhotos()
           }
       }
   }
    // Converts the model score into a user-friendly label
    // Temporary thresholds and could be adjusted later after testing
   private func label(for score: Double) -> String {
       if score >= 0.75 {
           return "This image appears blurry"
       } else if score >= 0.50 {
           return "This image might be slightly blurry"
       } else {
           return "This image appears sharp"
       }
   }
  
   private func scanPhotos() {
       isScanning = true
       results.removeAll()
      
       //scanning small amounts of photos for now. Starting with 10
       let assetsToScan = Array(photoManager.allPhotoAssets.prefix(10))
      
       let requestOptions = PHImageRequestOptions()
       requestOptions.isSynchronous = true
       requestOptions.deliveryMode = .highQualityFormat
       requestOptions.resizeMode = .exact
      
       var scannedResults: [BlurryResult] = []
      
       for asset in assetsToScan {
           let targetSize = CGSize(width: 224, height: 224)
          
           imageManager.requestImage(
               for: asset,
               targetSize: targetSize,
               contentMode: .aspectFill,
               options: requestOptions
           ) { image, _ in
               guard let image = image,
                     let score = blurManager.predictBlurScore(from: image) else {
                   return
               }
              
               scannedResults.append(
                   BlurryResult(asset: asset, score: score, image: image)
               )
           }
       }
       // Show blurriest images first
       scannedResults.sort { $0.score > $1.score }
      
       results = scannedResults
       // Temporary count used by the dashboard card
       // Right now "blurry" means score >= 0.75
       photoManager.blurryCount = scannedResults.filter { $0.score >= 0.75 }.count
       isScanning = false
   }
}


