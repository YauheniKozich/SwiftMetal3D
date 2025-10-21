//
//  ContentView.swift
//  MyMetal
//
//  Created by Yauheni Kozich on 29.10.24.
//

import SwiftUI
import MetalKit

/// SwiftUI view для отображения Metal-рендеринга куба
struct CubeMetalView: UIViewRepresentable {
    /// Sensitivity for converting pan distance -> rotation angle (radians per point)
    var rotationSensitivity: Float = 0.005

    /// Sensitivity for converting pan velocity -> impulse rotation (radians per point/second)
    var velocitySensitivity: Float = 0.0001
    
    // MARK: - UIViewRepresentable Implementation
    
    /// Создание MTKView для Metal рендеринга
    /// - Parameter context: Контекст SwiftUI
    /// - Returns: Настроенный MTKView
    func makeUIView(context: Context) -> MTKView {
        print("🚀 Creating Metal view...")
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("❌ Metal is not supported on this device")
            fatalError("Metal is not supported on this device")
        }
        
        print("✅ Metal device created: \(device.name)")

        let metalView = MTKView(frame: .zero, device: device)
        
    // Добавляем распознаватель жестов
    let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(CoordinatorWrapper.handlePan(_:)))
        metalView.addGestureRecognizer(panGesture)

    // Передаём чувствительность координатору
    context.coordinator.rotationSensitivity = rotationSensitivity
    context.coordinator.velocitySensitivity = velocitySensitivity
        
        do {
            configureMetalView(metalView)
            print("✅ Metal view configured")
            
            try setupRenderer(for: metalView, context: context)
            print("✅ Renderer setup complete")
        } catch {
            print("❌ Error during setup: \(error)")
            fatalError("Setup failed: \(error)")
        }

        print("✅ Metal view setup complete")
        return metalView
    }

    /// Обновление view (не требуется для Metal рендеринга)
    /// - Parameters:
    ///   - uiView: MTKView для обновления
    ///   - context: Контекст SwiftUI
    func updateUIView(_ uiView: MTKView, context: Context) {
        // Обновляем чувствительность координатора при каждом изменении
        context.coordinator.rotationSensitivity = rotationSensitivity
        context.coordinator.velocitySensitivity = velocitySensitivity
    }

    /// Создание координатора для управления renderer'ом
    /// - Returns: CoordinatorWrapper для хранения renderer'а
    func makeCoordinator() -> CoordinatorWrapper {
        return CoordinatorWrapper()
    }
    
    // MARK: - Private Methods
    
    /// Настройка Metal view
    /// - Parameter metalView: MTKView для настройки
    private func configureMetalView(_ metalView: MTKView) {
        metalView.clearColor = MTLClearColorMake(0.1, 0.1, 0.1, 1.0)
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.depthStencilPixelFormat = .depth32Float
        metalView.preferredFramesPerSecond = 120
        metalView.enableSetNeedsDisplay = false // Автоматический рендеринг
    }
    
    /// Настройка renderer'а для Metal view
    /// - Parameters:
    ///   - metalView: MTKView для рендеринга
    ///   - context: Контекст SwiftUI
    private func setupRenderer(for metalView: MTKView, context: Context) throws {
        print("🔧 Setting up renderer...")
        
        do {
            let renderer = try CubeRenderer(metalView: metalView)
            print("✅ Renderer created")
            
            metalView.delegate = renderer
            print("✅ Delegate set")
            
            context.coordinator.renderer = renderer
            print("✅ Coordinator updated")
        } catch {
            print("❌ Renderer setup failed: \(error)")
            throw error
        }
    }
}



// MARK: - Coordinator

/// Координатор для управления Metal renderer'ом
class CoordinatorWrapper {
    /// Renderer для Metal рендеринга
    var renderer: CubeRenderer!
    private var lastPanLocation: CGPoint = .zero
    /// Sensitivity configurable from the SwiftUI wrapper
    var rotationSensitivity: Float = 0.005
    var velocitySensitivity: Float = 0.0001
    
    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            lastPanLocation = gesture.location(in: gesture.view)
            
        case .changed:
            let currentLocation = gesture.location(in: gesture.view)
            let delta = CGPoint(
                x: currentLocation.x - lastPanLocation.x,
                y: currentLocation.y - lastPanLocation.y
            )
            
            // Преобразуем движение в углы поворота с настраиваемой чувствительностью
            let deltaX = Float(delta.x) * rotationSensitivity
            let deltaY = Float(delta.y) * rotationSensitivity

            renderer.rotateX(deltaY)
            renderer.rotateY(deltaX)
            
            lastPanLocation = currentLocation
            
        case .ended:
            // Получаем финальную скорость движения пальца для инерции
            let velocity = gesture.velocity(in: gesture.view)

            // Масштаб для преобразования скорости пальца в импульс вращения
            renderer.rotateX(Float(velocity.y) * velocitySensitivity)
            renderer.rotateY(Float(velocity.x) * velocitySensitivity)
            
        default:
            break
        }
    }
    
    deinit {
        // Очистка ресурсов при деинициализации
        renderer?.cleanupResources()  // Добавим метод очистки
        renderer = nil
    }
}
