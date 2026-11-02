import CoreGraphics
import UIKit

/// Pictures that ship with the app, so it works in the simulator with no photo library.
enum Sample: String, CaseIterable, Identifiable {
    case coins = "Coins"
    case leaves = "Leaves"
    case surfboard = "Surfboard"
    case anything = "Anything"

    var id: Self { self }

    var image: CGImage? {
        switch self {
        case .coins: UIImage(named: "coins")?.cgImage
        case .leaves: Self.drawnLeaves()
        case .surfboard: Self.drawnBoard()
        case .anything: Self.drawnShapes(stripes: false)
        }
    }

    /// A 6'2" shortboard seen from above on a concrete floor, lying sideways with the nose on the left:
    /// 74 in long, 19 ¼ in wide about an inch behind centre, with a squash tail. Drawn at 13 px per inch.
    static func drawnBoard() -> CGImage? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1100, height: 420))
        let image = renderer.image { context in
            UIColor(red: 0.52, green: 0.53, blue: 0.55, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1100, height: 420))
            // Drawn nose-down below, then turned on its side by swapping x and y.
            context.cgContext.concatenate(CGAffineTransform(a: 0, b: 1, c: 1, d: 0, tx: 0, ty: 0))
            let inch = 13.0, centre = 210.0, nose = 69.0
            func y(_ inches: Double) -> Double { nose + inches * inch }
            func x(_ halfWidth: Double) -> Double { centre + halfWidth * inch }
            // Right rail, nose to tail, as (inches from nose, half-width) for each curve's two control
            // points and its end. The left rail runs back up the mirror image.
            let segments: [[(Double, Double)]] = [
                [(1.5, 1.6), (7, 4.4), (12, 5.75)],
                [(19, 7.4), (30, 9.625), (38, 9.625)],
                [(47, 9.625), (56, 8.4), (62, 7.125)],
                [(66.5, 6.2), (71, 5.2), (74, 4.75)]
            ]
            func point(_ p: (Double, Double), side: Double) -> CGPoint { CGPoint(x: x(side * p.1), y: y(p.0)) }
            let board = UIBezierPath()
            board.move(to: CGPoint(x: centre, y: y(0)))
            for segment in segments {
                board.addCurve(to: point(segment[2], side: 1), controlPoint1: point(segment[0], side: 1), controlPoint2: point(segment[1], side: 1))
            }
            board.addLine(to: point(segments[3][2], side: -1))
            let starts = [(0.0, 0.0)] + segments.map { $0[2] }
            for (index, segment) in segments.enumerated().reversed() {
                board.addCurve(to: point(starts[index], side: -1), controlPoint1: point(segment[1], side: -1), controlPoint2: point(segment[0], side: -1))
            }
            board.close()
            UIColor(red: 0.97, green: 0.96, blue: 0.91, alpha: 1).setFill()
            board.fill()
            // The stringer, a thin wooden line down the middle.
            UIColor(red: 0.72, green: 0.6, blue: 0.42, alpha: 1).setFill()
            context.fill(CGRect(x: centre - 1, y: y(0.5), width: 2, height: 73 * inch))
        }
        return image.cgImage
    }

    /// Four leaves and a 1 € coin (23.25 mm, drawn 93 px wide) on cream paper, at 4 px per millimetre.
    static func drawnLeaves() -> CGImage? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 900, height: 700))
        let image = renderer.image { context in
            let cg = context.cgContext
            UIColor(red: 0.93, green: 0.9, blue: 0.84, alpha: 1).setFill()
            cg.fill(CGRect(x: 0, y: 0, width: 900, height: 700))
            // (centre x, centre y, angle, length, width, colour)
            let leaves: [(Double, Double, Double, Double, Double, UIColor)] = [
                (210, 170, -30, 300, 110, UIColor(red: 0.31, green: 0.54, blue: 0.24, alpha: 1)),
                (640, 160, 15, 280, 90, UIColor(red: 0.48, green: 0.64, blue: 0.29, alpha: 1)),
                (230, 500, -40, 260, 120, UIColor(red: 0.64, green: 0.46, blue: 0.17, alpha: 1)),
                (640, 500, 35, 240, 130, UIColor(red: 0.37, green: 0.6, blue: 0.27, alpha: 1))
            ]
            for (x, y, angle, length, width, colour) in leaves {
                cg.saveGState()
                cg.translateBy(x: x, y: y)
                cg.rotate(by: angle * .pi / 180)
                // A pointed leaf: two arcs meeting at the tip and the stem end.
                let leaf = UIBezierPath()
                leaf.move(to: CGPoint(x: -length / 2, y: 0))
                leaf.addQuadCurve(to: CGPoint(x: length / 2, y: 0), controlPoint: CGPoint(x: 0, y: -width))
                leaf.addQuadCurve(to: CGPoint(x: -length / 2, y: 0), controlPoint: CGPoint(x: 0, y: width))
                colour.setFill()
                leaf.fill()
                cg.restoreGState()
            }
            UIColor(red: 0.78, green: 0.63, blue: 0.25, alpha: 1).setFill()
            cg.fillEllipse(in: CGRect(x: 430 - 46.5, y: 340 - 46.5, width: 93, height: 93))
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
