//
//  SimpleMetalView.swift
//  MyMetal
//
//  Created by Yauheni Kozich on 29.10.24.
//

import SwiftUI
import MetalKit

/// Простая версия Metal view для тестирования
struct SimpleMetalView: UIViewRepresentable {
    
    class Coordinator {
        let renderer: SimpleRenderer
        init(renderer: SimpleRenderer) { self.renderer = renderer }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(renderer: SimpleRenderer())
    }
    
    func makeUIView(context: Context) -> MTKView {
        print("🚀 Creating simple Metal view...")
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        
        print("✅ Metal device: \(device.name)")
        
        let metalView = MTKView(frame: .zero, device: device)
        metalView.clearColor = MTLClearColorMake(0.2, 0.3, 0.4, 1.0)
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.enableSetNeedsDisplay = false
        
        // Простой delegate для тестирования
        metalView.delegate = context.coordinator.renderer
        
        print("✅ Simple Metal view created")
        return metalView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {}
}

/// Простой renderer для тестирования
class SimpleRenderer: NSObject, MTKViewDelegate {
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor else { return }
        
        descriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.2, 0.3, 0.4, 1.0)
        
        guard let commandBuffer = view.device?.makeCommandQueue()?.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }
        
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
}
