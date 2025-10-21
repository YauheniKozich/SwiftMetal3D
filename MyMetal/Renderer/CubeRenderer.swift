//
//  CubeRenderer.swift
//  MyMetal
//
//  Created by Yauheni Kozich on 21.10.25.
//

import SwiftUI
import Metal
import MetalKit

// MARK: - Cube Renderer
final class CubeRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState!
    private var depthStencilState: MTLDepthStencilState!
    private var vertexBuffer: MTLBuffer?
    private var indexBuffer: MTLBuffer?
    private var colorBuffer: MTLBuffer?
    private var samplerState: MTLSamplerState?
    // Texture is now lazy and will be (re)loaded on demand
    private var _texture: MTLTexture?
    private var textureNeedsUpdate: Bool = true

    // Shader function cache
    private let vertexFunction: MTLFunction
    private let fragmentFunction: MTLFunction

    private var rotationX: Float = 0
    private var rotationY: Float = 0
    private var rotationZ: Float = 0
    private var velocityX: Float = 0
    private var velocityY: Float = 0
    private var autoRotate = true

    private var lastUpdateTime: CFTimeInterval = 0
    private var deltaTime: Float = 0

    private var lastAspect: Float = 0
    private var cachedProjMatrix: float4x4?
    private lazy var cachedViewMatrix: float4x4 = {
        float4x4.translation([0, 0, -RendererConfiguration.Geometry.cameraDistance])
    }()

    // Texture getter with lazy loading and update
    private var texture: MTLTexture? {
        get {
            if textureNeedsUpdate || _texture == nil {
                do {
                    _texture = try loadTexture()
                    textureNeedsUpdate = false
                } catch {
                    RenderLogger.shared.log("Texture error: \(error)", level: .error)
                }
            }
            return _texture
        }
        set {
            _texture = newValue
        }
    }

    init(metalView: MTKView) throws {
        guard let device = metalView.device else {
            RenderLogger.shared.log("Metal device not found", level: .error)
            throw MetalError.deviceNotFound
        }
        guard let commandQueue = device.makeCommandQueue() else {
            RenderLogger.shared.log("Failed to create command queue", level: .error)
            throw MetalError.commandQueueCreationFailed
        }
        // Cache shader functions at initialization
        guard let library = try? device.makeDefaultLibrary(bundle: .main) else {
            throw MetalError.libraryCreationFailed
        }
        guard let vertex = library.makeFunction(name: RendererConfiguration.Shaders.vertex),
              let fragment = library.makeFunction(name: RendererConfiguration.Shaders.fragment) else {
            throw MetalError.shaderFunctionNotFound("\(RendererConfiguration.Shaders.vertex)/\(RendererConfiguration.Shaders.fragment)")
        }
        self.device = device
        self.commandQueue = commandQueue
        self.vertexFunction = vertex
        self.fragmentFunction = fragment
        super.init()
        RenderLogger.shared.log("Metal device initialized: \(device.name)", level: .info)
        try setupRenderer(metalView: metalView)
    }

    private func setupRenderer(metalView: MTKView) throws {
        try buildPipeline(metalView: metalView)
        try buildGeometry()
        try buildSampler()
        // Texture is now loaded lazily
        textureNeedsUpdate = true
    }

    private func buildPipeline(metalView: MTKView) throws {
        // Use cached shader functions
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "CubeRenderPipeline"
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
        descriptor.depthAttachmentPixelFormat = metalView.depthStencilPixelFormat
        pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        let depthDesc = MTLDepthStencilDescriptor()
        depthDesc.depthCompareFunction = .less
        depthDesc.isDepthWriteEnabled = true
        depthStencilState = device.makeDepthStencilState(descriptor: depthDesc)
    }

    private func buildGeometry() throws {
        let (vertices, colors, indices) = createIndexedCube()

        #if targetEnvironment(simulator)
        // Use shared storage on simulator
        vertexBuffer = device.makeBuffer(bytes: vertices,
                                         length: vertices.count * MemoryLayout<SIMD3<Float>>.stride,
                                         options: [.storageModeShared])
        vertexBuffer?.label = "CubeVertices"
        colorBuffer = device.makeBuffer(bytes: colors,
                                        length: colors.count * MemoryLayout<SIMD3<Float>>.stride,
                                        options: [.storageModeShared])
        colorBuffer?.label = "CubeColors"
        indexBuffer = device.makeBuffer(bytes: indices,
                                        length: indices.count * MemoryLayout<UInt16>.stride,
                                        options: [.storageModeShared])
        indexBuffer?.label = "CubeIndices"
        #else
        // Use private storage on device, upload via temporary shared buffer and blit
        let vertexLength = vertices.count * MemoryLayout<SIMD3<Float>>.stride
        let colorLength = colors.count * MemoryLayout<SIMD3<Float>>.stride
        let indexLength = indices.count * MemoryLayout<UInt16>.stride

        // Vertex buffer
        guard let vertexPrivate = device.makeBuffer(length: vertexLength, options: [.storageModePrivate]),
              let colorPrivate = device.makeBuffer(length: colorLength, options: [.storageModePrivate]),
              let indexPrivate = device.makeBuffer(length: indexLength, options: [.storageModePrivate])
        else {
            throw MetalError.bufferCreationFailed
        }
        vertexPrivate.label = "CubeVertices"
        colorPrivate.label = "CubeColors"
        indexPrivate.label = "CubeIndices"

        // Temporary shared buffers for upload
        guard let vertexTemp = device.makeBuffer(bytes: vertices, length: vertexLength, options: [.storageModeShared]),
              let colorTemp = device.makeBuffer(bytes: colors, length: colorLength, options: [.storageModeShared]),
              let indexTemp = device.makeBuffer(bytes: indices, length: indexLength, options: [.storageModeShared])
        else {
            throw MetalError.bufferCreationFailed
        }

        // Blit copy
        guard let blitCmdBuffer = commandQueue.makeCommandBuffer(),
              let blitEncoder = blitCmdBuffer.makeBlitCommandEncoder()
        else {
            throw MetalError.bufferCreationFailed
        }
        blitEncoder.copy(from: vertexTemp, sourceOffset: 0, to: vertexPrivate, destinationOffset: 0, size: vertexLength)
        blitEncoder.copy(from: colorTemp, sourceOffset: 0, to: colorPrivate, destinationOffset: 0, size: colorLength)
        blitEncoder.copy(from: indexTemp, sourceOffset: 0, to: indexPrivate, destinationOffset: 0, size: indexLength)
        blitEncoder.endEncoding()
        blitCmdBuffer.commit()
        blitCmdBuffer.waitUntilCompleted()

        vertexBuffer = vertexPrivate
        colorBuffer = colorPrivate
        indexBuffer = indexPrivate
        #endif

        guard vertexBuffer != nil, colorBuffer != nil, indexBuffer != nil else {
            throw MetalError.bufferCreationFailed
        }
    }

    private func createIndexedCube() -> (vertices: [SIMD3<Float>], colors: [SIMD3<Float>], indices: [UInt16]) {
        let s = RendererConfiguration.Geometry.cubeSize / 2
        let vertices: [SIMD3<Float>] = [
            [-s,-s, s],[ s,-s, s],[ s, s, s],[-s, s, s], // Front
            [-s,-s,-s],[ s,-s,-s],[ s, s,-s],[-s, s,-s], // Back
            [-s,-s,-s],[-s,-s, s],[-s, s, s],[-s, s,-s], // Left
            [ s,-s,-s],[ s,-s, s],[ s, s, s],[ s, s,-s], // Right
            [-s, s,-s],[ s, s,-s],[ s, s, s],[-s, s, s], // Top
            [-s,-s,-s],[ s,-s,-s],[ s,-s, s],[-s,-s, s]  // Bottom
        ]
        let faceColors: [SIMD3<Float>] = [
            [1,0,0],[0,1,0],[0,0,1],[1,1,0],[1,0,1],[0,1,1]
        ]
        var colors: [SIMD3<Float>] = []
        for c in faceColors { colors.append(contentsOf: Array(repeating: c, count: 4)) }
        var indices: [UInt16] = []
        for i in 0..<6 {
            let base = UInt16(i * 4)
            indices.append(contentsOf: [base,base+1,base+2,base+2,base+3,base])
        }
        return (vertices, colors, indices)
    }

    private func buildSampler() throws {
        let desc = MTLSamplerDescriptor()
        desc.minFilter = .linear
        desc.magFilter = .linear
        desc.mipFilter = .linear
        desc.sAddressMode = .repeat
        desc.tAddressMode = .repeat
        desc.maxAnisotropy = 8
        guard let sampler = device.makeSamplerState(descriptor: desc) else {
            throw MetalError.samplerCreationFailed
        }
        samplerState = sampler
    }

    // Texture loading is now lazy and will be called only when needed or if marked as dirty
    private func loadTexture() throws -> MTLTexture? {
        let loader = MTKTextureLoader(device: device)
        guard let url = Bundle.main.url(forResource: RendererConfiguration.Resources.textureName,
                                        withExtension: RendererConfiguration.Resources.textureExtension) else {
            RenderLogger.shared.log("Texture not found — creating fallback", level: .warning)
            return try createFallbackTexture()
        }
        do {
            return try loader.newTexture(URL: url, options: [.generateMipmaps: true])
        } catch {
            RenderLogger.shared.log("Texture loading failed: \(error)", level: .error)
            return try createFallbackTexture()
        }
    }

    private func createFallbackTexture() throws -> MTLTexture {
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm,
                                                            width: RendererConfiguration.Performance.textureSize,
                                                            height: RendererConfiguration.Performance.textureSize,
                                                            mipmapped: true)
        desc.usage = [.shaderRead]
        guard let fallbackTexture = device.makeTexture(descriptor: desc) else {
            throw MetalError.textureCreationFailed
        }
        generateProceduralTexture(fallbackTexture)
        RenderLogger.shared.log("Fallback texture created: \(fallbackTexture.width)x\(fallbackTexture.height)", level: .info)
        return fallbackTexture
    }

    private func generateProceduralTexture(_ texture: MTLTexture) {
        let width = texture.width, height = texture.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        var pixelData = [UInt8](repeating: 0, count: width*height*bytesPerPixel)
        pixelData.withUnsafeMutableBytes { ptr in
            let buffer = ptr.bindMemory(to: UInt8.self)
            for y in 0..<height {
                for x in 0..<width {
                    let pattern = (x/16 + y/16) % 2
                    let base: UInt8 = pattern == 0 ? 200 : 100
                    let idx = (y*width + x)*4
                    buffer[idx] = base
                    buffer[idx+1] = base
                    buffer[idx+2] = base
                    buffer[idx+3] = 255
                }
            }
        }
        texture.replace(region: MTLRegion(origin: .init(), size: .init(width: width, height: height, depth: 1)),
                        mipmapLevel: 0,
                        withBytes: pixelData,
                        bytesPerRow: bytesPerRow)
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        lastAspect = 0
        cachedProjMatrix = nil
        textureNeedsUpdate = true
    }

    func draw(in view: MTKView) {
        updateTime()
        guard let drawable = view.currentDrawable,
              let desc = view.currentRenderPassDescriptor,
              let pipeline = pipelineState,
              let cmdBuffer = commandQueue.makeCommandBuffer(),
              let encoder = cmdBuffer.makeRenderCommandEncoder(descriptor: desc) else { return }
        encoder.label = "CubeRenderEncoder"
        encoder.pushDebugGroup("DrawCube")
        defer {
            encoder.popDebugGroup()
            encoder.endEncoding()
            cmdBuffer.present(drawable)
            cmdBuffer.commit()
        }
        encoder.setRenderPipelineState(pipeline)
        encoder.setDepthStencilState(depthStencilState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(colorBuffer, offset: 0, index: 2)
        // Use lazy texture, update only if needed
        if let tex = self.texture { encoder.setFragmentTexture(tex, index: 0) }
        if let samp = samplerState { encoder.setFragmentSamplerState(samp, index: 0) }
        var mvp = createMVPMatrix(for: view)
        encoder.setVertexBytes(&mvp, length: MemoryLayout<float4x4>.stride, index: 1)
        encoder.drawIndexedPrimitives(type: .triangle,
                                      indexCount: 36,
                                      indexType: .uint16,
                                      indexBuffer: indexBuffer!,
                                      indexBufferOffset: 0)
        updateRotation()
    }

    private func updateTime() {
        let current = CACurrentMediaTime()
        deltaTime = lastUpdateTime > 0 ? Float(current - lastUpdateTime) : RendererConfiguration.Performance.targetFrameTime
        lastUpdateTime = current
    }

    // Only recalculate projection matrix if drawable size changes
    private func updateProjectionMatrix(for view: MTKView) {
        let aspect = Float(view.drawableSize.width / max(view.drawableSize.height, 1))
        if aspect != lastAspect || cachedProjMatrix == nil {
            cachedProjMatrix = float4x4.perspectiveFov(RendererConfiguration.Geometry.fieldOfView,
                                                      aspect: aspect,
                                                      nearZ: RendererConfiguration.Geometry.nearZ,
                                                      farZ: RendererConfiguration.Geometry.farZ)
            lastAspect = aspect
        }
    }

    // Only model matrix is recalculated per frame, view and projection are cached
    private func createMVPMatrix(for view: MTKView) -> float4x4 {
        updateProjectionMatrix(for: view)
        let model = float4x4.rotationX(rotationX) * .rotationY(rotationY) * .rotationZ(rotationZ)
        return cachedProjMatrix! * cachedViewMatrix * model
    }

    private func updateRotation() {
        let frameTime = min(deltaTime, RendererConfiguration.Performance.targetFrameTime*2)
        if autoRotate {
            rotationY += RendererConfiguration.Rotation.autoRotateSpeed * frameTime
        } else {
            rotationX += velocityX * frameTime
            rotationY += velocityY * frameTime
            velocityX = simd_mix(velocityX, 0, 1 - pow(RendererConfiguration.Rotation.dampingFactor, frameTime*60))
            velocityY = simd_mix(velocityY, 0, 1 - pow(RendererConfiguration.Rotation.dampingFactor, frameTime*60))
            if abs(velocityX) <= RendererConfiguration.Rotation.minVelocity &&
               abs(velocityY) <= RendererConfiguration.Rotation.minVelocity {
                autoRotate = true
                velocityX = 0
                velocityY = 0
            }
        }
    }

    func rotateX(_ delta: Float) { rotationX += delta; velocityX = delta*0.5; autoRotate = false }
    func rotateY(_ delta: Float) { rotationY += delta; velocityY = delta*0.5; autoRotate = false }

    func cleanupResources() {
        if let commandBuffer = commandQueue.makeCommandBuffer() {
            commandBuffer.addCompletedHandler { [weak self] _ in
                self?.vertexBuffer = nil
                self?.indexBuffer = nil
                self?.colorBuffer = nil
                self?.cachedProjMatrix = nil
                self?._texture = nil
                self?.samplerState = nil
            }
            commandBuffer.commit()
        }
    }
}
