import MetalKit
import SwiftUI

struct GameMetalView: UIViewRepresentable {
    let session: GameSession

    func makeCoordinator() -> Renderer { Renderer(session: session) }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        view.isUserInteractionEnabled = false
        view.device = MTLCreateSystemDefaultDevice()
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColorMake(0, 0, 0, 1)
        view.preferredFramesPerSecond = 60
        view.isPaused = false
        view.enableSetNeedsDisplay = false
        view.delegate = context.coordinator
        context.coordinator.configure(view)
        return view
    }

    func updateUIView(_ view: MTKView, context: Context) {
        view.isPaused = !session.running || session.paused
    }
}

final class Renderer: NSObject, MTKViewDelegate {
    private let session: GameSession
    private var pipeline: MTLRenderPipelineState?
    private var queue: MTLCommandQueue?
    // Keep each CPU upload away from textures still being sampled by the GPU.
    private var textures: [MTLTexture] = []
    private var nextTextureIndex = 0
    private let inFlight = DispatchSemaphore(value: 3)
    private let presentationFilter = GameFramePresentationFilter()
    private let textLocalization = GameTextLocalization()

    init(session: GameSession) { self.session = session }

    func configure(_ view: MTKView) {
        guard let device = view.device,
              let shader = device.makeDefaultLibrary(),
              let vertex = shader.makeFunction(name: "gameVertex"),
              let fragment = shader.makeFunction(name: "gameFragment") else { return }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertex
        descriptor.fragmentFunction = fragment
        descriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        pipeline = try? device.makeRenderPipelineState(descriptor: descriptor)
        queue = device.makeCommandQueue()
        let image = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
            width: 320, height: 224, mipmapped: false)
        image.usage = [.shaderRead]
        image.storageMode = .shared
        textures = (0..<3).compactMap { _ in device.makeTexture(descriptor: image) }
        if textures.count != 3 { textures.removeAll() }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let rawFrame = session.step(), textures.count == 3, let pipeline,
              let descriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let command = queue?.makeCommandBuffer() else {
            if !session.running { presentationFilter.reset(); textLocalization.reset() }
            return
        }
        let sourceWidth = max(1, min(320, session.videoWidth))
        // These switches are user-accessible because the map-blackout fix is
        // deliberately presentation-level until the VDP root cause is traced.
        let defaults = UserDefaults.standard
        presentationFilter.suppressPartialMenuFrames =
            defaults.object(forKey: "BawangPartialMenuDeGlitch") == nil ||
            defaults.bool(forKey: "BawangPartialMenuDeGlitch")
        presentationFilter.suppressTransientMapBlackTiles =
            defaults.object(forKey: "BawangMapBlackTileRepair") == nil ||
            defaults.bool(forKey: "BawangMapBlackTileRepair")
        let filtered = presentationFilter.present(rawFrame, visibleWidth: sourceWidth)
        let frame = textLocalization.present(filtered, visibleWidth: sourceWidth,
                           simplified: defaults.string(forKey: "BawangGameLanguage") == "simplified")

        // Completion callbacks return slots in command-buffer submission order.
        inFlight.wait()
        let texture = textures[nextTextureIndex]
        nextTextureIndex = (nextTextureIndex + 1) % textures.count
        frame.withUnsafeBytes { raw in
            if let base = raw.baseAddress {
                texture.replace(region: MTLRegionMake2D(0, 0, 320, 224), mipmapLevel: 0,
                    withBytes: base, bytesPerRow: 320 * 4)
            }
        }
        guard let encoder = command.makeRenderCommandEncoder(descriptor: descriptor) else {
            inFlight.signal()
            return
        }

        let halfSize = GameDisplayGeometry.normalizedHalfSize(
            canvasWidth: Float(view.drawableSize.width),
            canvasHeight: Float(view.drawableSize.height),
            sourceWidth: Float(sourceWidth))
        var rectangle = SIMD4<Float>(-halfSize.0, -halfSize.1, halfSize.0, halfSize.1)
        var rightUV = Float(sourceWidth) / 320.0
        encoder.setRenderPipelineState(pipeline)
        encoder.setVertexBytes(&rectangle, length: MemoryLayout.size(ofValue: rectangle), index: 0)
        encoder.setVertexBytes(&rightUV, length: MemoryLayout.size(ofValue: rightUV), index: 1)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        let limiter = inFlight
        command.addCompletedHandler { _ in limiter.signal() }
        command.present(drawable)
        command.commit()
    }
}
