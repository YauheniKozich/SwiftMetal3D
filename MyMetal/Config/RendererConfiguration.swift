//
//  RendererConfiguration.swift
//  MyMetal
//
//  Created by Yauheni Kozich on 21.10.25.
//

import Foundation

// MARK: - Renderer Configuration
struct RendererConfiguration {
    
    struct Shaders {
        static let vertex = "vertex_main"
        static let fragment = "fragment_main"
    }
    
    struct Rotation {
        static let sensitivity: Float = 0.005
        static let dampingFactor: Float = 0.95
        static let minVelocity: Float = 0.0001
        static let autoRotateSpeed: Float = 0.3
    }
    
    struct Geometry {
        static let cubeSize: Float = 0.5
        static let cameraDistance: Float = 2.0
        static let nearZ: Float = 0.1
        static let farZ: Float = 100.0
        static let fieldOfView: Float = .pi / 4
    }
    
    struct Performance {
        static let targetFrameTime: Float = 1.0 / 120.0
        static let textureSize = 256
    }
    
    struct Resources {
        static let textureName = "texture"
        static let textureExtension = "png"
    }
}
