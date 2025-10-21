//
//  MetalErrors.swift
//  MyMetal
//
//  Created by Yauheni Kozich on 21.10.25.
//

import Foundation

// MARK: - MetalError
enum MetalError: Error, CustomStringConvertible {
    case deviceNotFound, commandQueueCreationFailed, libraryCreationFailed
    case shaderFunctionNotFound(String)
    case pipelineCreationFailed(String), textureCreationFailed
    case bufferCreationFailed, samplerCreationFailed
    
    var localizedDescription: String {
        switch self {
        case .deviceNotFound: return "Metal device not available"
        case .commandQueueCreationFailed: return "Failed to create command queue"
        case .libraryCreationFailed: return "Failed to create Metal library"
        case .shaderFunctionNotFound(let name): return "Shader function '\(name)' not found"
        case .pipelineCreationFailed(let details): return "Pipeline creation failed: \(details)"
        case .textureCreationFailed: return "Failed to create texture"
        case .bufferCreationFailed: return "Failed to create buffer"
        case .samplerCreationFailed: return "Failed to create sampler"
        }
    }
    
    var description: String { localizedDescription }
}
