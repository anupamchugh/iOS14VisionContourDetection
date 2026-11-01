import CoreGraphics
import Foundation

public struct RGBColor: Sendable, Equatable {
    public let red: Double
    public let green: Double
    public let blue: Double
}

/// The average colour inside each counted object, read from the photo.
public enum ColorSampler {
    public static func averageColors(in image: CGImage, for objects: [CountedObject], maximumDimension: Int = 512) -> [RGBColor] {
        let scale = min(1, Double(maximumDimension) / Double(max(image.width, image.height)))
        let width = max(1, Int(Double(image.width) * scale)), height = max(1, Int(Double(image.height) * scale))
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = rgba.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        let grey = RGBColor(red: 0.5, green: 0.5, blue: 0.5)
        guard drawn else { return objects.map { _ in grey } }

        return objects.map { object in
            // The inner 70% of the circle, away from the edge and its shadow.
            let box = object.boundingBox
            let cx = box.midX * Double(width), cy = box.midY * Double(height)
            let rx = box.width / 2 * Double(width) * 0.7, ry = box.height / 2 * Double(height) * 0.7
            var sum = (0.0, 0.0, 0.0), count = 0.0
            for y in max(0, Int(cy - ry))...min(height - 1, Int(cy + ry)) {
                for x in max(0, Int(cx - rx))...min(width - 1, Int(cx + rx)) {
                    let dx = (Double(x) - cx) / max(rx, 1), dy = (Double(y) - cy) / max(ry, 1)
                    guard dx * dx + dy * dy <= 1 else { continue }
                    let i = (y * width + x) * 4
                    sum.0 += Double(rgba[i]); sum.1 += Double(rgba[i + 1]); sum.2 += Double(rgba[i + 2])
                    count += 1
                }
            }
            guard count > 0 else { return grey }
            return RGBColor(red: sum.0 / count / 255, green: sum.1 / count / 255, blue: sum.2 / count / 255)
        }
    }
}

/// Counted objects laid out as tokens on a table, in metres, for RealityKit.
///
/// The photo is mapped onto a table `tableWidth` wide, so positions and relative sizes match the
/// photo. Without a reference object the scale isn't real-world size.
public struct TableScene: Sendable {
    public struct Token: Sendable {
        /// Left-right position, 0 at the table's centre.
        public let x: Double
        /// Near-far position, 0 at the table's centre; the photo's top edge is far away.
        public let z: Double
        public let radius: Double
        public let height: Double
        public let color: RGBColor
    }

    public let tableWidth: Double
    public let tableDepth: Double
    public let tokens: [Token]

    /// - Parameter imageAspect: The photo's width divided by its height.
    public init(result: CountResult, imageAspect: Double, colours: [RGBColor], tableWidth: Double = 0.3) {
        self.tableWidth = tableWidth
        tableDepth = tableWidth / imageAspect
        let grey = RGBColor(red: 0.5, green: 0.5, blue: 0.5)
        tokens = result.objects.enumerated().map { index, object in
            let box = object.boundingBox
            let radius = box.width / 2 * tableWidth
            return Token(
                x: (box.midX - 0.5) * tableWidth,
                z: (box.midY - 0.5) * tableWidth / imageAspect,
                radius: radius,
                // About a coin's thickness relative to its width.
                height: radius * 0.16,
                color: index < colours.count ? colours[index] : grey
            )
        }
    }
}
