//
//  BlurModelManager.swift
//  Snap Sweeper
//
//  Created by Carla Segura on 3/26/26.

import SwiftUI
import CoreML
import UIKit

final class BlurModelManager {
    
    private let model: BlurRegressorMobileNetV3?
    
    init() {
        let config = MLModelConfiguration()
        self.model = try? BlurRegressorMobileNetV3(configuration: config)
    }
    
    func predictBlurScore(from image: UIImage) -> Double? {
        guard let model = model,
              let resizedImage = image.resized(to: CGSize(width: 224, height: 224)),
              let multiArray = resizedImage.toMLMultiArray() else {
            return nil
        }


        let prediction = try? model.prediction(image: multiArray)
        return prediction?.var_765[0].doubleValue
    }

}



