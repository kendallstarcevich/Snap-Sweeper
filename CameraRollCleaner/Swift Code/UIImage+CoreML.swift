//
//  UIImage+CoreML.swift
//  Snap Sweeper
//
//  Created by Carla Segura on 3/26/26.
//  Description: Converts UIImage into a format the CoreML model can understand.
//  Handles resizing (224x224) and transforms pixel data into an MLMultiArray (numerical input).


import UIKit
import CoreML

extension UIImage {
    
    // Resize image to 224x224
    func resized(to targetSize: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
    
    // This transforms image pixels into numerical data the model can understand
    func toMLMultiArray() -> MLMultiArray? {
        guard let cgImage = self.cgImage else { return nil }
        
        let width = 224
        let height = 224
        
        // Create an empty MLMultiArray to hold pixel data
            // 1 = batch size
            // 3 = RGB channels
            // 224x224 = image size
        guard let array = try? MLMultiArray(shape: [1, 3, 224, 224], dataType: .float32) else {
            return nil
        }
        
        // Turn the image into raw pixel values (R, G, B, A)
        // We draw the image into a temporary array in memory  so we can read each pixel as numbers
        // This step converts the image into a format the ML model understands
        guard let colorSpace = cgImage.colorSpace else { return nil }
        
        let bytesPerPixel = 4// RGBA (Alpha/transparency)
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        // Raw pixel buffer (stores image data)
        var rawData = [UInt8](repeating: 0, count: height * width * bytesPerPixel)
        
        // Create a graphics context to draw the image into rawData
        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Get pointer to MLMultiArray memory
        let ptr = UnsafeMutablePointer<Float32>(OpaquePointer(array.dataPointer))
        
        // Shape is [1, 3, 224, 224]
        // Flattened index:
        // channel 0 = R, channel 1 = G, channel 2 = B
        let channelSize = width * height
        
        // Loop through every pixel
        for y in 0..<height {
            for x in 0..<width {
                // Find position in raw pixel array
                let pixelIndex = (y * width + x) * bytesPerPixel
                
                // Extract RGB values and normalize to [0, 1]
                let r = Float32(rawData[pixelIndex]) / 255.0
                let g = Float32(rawData[pixelIndex + 1]) / 255.0
                let b = Float32(rawData[pixelIndex + 2]) / 255.0
                
                // Flattened index for this pixel
                let flatIndex = y * width + x
                
                // Store values in MLMultiArray:
                // Channel 0 = Red
                // Channel 1 = Green
                // Channel 2 = Blue
                ptr[flatIndex] = r
                ptr[channelSize + flatIndex] = g
                ptr[(2 * channelSize) + flatIndex] = b
            }
        }
        
        return array
    }
}


