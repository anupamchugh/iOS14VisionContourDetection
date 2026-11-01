import CoreGraphics
import Foundation

/// Which pixels belong to objects, for a photo of things on a plain background.
public struct ObjectMask: Sendable {
    public let width: Int
    public let height: Int
    /// Row-major, origin at the top left. `true` is an object pixel.
    public let pixels: [Bool]

    /// Black objects on white, for Vision's contour request.
    public func image() -> CGImage? {
        let gray = pixels.map { $0 ? UInt8(0) : UInt8(255) }
        guard let provider = CGDataProvider(data: Data(gray) as CFData) else { return nil }
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )
    }
}

/// Separates objects from a plain background by colour.
///
/// The background colour is read from the image's border. A pixel is an object pixel when its colour
/// is further than `threshold` from that colour, so coins, fruit or pills of any colour stand out the
/// same way. Holes inside an object (a shiny highlight, a printed number) are filled.
public struct BackgroundMask: Sendable {
    /// Colour distance (0...√3 in RGB) above which a pixel counts as an object.
    public var threshold = 0.16
    public var maximumDimension = 1024

    public init() {}

    public func mask(for image: CGImage) -> ObjectMask? {
        let scale = min(1, Double(maximumDimension) / Double(max(image.width, image.height)))
        let width = max(1, Int(Double(image.width) * scale)), height = max(1, Int(Double(image.height) * scale))
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = rgba.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            ) else { return false }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }

        let background = Self.borderColor(rgba, width: width, height: height)
        let limit = threshold * threshold
        var object = [Bool](repeating: false, count: width * height)
        for index in object.indices {
            let r = Double(rgba[index * 4]) / 255 - background.r
            let g = Double(rgba[index * 4 + 1]) / 255 - background.g
            let b = Double(rgba[index * 4 + 2]) / 255 - background.b
            object[index] = r * r + g * g + b * b > limit
        }
        return ObjectMask(width: width, height: height, pixels: Self.fillingHoles(object, width: width, height: height))
    }

    static func borderColor(_ rgba: [UInt8], width: Int, height: Int) -> (r: Double, g: Double, b: Double) {
        var sum = (r: 0.0, g: 0.0, b: 0.0), count = 0.0
        let band = max(1, min(width, height) / 50)
        for y in 0..<height {
            for x in 0..<width where x < band || y < band || x >= width - band || y >= height - band {
                let index = (y * width + x) * 4
                sum.r += Double(rgba[index]); sum.g += Double(rgba[index + 1]); sum.b += Double(rgba[index + 2])
                count += 1
            }
        }
        return (sum.r / count / 255, sum.g / count / 255, sum.b / count / 255)
    }

    /// Background is whatever non-object area touches the border; every other pixel becomes object.
    static func fillingHoles(_ object: [Bool], width: Int, height: Int) -> [Bool] {
        var outside = [Bool](repeating: false, count: object.count)
        var stack: [Int] = []
        func visit(_ index: Int) {
            if !object[index] && !outside[index] { outside[index] = true; stack.append(index) }
        }
        for x in 0..<width { visit(x); visit((height - 1) * width + x) }
        for y in 0..<height { visit(y * width); visit(y * width + width - 1) }
        while let index = stack.popLast() {
            let x = index % width, y = index / width
            if x > 0 { visit(index - 1) }
            if x < width - 1 { visit(index + 1) }
            if y > 0 { visit(index - width) }
            if y < height - 1 { visit(index + width) }
        }
        return outside.map { !$0 }
    }
}
