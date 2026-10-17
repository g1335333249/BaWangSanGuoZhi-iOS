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
    private var texture: MTLTexture?

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
        texture = device.makeTexture(descriptor: image)
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let bytes = session.step(), let texture, let pipeline,
              let descriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let command = queue?.makeCommandBuffer(),
              let encoder = command.makeRenderCommandEncoder(descriptor: descriptor) else { return }

        bytes.withUnsafeBytes { raw in
            if let base = raw.baseAddress {
                texture.replace(region: MTLRegionMake2D(0, 0, 320, 224), mipmapLevel: 0,
                    withBytes: base, bytesPerRow: 320 * 4)
            }
        }

        let sourceWidth = max(1, min(320, session.videoWidth))
        let canvasWidth = max(1, Int(view.drawableSize.width))
        let canvasHeight = max(1, Int(view.drawableSize.height))
        // Leave the sidebars for touch controls, then scale by whole pixels.
        let availableWidth = max(sourceWidth, Int(Double(canvasWidth) * 0.60))
        let scale = max(1, min(availableWidth / sourceWidth, canvasHeight / 224))
        let x = Float(sourceWidth * scale) / Float(canvasWidth)
        let y = Float(224 * scale) / Float(canvasHeight)
        var rectangle = SIMD4<Float>(-x, -y, x, y)
        var rightUV = Float(sourceWidth) / 320.0

        encoder.setRenderPipelineState(pipeline)
        encoder.setVertexBytes(&rectangle, length: MemoryLayout.size(ofValue: rectangle), index: 0)
        encoder.setVertexBytes(&rightUV, length: MemoryLayout.size(ofValue: rightUV), index: 1)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        command.present(drawable)
        command.commit()
    }
}
