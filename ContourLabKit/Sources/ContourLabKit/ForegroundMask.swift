import CoreGraphics
import CoreVideo
import Foundation
import Vision

/// Anything that can say which pixels belong to objects.
public protocol ObjectMasking: Sendable {
    func mask(for image: CGImage) throws -> ObjectMask?
}

extension BackgroundMask: ObjectMasking {}

/// Separates objects from any background with Vision's foreground instance mask, the model behind
/// lifting a subject out of a photo. Use it when the background isn't plain.
///
/// The model finds the photo's main subjects, not every small thing, and may join objects that touch,
/// so it suits a few objects on a busy background more than a heap of coins.
public struct ForegroundMask: ObjectMasking {
    public var maximumDimension = 1024

    public init() {}

    public func mask(for image: CGImage) throws -> ObjectMask? {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])
        guard let observation = request.results?.first, !observation.allInstances.isEmpty else {
            return ObjectMask(width: 1, height: 1, pixels: [false])
        }
        let buffer = try observation.generateScaledMaskForImage(forInstances: observation.allInstances, from: handler)

        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let sourceWidth = CVPixelBufferGetWidth(buffer), sourceHeight = CVPixelBufferGetHeight(buffer)
        let rowBytes = CVPixelBufferGetBytesPerRow(buffer)

        let scale = min(1, Double(maximumDimension) / Double(max(sourceWidth, sourceHeight)))
        let width = max(1, Int(Double(sourceWidth) * scale)), height = max(1, Int(Double(sourceHeight) * scale))
        var pixels = [Bool](repeating: false, count: width * height)
        for y in 0..<height {
            let row = base.advanced(by: min(sourceHeight - 1, Int(Double(y) / scale)) * rowBytes)
                .assumingMemoryBound(to: Float32.self)
            for x in 0..<width {
                pixels[y * width + x] = row[min(sourceWidth - 1, Int(Double(x) / scale))] > 0.5
            }
        }
        return ObjectMask(width: width, height: height, pixels: pixels)
    }
}
