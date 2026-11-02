import CoreGraphics
import UIKit

/// Pictures that ship with the app, so it works in the simulator with no photo library.
enum Sample: String, CaseIterable, Identifiable {
    case coins = "Coins"
    case discs = "Discs"
    case shapes = "Shapes"
    case busy = "Busy"

    var id: Self { self }

    /// The counting mode each sample is made for.
    var mode: CountMode {
        switch self {
        case .coins, .discs: .round
        case .shapes, .busy: .shapes
        }
    }

    var image: CGImage? {
        switch self {
        case .coins: UIImage(named: "coins")?.cgImage
        case .discs: Self.drawnDiscs()
        case .shapes: Self.drawnShapes(stripes: false)
        case .busy: Self.drawnShapes(stripes: true)
        }
    }

    /// Two sizes of disc, two of them touching, on a light background.
    static func drawnDiscs() -> CGImage? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 900, height: 600))
        let image = renderer.image { context in
            UIColor(red: 0.9, green: 0.91, blue: 0.94, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 900, height: 600))
            UIColor(red: 0.78, green: 0.47, blue: 0.2, alpha: 1).setFill()
            for x in [150.0, 330, 510, 690] {
                context.cgContext.fillEllipse(in: CGRect(x: x - 50, y: 100, width: 100, height: 100))
            }
            UIColor(red: 0.62, green: 0.65, blue: 0.2, alpha: 1).setFill()
            for (x, y) in [(220.0, 400.0), (370, 400), (640, 380)] {
                context.cgContext.fillEllipse(in: CGRect(x: x - 75, y: y - 75, width: 150, height: 150))
            }
        }
        return image.cgImage
    }

    /// Screw-like rods, a key, two leaves and a washer, on plain grey or on stripes.
    static func drawnShapes(stripes: Bool) -> CGImage? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 900, height: 600))
        let image = renderer.image { context in
            let cg = context.cgContext
            UIColor(red: 0.91, green: 0.91, blue: 0.93, alpha: 1).setFill()
            cg.fill(CGRect(x: 0, y: 0, width: 900, height: 600))
            if stripes {
                for (index, x) in stride(from: 0, to: 900, by: 45).enumerated() where index.isMultiple(of: 2) {
                    UIColor(red: 0.62, green: 0.58, blue: 0.5, alpha: 1).setFill()
                    cg.fill(CGRect(x: x, y: 0, width: 45, height: 600))
                }
            }

            func turned(_ x: Double, _ y: Double, _ degrees: Double, draw: () -> Void) {
                cg.saveGState()
                cg.translateBy(x: x, y: y)
                cg.rotate(by: degrees * .pi / 180)
                draw()
                cg.restoreGState()
            }

            // Screws: a shank with a wider head.
            UIColor(red: 0.35, green: 0.37, blue: 0.42, alpha: 1).setFill()
            for (x, y, angle, length) in [(170.0, 150.0, 20.0, 220.0), (200, 330, -10, 180), (150, 480, 35, 150)] {
                turned(x, y, angle) {
                    cg.fill(CGRect(x: -length / 2, y: -9, width: length, height: 18))
                    cg.fillEllipse(in: CGRect(x: -length / 2 - 16, y: -20, width: 32, height: 40))
                }
            }
            // A key: a round bow with a hole, a shaft and teeth.
            UIColor(red: 0.82, green: 0.66, blue: 0.25, alpha: 1).setFill()
            turned(480, 190, -25) {
                cg.fillEllipse(in: CGRect(x: -120, y: -45, width: 90, height: 90))
                cg.fill(CGRect(x: -40, y: -12, width: 170, height: 24))
                cg.fill(CGRect(x: 80, y: 10, width: 14, height: 22))
                cg.fill(CGRect(x: 105, y: 10, width: 14, height: 16))
            }
            // Leaves.
            UIColor(red: 0.3, green: 0.55, blue: 0.25, alpha: 1).setFill()
            for (x, y, angle) in [(520.0, 440.0, 30.0), (720, 380, -50)] {
                turned(x, y, angle) { cg.fillEllipse(in: CGRect(x: -90, y: -40, width: 180, height: 80)) }
            }
            // A washer.
            UIColor(red: 0.55, green: 0.57, blue: 0.6, alpha: 1).setFill()
            cg.fillEllipse(in: CGRect(x: 720, y: 110, width: 110, height: 110))
        }
        return image.cgImage
    }
}
