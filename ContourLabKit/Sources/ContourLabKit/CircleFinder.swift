import Foundation

/// A circle in mask pixels.
public struct FoundCircle: Sendable, Equatable {
    public let x: Double
    public let y: Double
    public let radius: Double
}

/// Finds round objects in a mask, one per object even when objects touch.
///
/// Each object pixel gets its distance to the nearest background pixel. The centre of a round object
/// is the farthest point from its edge, so the peaks of that distance map are the centres and their
/// heights are the radii. Two touching coins form one blob with two peaks, so they count as two.
public enum CircleFinder {
    public static func circles(in mask: ObjectMask, minimumRadius: Double) -> [FoundCircle] {
        let distance = distanceMap(mask)
        let width = mask.width, height = mask.height
        var candidates: [(index: Int, value: Double)] = []
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let index = y * width + x
                let value = distance[index]
                guard value >= minimumRadius else { continue }
                var isPeak = true
                neighbours: for dy in -1...1 {
                    for dx in -1...1 where distance[index + dy * width + dx] > value {
                        isPeak = false
                        break neighbours
                    }
                }
                if isPeak { candidates.append((index, value)) }
            }
        }

        // Largest first; a candidate inside a circle already found belongs to that object.
        var found: [FoundCircle] = []
        for candidate in candidates.sorted(by: { $0.value > $1.value }) {
            let x = Double(candidate.index % width), y = Double(candidate.index / width)
            let insideAnother = found.contains { hypot($0.x - x, $0.y - y) < $0.radius }
            if !insideAnother { found.append(FoundCircle(x: x, y: y, radius: candidate.value)) }
        }
        return removingOverlaps(found)
    }

    /// Touching objects barely overlap. A circle that cuts deep into others is a shadow between two
    /// objects or a bridge across several, so the circle with the most deep overlaps goes first
    /// (the smaller one on a tie) until none are left.
    static func removingOverlaps(_ circles: [FoundCircle], depth: Double = 0.8) -> [FoundCircle] {
        var kept = circles
        while true {
            let overlaps = kept.map { circle in
                kept.filter { other in
                    other != circle && hypot(other.x - circle.x, other.y - circle.y) < depth * (other.radius + circle.radius)
                }.count
            }
            guard let worst = overlaps.max(), worst > 0 else { return kept }
            let index = kept.indices
                .filter { overlaps[$0] == worst }
                .min { kept[$0].radius < kept[$1].radius }!
            kept.remove(at: index)
        }
    }

    /// Two-pass chamfer distance (3-4 weights), in pixels, close to the true Euclidean distance.
    static func distanceMap(_ mask: ObjectMask) -> [Double] {
        let width = mask.width, height = mask.height
        let far = Double(width + height) * 3
        var d = mask.pixels.map { $0 ? far : 0 }
        let straight = 3.0, diagonal = 4.0
        for y in 0..<height {
            for x in 0..<width {
                let i = y * width + x
                guard d[i] > 0 else { continue }
                if x > 0 { d[i] = min(d[i], d[i - 1] + straight) } else { d[i] = min(d[i], straight) }
                if y > 0 {
                    d[i] = min(d[i], d[i - width] + straight)
                    if x > 0 { d[i] = min(d[i], d[i - width - 1] + diagonal) }
                    if x < width - 1 { d[i] = min(d[i], d[i - width + 1] + diagonal) }
                } else { d[i] = min(d[i], straight) }
            }
        }
        for y in stride(from: height - 1, through: 0, by: -1) {
            for x in stride(from: width - 1, through: 0, by: -1) {
                let i = y * width + x
                guard d[i] > 0 else { continue }
                if x < width - 1 { d[i] = min(d[i], d[i + 1] + straight) } else { d[i] = min(d[i], straight) }
                if y < height - 1 {
                    d[i] = min(d[i], d[i + width] + straight)
                    if x < width - 1 { d[i] = min(d[i], d[i + width + 1] + diagonal) }
                    if x > 0 { d[i] = min(d[i], d[i + width - 1] + diagonal) }
                } else { d[i] = min(d[i], straight) }
            }
        }
        return d.map { $0 / straight }
    }
}
