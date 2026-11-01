import CoreGraphics
import UIKit

/// Pictures that ship with the app, so it works in the simulator with no photo library.
enum Sample: String, CaseIterable, Identifiable {
    case coins = "Coins"
    case discs = "Drawn discs"

    var id: Self { self }

    var image: CGImage? {
        switch self {
        case .coins: UIImage(named: "coins")?.cgImage
        case .discs: Self.drawnDiscs()
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
}
