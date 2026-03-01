//
//  SnappingEngine.swift
//  Clippy
//

import SwiftUI

struct SnapResult {
    var adjustedRect: CGRect
    var verticalGuide: CGFloat?
    var horizontalGuide: CGFloat?
}

struct SnappingEngine {
    static let threshold: CGFloat = 5.0

    static func snap(
        movingRect: CGRect,
        annotations: [Annotation],
        excludeID: UUID?,
        imageSize: CGSize
    ) -> SnapResult {
        var result = SnapResult(adjustedRect: movingRect)

        // Collect snap targets from other annotations + image edges
        var xTargets: [CGFloat] = [0, imageSize.width / 2, imageSize.width]
        var yTargets: [CGFloat] = [0, imageSize.height / 2, imageSize.height]

        for ann in annotations where ann.id != excludeID {
            xTargets.append(contentsOf: [ann.rect.minX, ann.rect.midX, ann.rect.maxX])
            yTargets.append(contentsOf: [ann.rect.minY, ann.rect.midY, ann.rect.maxY])
        }

        // Check moving rect's edges and center against targets
        let movingXs: [(CGFloat, CGFloat)] = [
            (movingRect.minX, 0),
            (movingRect.midX, movingRect.width / 2),
            (movingRect.maxX, movingRect.width)
        ]
        let movingYs: [(CGFloat, CGFloat)] = [
            (movingRect.minY, 0),
            (movingRect.midY, movingRect.height / 2),
            (movingRect.maxY, movingRect.height)
        ]

        var bestDx: CGFloat?
        var bestDxDist: CGFloat = .greatestFiniteMagnitude

        for (mx, _) in movingXs {
            for tx in xTargets {
                let dist = abs(mx - tx)
                if dist < threshold && dist < bestDxDist {
                    bestDx = tx - mx
                    bestDxDist = dist
                    result.verticalGuide = tx
                }
            }
        }

        var bestDy: CGFloat?
        var bestDyDist: CGFloat = .greatestFiniteMagnitude

        for (my, _) in movingYs {
            for ty in yTargets {
                let dist = abs(my - ty)
                if dist < threshold && dist < bestDyDist {
                    bestDy = ty - my
                    bestDyDist = dist
                    result.horizontalGuide = ty
                }
            }
        }

        var adjusted = movingRect
        if let dx = bestDx {
            adjusted.origin.x += dx
        }
        if let dy = bestDy {
            adjusted.origin.y += dy
        }
        result.adjustedRect = adjusted

        return result
    }
}
