import AppKit
@preconcurrency import Metal
import MetalKit

actor ImageProcessingService {

    // MARK: - Dependencies
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState

    init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            return nil
        }

        self.device = device
        self.commandQueue = commandQueue

        let library: MTLLibrary
        do {
            guard let libraryURL = Bundle.main.url(forResource: "default", withExtension: "metallib") else {
                return nil
            }
            library = try device.makeLibrary(URL: libraryURL)
        } catch {
            return nil
        }

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = library.makeFunction(name: "texture_vertex")
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: "texture_fragment")
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        do {
            self.pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            return nil
        }
    }

    func downsample(image: CGImage, maxDimension: CGFloat) async -> CGImage? {
        let newSize = calculateNewSize(for: image, maxDimension: maxDimension)
        guard newSize.width > 0 && newSize.height > 0 else { return nil }

        guard let sourceTexture = loadTexture(from: image) else {
            return nil
        }

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: Int(newSize.width),
            height: Int(newSize.height),
            mipmapped: false
        )
        descriptor.usage = [.renderTarget, .shaderRead]
        guard let destinationTexture = device.makeTexture(descriptor: descriptor) else {
            return nil
        }

        let renderPassDescriptor = createRenderPassDescriptor(for: destinationTexture)
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return nil
        }

        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setFragmentTexture(sourceTexture, index: 0)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        renderEncoder.endEncoding()

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            commandBuffer.addCompletedHandler { _ in
                continuation.resume()
            }
            commandBuffer.commit()
        }

        guard commandBuffer.status == .completed else {
            return nil
        }

        let width = destinationTexture.width
        let height = destinationTexture.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let dataSize = bytesPerRow * height

        let pixelData = UnsafeMutableRawPointer.allocate(byteCount: dataSize, alignment: bytesPerPixel)

        destinationTexture.getBytes(pixelData, bytesPerRow: bytesPerRow, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)

        let provider = CGDataProvider(dataInfo: pixelData, data: pixelData, size: dataSize) { info, _, _ in
            info?.deallocate()
        }

        guard let provider = provider else {
            pixelData.deallocate()
            return nil
        }

        let resultImage = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bytesPerRow,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
                                  provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)

        return resultImage
    }

    // MARK: - Private Helpers

    private func loadTexture(from cgImage: CGImage) -> MTLTexture? {
        let width = cgImage.width
        let height = cgImage.height

        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        textureDescriptor.usage = .shaderRead

        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            return nil
        }

        guard let dataProvider = cgImage.dataProvider, let data = dataProvider.data else {
            return nil
        }

        let bytesPerRow = cgImage.bytesPerRow
        guard let bytes = CFDataGetBytePtr(data) else {
            return nil
        }

        texture.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: bytes,
            bytesPerRow: bytesPerRow
        )

        return texture
    }

    private func calculateNewSize(for image: CGImage, maxDimension: CGFloat) -> CGSize {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        if width <= maxDimension && height <= maxDimension {
            return CGSize(width: width, height: height)
        }

        if width > height {
            let newWidth = maxDimension
            let newHeight = round((height / width) * newWidth)
            return CGSize(width: newWidth, height: newHeight)
        } else {
            let newHeight = maxDimension
            let newWidth = round((width / height) * newHeight)
            return CGSize(width: newWidth, height: newHeight)
        }
    }

    private func createRenderPassDescriptor(for texture: MTLTexture) -> MTLRenderPassDescriptor {
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = texture
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        return descriptor
    }
}
