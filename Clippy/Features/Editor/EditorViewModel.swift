//
//  EditorViewModel.swift
//  Clippy
//

import SwiftUI
import Combine

class ScreenshotEditorViewModel: ObservableObject {
    @Published var annotations: [Annotation] = []
    @Published var currentNumber: Int = 1

    deinit {
        annotations.removeAll()
        // Cleanup on deinit
    }

    func addAnnotation(_ annotation: Annotation, undoManager: UndoManager?) {
        annotations.append(annotation)
        undoManager?.registerUndo(withTarget: self) { target in
            target.removeLastAnnotation(undoManager: undoManager)
        }
        objectWillChange.send()
    }

    func removeLastAnnotation(undoManager: UndoManager?) {
        guard let lastAnnotation = annotations.popLast() else { return }
        undoManager?.registerUndo(withTarget: self) { target in
            target.addAnnotation(lastAnnotation, undoManager: undoManager)
        }
        objectWillChange.send()
    }

    func moveAnnotation(at index: Int, to newRect: CGRect, from oldRect: CGRect, undoManager: UndoManager?) {
        guard index < annotations.count else { return }
        let originalRect = annotations[index].rect
        annotations[index].rect = newRect
        undoManager?.registerUndo(withTarget: self) { target in
            target.moveAnnotation(at: index, to: originalRect, from: newRect, undoManager: undoManager)
        }
        objectWillChange.send()
    }

    func updateAnnotationRect(at index: Int, newRect: CGRect, oldRect: CGRect, undoManager: UndoManager?) {
        guard index < annotations.count else { return }
        annotations[index].rect = newRect

        if annotations[index].tool == .pen, let path = annotations[index].path {
            if oldRect.width > 0, oldRect.height > 0 {
                let scaledPath = path.map { point in
                    let normalizedX = (point.x - oldRect.minX) / oldRect.width
                    let normalizedY = (point.y - oldRect.minY) / oldRect.height

                    return CGPoint(
                        x: newRect.minX + normalizedX * newRect.width,
                        y: newRect.minY + normalizedY * newRect.height
                    )
                }
                annotations[index].path = scaledPath
            } else {
                // Zero dimension: translate only
                let dx = newRect.minX - oldRect.minX
                let dy = newRect.minY - oldRect.minY
                annotations[index].path = path.map { CGPoint(x: $0.x + dx, y: $0.y + dy) }
            }
        }

        undoManager?.registerUndo(withTarget: self) { target in
            target.updateAnnotationRect(at: index, newRect: oldRect, oldRect: newRect, undoManager: undoManager)
        }
        objectWillChange.send()
    }

    func removeAnnotation(with id: UUID, undoManager: UndoManager?) {
        guard let index = annotations.firstIndex(where: { $0.id == id }) else { return }
        let removedAnnotation = annotations.remove(at: index)

        undoManager?.registerUndo(withTarget: self) { target in
            target.insertAnnotation(removedAnnotation, at: index, undoManager: undoManager)
        }
        objectWillChange.send()
    }

    func insertAnnotation(_ annotation: Annotation, at index: Int, undoManager: UndoManager?) {
        guard index <= annotations.count else { return }
        annotations.insert(annotation, at: index)
        undoManager?.registerUndo(withTarget: self) { target in
            target.removeAnnotation(with: annotation.id, undoManager: undoManager)
        }
        objectWillChange.send()
    }

    func updateAnnotationText(at index: Int, newText: String, oldText: String, undoManager: UndoManager?) {
        guard index < annotations.count else { return }
        annotations[index].text = newText
        undoManager?.registerUndo(withTarget: self) { target in
            target.updateAnnotationText(at: index, newText: oldText, oldText: newText, undoManager: undoManager)
        }
        objectWillChange.send()
    }

    func nudgeAnnotation(at index: Int, dx: CGFloat, dy: CGFloat, undoManager: UndoManager?) {
        guard index < annotations.count else { return }
        annotations[index].rect = annotations[index].rect.offsetBy(dx: dx, dy: dy)
        if let sp = annotations[index].startPoint {
            annotations[index].startPoint = CGPoint(x: sp.x + dx, y: sp.y + dy)
        }
        if let ep = annotations[index].endPoint {
            annotations[index].endPoint = CGPoint(x: ep.x + dx, y: ep.y + dy)
        }
        if let cp = annotations[index].controlPoint {
            annotations[index].controlPoint = CGPoint(x: cp.x + dx, y: cp.y + dy)
        }
        if let path = annotations[index].path {
            annotations[index].path = path.map { CGPoint(x: $0.x + dx, y: $0.y + dy) }
        }
        undoManager?.registerUndo(withTarget: self) { target in
            target.nudgeAnnotation(at: index, dx: -dx, dy: -dy, undoManager: undoManager)
        }
        objectWillChange.send()
    }

    func updateAnnotationEndpoints(at index: Int,
                                   newStart: CGPoint?, newEnd: CGPoint?, newControlPoint: CGPoint?, newRect: CGRect,
                                   oldStart: CGPoint?, oldEnd: CGPoint?, oldControlPoint: CGPoint?, oldRect: CGRect,
                                   undoManager: UndoManager?) {
        guard index < annotations.count else { return }
        annotations[index].startPoint = newStart
        annotations[index].endPoint = newEnd
        annotations[index].controlPoint = newControlPoint
        annotations[index].rect = newRect
        undoManager?.registerUndo(withTarget: self) { target in
            target.updateAnnotationEndpoints(at: index,
                                             newStart: oldStart, newEnd: oldEnd, newControlPoint: oldControlPoint, newRect: oldRect,
                                             oldStart: newStart, oldEnd: newEnd, oldControlPoint: newControlPoint, oldRect: newRect,
                                             undoManager: undoManager)
        }
        objectWillChange.send()
    }
}
