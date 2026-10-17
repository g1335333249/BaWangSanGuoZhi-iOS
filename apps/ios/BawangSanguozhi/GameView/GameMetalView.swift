import MetalKit
import SwiftUI

struct GameMetalView: UIViewRepresentable {
    let session: GameSession

    func makeCoordinator() -> Renderer { Renderer(session: session) }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        view.isUserInteractionEnabled = true
        view.device = MTLCreateSystemDefaultDevice()
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColorMake(0, 0, 0, 1)
        view.preferredFramesPerSecond = 60
        view.isPaused = false
        view.enableSetNeedsDisplay = false
        view.delegate = context.coordinator
        context.coordinator.configure(view)
        let tap = UITapGestureRecognizer(target: context.coordinator,
                                       action: #selector(Renderer.handleTap(_:)))
        tap.cancelsTouchesInView = false
        let pan = UIPanGestureRecognizer(target: context.coordinator,
                                       action: #selector(Renderer.handlePan(_:)))
        pan.cancelsTouchesInView = false
        tap.require(toFail: pan)
        view.addGestureRecognizer(tap)
        view.addGestureRecognizer(pan)
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
    private let mapFlagRecovery = GameMapFlagRecovery()

    init(session: GameSession) { self.session = session }

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended, let view = gesture.view else { return }
        let sourceWidth = max(1, min(320, session.videoWidth))
        let half = GameDisplayGeometry.normalizedHalfSize(
            canvasWidth: Float(view.bounds.width),
            canvasHeight: Float(view.bounds.height),
            sourceWidth: Float(sourceWidth))
        let contentWidth = CGFloat(half.0) * view.bounds.width
        let contentHeight = CGFloat(half.1) * view.bounds.height
        let left = (view.bounds.width - contentWidth) / 2
        let top = (view.bounds.height - contentHeight) / 2
        let p = gesture.location(in: view)
        guard contentWidth > 0, contentHeight > 0,
              p.x >= left, p.x < left + contentWidth,
              p.y >= top, p.y < top + contentHeight else { return }
        session.tapGame(x: Int((p.x - left) / contentWidth * CGFloat(sourceWidth)),
                        y: Int((p.y - top) / contentHeight * 224),
                        width: sourceWidth)
    }

    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard gesture.state == .ended, let view = gesture.view else { return }
        let delta = gesture.translation(in: view)
        guard hypot(delta.x, delta.y) >= 18 else { return }
        session.swipeGame(dx: delta.x, dy: delta.y)
    }

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
            if !session.running { presentationFilter.reset(); mapFlagRecovery.reset() }
            return
        }
        let sourceWidth = max(1, min(320, session.videoWidth))
        // These switches are user-accessible because the map-blackout fix is
        // deliberately presentation-level until the VDP root cause is traced.
        let defaults = UserDefaults.standard
        presentationFilter.suppressPartialMenuFrames =
            defaults.object(forKey: "BawangPartialMenuDeGlitch") == nil ||
            defaults.bool(forKey: "BawangPartialMenuDeGlitch")
        // Keep the old generic 8x8 black-square heuristic off: actual flags
        // contain too few coloured pixels for it to reliably activate.
        presentationFilter.suppressTransientMapBlackTiles = false
        let filtered = presentationFilter.present(rawFrame, visibleWidth: sourceWidth)
        mapFlagRecovery.enabled = defaults.object(forKey: "BawangMapBlackTileRepair") == nil ||
            defaults.bool(forKey: "BawangMapBlackTileRepair")
        let recovered = mapFlagRecovery.present(filtered, visibleWidth: sourceWidth)
        // Localization now occurs in the ROM glyphs before the VDP renderer.
        // Never overlay or OCR the finished framebuffer to replace text.
        let frame = recovered

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
        var quality = UInt32(max(0, min(2, UserDefaults.standard.integer(forKey: "BawangVideoFilter"))))
        encoder.setFragmentBytes(&quality, length: MemoryLayout<UInt32>.size, index: 0)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        let limiter = inFlight
        command.addCompletedHandler { _ in limiter.signal() }
        command.present(drawable)
        command.commit()
    }
}
