import ContourLabKit
import RealityKit
import SwiftUI

/// The counted objects as tokens on a table you can turn around: drag to orbit.
struct TableView3D: View {
    let scene: TableScene

    var body: some View {
        RealityView { content in
            content.camera = .virtual
            let root = Entity()

            let table = ModelEntity(
                mesh: .generateBox(width: Float(scene.tableWidth) + 0.02, height: 0.004, depth: Float(scene.tableDepth) + 0.02, cornerRadius: 0.002),
                materials: [SimpleMaterial(color: UIColor(white: 0.9, alpha: 1), roughness: 0.9, isMetallic: false)]
            )
            table.position.y = -0.002
            root.addChild(table)

            for token in scene.tokens {
                let colour = UIColor(red: token.color.red, green: token.color.green, blue: token.color.blue, alpha: 1)
                let piece = ModelEntity(
                    mesh: .generateCylinder(height: Float(token.height), radius: Float(token.radius)),
                    materials: [SimpleMaterial(color: colour, roughness: 0.45, isMetallic: false)]
                )
                piece.position = [Float(token.x), Float(token.height / 2), Float(token.z)]
                root.addChild(piece)
            }
            content.add(root)
            content.cameraTarget = root

            let camera = PerspectiveCamera()
            camera.look(at: .zero, from: [0, Float(scene.tableWidth) * 0.62, Float(scene.tableWidth) * 0.5], relativeTo: nil)
            content.add(camera)

            let key = DirectionalLight()
            key.light.intensity = 6000
            key.look(at: .zero, from: [0.15, 0.4, 0.25], relativeTo: nil)
            content.add(key)

            let fill = DirectionalLight()
            fill.light.intensity = 2500
            fill.look(at: .zero, from: [-0.2, 0.3, -0.1], relativeTo: nil)
            content.add(fill)
        }
        .realityViewCameraControls(.orbit)
        .accessibilityLabel("\(scene.tokens.count) objects shown as 3D tokens on a table. Drag to turn it.")
    }
}
