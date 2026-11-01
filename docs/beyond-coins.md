# Beyond coins

Contour Lab counts round things on a plain background. This note lists what else Apple's frameworks let it measure or count, how the results can move into 3D, and which features to build first. Researched 1 November 2026 against Apple's documentation (docs map dated 18 October 2026).

## What it can count or measure in 2D

| Objects | Vision request | What it adds | Fit |
|---|---|---|---|
| Coins, pills, seeds, buttons, cookies | Today's pipeline: colour mask, `VNDetectContoursRequest`, distance-map peaks | Count and relative size of round things, even when they touch | Works now |
| Screws, bolts, keys, leaves, Lego bricks | `VNDetectContoursRequest` outlines plus `ShapeMetrics` (area, perimeter, circularity) | Count non-round shapes that don't touch; sort by length, area or roundness | Small change: count outlines instead of circles when objects are elongated |
| Cookies on a tray, fruit in a bowl, things on a busy background | `GenerateForegroundInstanceMaskRequest` (Swift API) / `VNGenerateForegroundInstanceMaskRequest` | One mask per separate foreground object, without needing a plain background | Good: replaces the colour mask where the background isn't plain |
| Receipts, cards, documents, a sheet of paper as a reference | `DetectRectanglesRequest` | Finds four-cornered shapes and their corners | Good: the basis for real-world size (below) |
| Labels on jars, pill packs, coin years | `RecognizeTextRequest` | Reads text inside or next to each object | Later: pairs well with the on-device model note |
| "What should I look at?" | `GenerateAttentionBasedSaliencyImageRequest` / objectness saliency | A heat map of where the subject is, to crop before counting | Later: helps on cluttered photos |
| Hand-drawn shapes | Contours on a white page | A drawing becomes outlines that can be filled, measured or extruded | Good with 3D (below) |

## Real-world size

A photo alone gives sizes in pixels. Three ways to turn them into millimetres:

1. **A reference object in the photo.** This is the long-standing "pixels per metric" method ([PyImageSearch, 2016](https://pyimagesearch.com/2016/03/28/measuring-size-of-objects-in-an-image-with-opencv/)). A bank card (ISO/IEC 7810 ID-1, 85.60 × 53.98 mm) is easy to find with `DetectRectanglesRequest`, and is common and flat. Millimetres per pixel = 85.60 / the card's long side in pixels. It works on any iPhone and in the simulator, but only for objects lying flat at the card's distance, shot from straight above.
2. **LiDAR scene depth.** On iPhones and iPads with LiDAR, ARKit's `ARFrame.sceneDepth` (`ARConfiguration.FrameSemantics.sceneDepth`) gives the distance to every pixel. Pixel size × depth ÷ focal length gives millimetres, with no reference object. Apple's samples [Displaying a point cloud using scene depth](https://developer.apple.com/documentation/arkit/displaying-a-point-cloud-using-scene-depth) and [Capturing depth using the LiDAR camera](https://developer.apple.com/documentation/avfoundation/capturing-depth-using-the-lidar-camera) show both routes. This needs a real device.
3. **ARKit plane hit-test.** Without LiDAR, raycast the object's centre and edge onto a detected horizontal plane ([Tracking and visualizing planes](https://developer.apple.com/documentation/arkit/tracking-and-visualizing-planes)). It's less precise for small objects.

With millimetres, euro or rupee coins could be named by diameter and totalled. That needs about 0.5 mm accuracy, so check it on real photos before promising it.

## Into 3D with RealityKit

- **Tokens.** Each counted object becomes a short cylinder: `MeshResource.generateCylinder`, sized from Vision's measured diameter and tinted with the object's average colour from the photo. A `RealityView` with `realityViewCameraControls(.orbit)` (iOS 18+) lets you turn the table around. It works in the simulator with no camera.
- **Extruded outlines.** `MeshResource(extruding: Path, extrusionOptions:)` (iOS 18+, macOS 15+, visionOS 2+) turns any closed outline into a solid. The path must be closed and must not cross itself, so simplify Vision's outline first. A hand-drawn star or a leaf becomes a 3D piece. Public write-ups: [Step Into Vision: Extruding Meshes](https://stepinto.vision/example-code/realitykit-basics-extruding-meshes/) and [Andre Salla: a custom 3D shape from a SwiftUI shape](https://andresalla.com/en/how-to-create-a-custom-3d-shape-for-realitykit-on-visionos-from-a-swiftui-shape/).
- **AR overlay.** In an AR session, place each token where its object sits on the table, using a plane anchor or LiDAR depth. Counts and sizes then float above the real coins. [Placing objects and handling 3D interaction](https://developer.apple.com/documentation/arkit/placing-objects-and-handling-3d-interaction) covers the anchoring.
- **visionOS.** The same tokens go in a volumetric window, and in a full space ARKit's scene reconstruction can mesh the table ([Applying mesh to real-world surroundings](https://developer.apple.com/documentation/visionos/applying-mesh-to-real-world-surroundings)). Apps don't get the main camera feed without an enterprise entitlement, so the visionOS app would count photos you hand it, not the live view.

## Picks

1. **Lift into 3D (built in this branch).** Counted objects become colour-matched tokens on a table you can orbit. It works in the simulator, and it is the base the AR overlay and the visionOS volume reuse.
2. **Real size from a bank card.** Find the card with `DetectRectanglesRequest`, convert pixels to millimetres, and show each object's diameter. Tokens then become life-size, which is what AR placement needs.
3. **Any shape, any background.** Use `GenerateForegroundInstanceMaskRequest` instead of the colour mask, and extrude each outline instead of drawing a cylinder: leaves, cookies or hand-drawn shapes become 3D pieces.
