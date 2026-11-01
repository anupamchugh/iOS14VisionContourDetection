# Contour Lab

Count round things in a photo — coins, fruit, pills, seeds — on the iPhone, with Apple's Vision framework.

| Before | After: 51 coins found |
|---|---|
| ![A photo of euro coins on a grey sheet](docs/coins-original.jpg) | ![The same photo with a circle around each of the 51 coins](docs/coins-counted.jpg) |

<img src="docs/app-screenshot.png" width="320" alt="Contour Lab on an iOS 27.1 simulator showing 51 coins counted">

This repo started in 2020 as a sample for [VNDetectContoursRequest](https://developer.apple.com/documentation/vision/vndetectcontoursrequest) that drew every contour Vision found. Contour Lab turns it into a counter.

## How it counts

1. **Separate objects from the background.** `BackgroundMask` reads the background colour from the photo's border and marks every pixel that differs from it. Holes inside an object, like a shiny highlight, are filled.
2. **Outline them.** Vision's `VNDetectContoursRequest` draws the outlines of the object areas (the thin white lines in the app).
3. **Split touching objects.** Coins that touch make one outline. `CircleFinder` measures how far each object pixel is from the background; the centre of a round object is the farthest point, so each peak is one object and its height is the radius. Circles that cut deep into others (the shadow between two coins) are dropped.
4. **Say what was found.** `CountSummary` writes one sentence from those numbers, for example *"Found 51 round objects in 2 size groups (7 and 44)."*

Works best with a plain background that differs in colour from the objects, and with objects that are roughly round.

## Apple Intelligence and Siri

- **On-device model (iOS 27).** When Apple Intelligence is available, the app shows the photo to the on-device model with Foundation Models' `Attachment` and asks what the objects are. The model never counts: it's told not to, any reply containing a digit is dropped, and the number on screen always comes from Vision.
- **Siri and Shortcuts.** `CountObjectsIntent` counts the objects in a photo without opening the app. Say *"Count objects with Contour Lab"*, or use it in a shortcut or on the Action button.

## Run it

```bash
brew install xcodegen
xcodegen generate
open ContourLab.xcodeproj
```

Requires Xcode 27 and iOS 26 or later. The on-device model needs iOS 27 on a device with Apple Intelligence.

Run the counter's tests on the Mac (Vision runs on macOS too):

```bash
cd ContourLabKit && swift test
```

## Layout

| Path | What |
|---|---|
| `ContourLabKit/` | The counter as a Swift package: `BackgroundMask`, `CircleFinder`, `ContourCounter`, `ShapeMetrics`, `CountSummary`, with tests |
| `ContourLab/` | The SwiftUI app, the on-device model note and the App Intent |
| `project.yml` | XcodeGen project for iPhone and iPad |

## Licence

Code: MIT, see [LICENSE](LICENSE). The coin photo has been in this repo since 2020 and its original source isn't recorded; replace it before reusing it elsewhere.
