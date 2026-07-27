//
//  EditorCanvasView.swift
//  Clippy
//

import SwiftUI

struct DrawingCanvasView: View {
    let image: NSImage
    @ObservedObject var viewModel: ScreenshotEditorViewModel
    @Binding var selectedTool: DrawingTool
    @Binding var selectedColor: Color
    @Binding var selectedLineWidth: CGFloat
    @Binding var numberSize: CGFloat
    /// Remembered text point size (0 = none chosen yet, derive from image).
    var textPointSize: Binding<CGFloat> = .constant(0)
    @Binding var numberShape: NumberShape
    @Binding var shapeCornerRadius: CGFloat
    @Binding var shapeFillMode: FillMode
    @Binding var spotlightShape: SpotlightShape
    @Binding var selectedEmoji: String
    @Binding var emojiSize: CGFloat
    @Binding var selectedBrushStyle: BrushStyle
    @Binding var movingAnnotationID: UUID?
    @Binding var dragOffset: CGSize
    @Binding var editingTextIndex: Int?
    @Binding var showToolControls: Bool
    @Binding var selectedAnnotationID: UUID?
    @Binding var isEditingText: Bool
    let backdropPadding: CGFloat
    let canvasSize: CGSize
    var blurRadius: CGFloat = 10
    var blurMode: BlurMode = .full
    @Binding var cropRect: CGRect?
    var cropAspectRatio: CropAspectRatio = .free
    var annotationOpacity: CGFloat = 1.0
    var dashedStroke: Bool = false
    var textIsBold: Bool = false
    var textIsItalic: Bool = false
    var textAlignment: TextAlignment = .left
    var calloutTailDirection: CalloutTailDirection = .bottomLeft
    var onTextAnnotationCreated: (UUID) -> Void
    var onStartEditingText: (Int) -> Void
    var onStopEditingText: () -> Void
    var onPickColor: ((CGPoint) -> Void)?
    var onEyedropperHover: ((CGPoint, NSPoint) -> Void)?
    var zoomScale: CGFloat = 1.0

    @Environment(\.undoManager) private var undoManager

    @State private var liveDrawingStart: CGPoint?
    @State private var liveDrawingEnd: CGPoint?
    @State private var liveDrawingPath: [CGPoint]?

    @State private var resizingHandle: ResizeHandle?
    @State private var originalRect: CGRect?

    @State private var snapVerticalGuide: CGFloat?
    @State private var snapHorizontalGuide: CGFloat?
    @State private var draggingControlPoint: Bool = false
    @State private var draggingEndpointIsStart: Bool? = nil  // true=start, false=end, nil=not dragging
    @State private var preDragControlPoint: CGPoint?
    @State private var preDragStartPoint: CGPoint?
    @State private var preDragEndPoint: CGPoint?
    @State private var preDragRect: CGRect?

    enum ResizeHandle {
        case topLeft, top, topRight
        case left, right
        case bottomLeft, bottom, bottomRight
    }

    var body: some View {
        Canvas { context, size in
            let imageSize = image.size
            let scale = min(canvasSize.width / imageSize.width, canvasSize.height / imageSize.height)

            let scaledImageSize = CGSize(
                width: imageSize.width * scale,
                height: imageSize.height * scale
            )

            let imageOffset = CGPoint(
                x: (canvasSize.width - scaledImageSize.width) / 2,
                y: (canvasSize.height - scaledImageSize.height) / 2
            )

                for annotation in viewModel.annotations {
                    var displayRect = CGRect(
                        x: annotation.rect.origin.x * scale + imageOffset.x,
                        y: annotation.rect.origin.y * scale + imageOffset.y,
                        width: annotation.rect.width * scale,
                        height: annotation.rect.height * scale
                    )

                    let isMoving = annotation.id == movingAnnotationID
                    if isMoving {
                        displayRect = displayRect.offsetBy(dx: dragOffset.width, dy: dragOffset.height)
                        context.addFilter(.shadow(color: .black.opacity(0.5), radius: 5))
                    }

                    var displayAnnotation = annotation
                    displayAnnotation.rect = displayRect
                    displayAnnotation.lineWidth = annotation.lineWidth * scale
                    if let start = annotation.startPoint {
                        var displayStart = CGPoint(
                            x: start.x * scale + imageOffset.x,
                            y: start.y * scale + imageOffset.y
                        )
                        if isMoving {
                            displayStart.x += dragOffset.width
                            displayStart.y += dragOffset.height
                        }
                        displayAnnotation.startPoint = displayStart
                    }
                    if let end = annotation.endPoint {
                        var displayEnd = CGPoint(
                            x: end.x * scale + imageOffset.x,
                            y: end.y * scale + imageOffset.y
                        )
                        if isMoving {
                            displayEnd.x += dragOffset.width
                            displayEnd.y += dragOffset.height
                        }
                        displayAnnotation.endPoint = displayEnd
                    }
                    if let path = annotation.path {
                        displayAnnotation.path = path.map { point in
                            var displayPoint = CGPoint(
                                x: point.x * scale + imageOffset.x,
                                y: point.y * scale + imageOffset.y
                            )
                            if isMoving {
                                displayPoint.x += dragOffset.width
                                displayPoint.y += dragOffset.height
                            }
                            return displayPoint
                        }
                    }
                    if let cp = annotation.controlPoint {
                        var displayCP = CGPoint(
                            x: cp.x * scale + imageOffset.x,
                            y: cp.y * scale + imageOffset.y
                        )
                        if isMoving {
                            displayCP.x += dragOffset.width
                            displayCP.y += dragOffset.height
                        }
                        displayAnnotation.controlPoint = displayCP
                    }

                    // The Inspector offers a SHADOW toggle, colour and radius
                    // for seven tools (rect, ellipse, callout, arrow, line,
                    // text, pin) — but nothing ever read those fields, so
                    // the whole section was inert. Applying it once around
                    // the draw covers every tool that advertises it, rather
                    // than needing the same block repeated per case.
                    if displayAnnotation.shadowRadius > 0 {
                        context.drawLayer { layer in
                            layer.addFilter(.shadow(
                                color: displayAnnotation.shadowColor,
                                radius: displayAnnotation.shadowRadius,
                                x: displayAnnotation.shadowOffset.width,
                                y: displayAnnotation.shadowOffset.height
                            ))
                            drawSingleAnnotation(displayAnnotation, rect: displayRect, in: &layer, canvasSize: size, nsImage: image)
                        }
                    } else {
                        drawSingleAnnotation(displayAnnotation, rect: displayRect, in: &context, canvasSize: size, nsImage: image)
                    }
                }

                if let start = liveDrawingStart, let end = liveDrawingEnd {
                    var rect = CGRect(from: start, to: end)

                    // Enforce crop aspect ratio during live drawing
                    if selectedTool == .crop, let ratio = cropAspectRatio.ratio {
                        let w = rect.width
                        let h = w / ratio
                        rect = CGRect(x: rect.origin.x, y: rect.origin.y, width: w, height: h)
                    }

                    var liveAnnotation = Annotation(rect: rect, color: selectedColor, lineWidth: selectedLineWidth, tool: selectedTool)
                    liveAnnotation.startPoint = start
                    liveAnnotation.endPoint = end

                    if selectedTool == .spotlight {
                        liveAnnotation.spotlightShape = spotlightShape
                    }

                    if selectedTool == .crop {
                        // Draw crop preview: dark overlay outside selection
                        var fullPath = Path(CGRect(origin: .zero, size: size))
                        fullPath.addPath(Path(rect))
                        context.fill(fullPath, with: .color(.black.opacity(0.5)), style: FillStyle(eoFill: true))
                        context.stroke(Path(rect), with: .color(.white), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    } else {
                        drawSingleAnnotation(liveAnnotation, rect: rect, in: &context, canvasSize: size, nsImage: image)
                    }
                }

                // Draw committed crop overlay
                if let crop = cropRect {
                    let displayCropRect = CGRect(
                        x: crop.origin.x * scale + imageOffset.x,
                        y: crop.origin.y * scale + imageOffset.y,
                        width: crop.width * scale,
                        height: crop.height * scale
                    )
                    var fullPath = Path(CGRect(origin: .zero, size: size))
                    fullPath.addPath(Path(displayCropRect))
                    context.fill(fullPath, with: .color(.black.opacity(0.5)), style: FillStyle(eoFill: true))
                    context.stroke(Path(displayCropRect), with: .color(.white), lineWidth: 1.5)
                }

                if let path = liveDrawingPath, path.count > 1 {
                    let canvasPath = path.map { point in
                        CGPoint(
                            x: point.x * scale + imageOffset.x,
                            y: point.y * scale + imageOffset.y
                        )
                    }

                    var bezierPath = Path()
                    bezierPath.move(to: canvasPath[0])
                    for i in 1..<canvasPath.count {
                        bezierPath.addLine(to: canvasPath[i])
                    }

                    let scaledLineWidth = selectedLineWidth * scale
                    switch selectedBrushStyle {
                    case .solid:
                        context.stroke(bezierPath, with: .color(selectedColor), lineWidth: scaledLineWidth)
                    case .dashed:
                        context.stroke(bezierPath, with: .color(selectedColor), style: StrokeStyle(lineWidth: scaledLineWidth, dash: [10, 5]))
                    case .marker:
                        context.stroke(bezierPath, with: .color(selectedColor.opacity(0.5)), style: StrokeStyle(lineWidth: scaledLineWidth * 2, lineCap: .round, lineJoin: .round))
                    }
                }

                // The annotation being edited draws its own frame (see the
                // `.text` case), so drawing the selection chrome on top of
                // it as well produced two offset dashed boxes.
                let editedID: UUID? = editingTextIndex.flatMap {
                    viewModel.annotations.indices.contains($0) ? viewModel.annotations[$0].id : nil
                }

                if let selectedID = selectedAnnotationID,
                   selectedID != editedID,
                   let selectedAnnotation = viewModel.annotations.first(where: { $0.id == selectedID }) {

                    // The annotation's own rect, for every tool.
                    //
                    // Text used to get a *recomputed* rect here, measured
                    // with a plain system font — ignoring bold, italic, the
                    // font family and letter spacing. So the selection
                    // frame and handles sat somewhere other than the box
                    // that was actually drawn. The box now tightens onto
                    // its content when editing ends, which is what that
                    // guesswork was standing in for.
                    let originalRect = selectedAnnotation.rect

                    let displayRect = CGRect(
                        x: originalRect.minX * scale + imageOffset.x,
                        y: originalRect.minY * scale + imageOffset.y,
                        width: originalRect.width * scale,
                        height: originalRect.height * scale
                    )

                    // For arrows/lines/rulers: use actual start/end points for handles
                    if (selectedAnnotation.tool == .arrow || selectedAnnotation.tool == .line || selectedAnnotation.tool == .ruler),
                       let start = selectedAnnotation.startPoint,
                       let end = selectedAnnotation.endPoint {
                        let handleSize: CGFloat = 8
                        let startScreen = CGPoint(x: start.x * scale + imageOffset.x, y: start.y * scale + imageOffset.y)
                        let endScreen = CGPoint(x: end.x * scale + imageOffset.x, y: end.y * scale + imageOffset.y)

                        for pos in [startScreen, endScreen] {
                            let handleRect = CGRect(x: pos.x - handleSize / 2, y: pos.y - handleSize / 2, width: handleSize, height: handleSize)
                            context.fill(Path(ellipseIn: handleRect), with: .color(.white))
                            context.stroke(Path(ellipseIn: handleRect), with: .color(.blue), lineWidth: 2)
                        }

                        // Control point handle for curved arrows
                        if selectedAnnotation.tool == .arrow {
                            let cp = selectedAnnotation.controlPoint ?? CGPoint(
                                x: (start.x + end.x) / 2,
                                y: (start.y + end.y) / 2
                            )
                            let cpScreen = CGPoint(x: cp.x * scale + imageOffset.x, y: cp.y * scale + imageOffset.y)
                            let cpSize: CGFloat = 10
                            let cpRect = CGRect(x: cpScreen.x - cpSize / 2, y: cpScreen.y - cpSize / 2, width: cpSize, height: cpSize)
                            context.fill(Path(ellipseIn: cpRect), with: .color(.orange))
                            context.stroke(Path(ellipseIn: cpRect), with: .color(.white), lineWidth: 2)
                        }
                    } else {
                        // Bounding box, not just the handles. Handles alone
                        // leave the edges to be inferred — obvious for a
                        // filled rectangle, but a text box whose content
                        // doesn't reach its edges gave no clue where it ended.
                        strokeContrastOutline(Path(displayRect), in: &context)

                        let handlePositions = getHandlePositions(for: displayRect, tool: selectedAnnotation.tool)
                        let handleSize: CGFloat = 8

                        for (_, position) in handlePositions {
                            let handleRect = CGRect(x: position.x - handleSize / 2,
                                                   y: position.y - handleSize / 2,
                                                   width: handleSize,
                                                   height: handleSize)
                            // Dark rim under the handle so it reads on a
                            // white background too, where a white dot on
                            // white was previously just the blue ring.
                            context.stroke(Path(ellipseIn: handleRect.insetBy(dx: -1, dy: -1)),
                                           with: .color(.black.opacity(0.4)), lineWidth: 1)
                            context.fill(Path(ellipseIn: handleRect), with: .color(.white))
                            context.stroke(Path(ellipseIn: handleRect), with: .color(.blue), lineWidth: 2)
                        }
                    }
                }

                // Snap guide lines — amber for visibility on light backgrounds
                let snapColor = Ember.Palette.amber.opacity(0.85)
                if let vg = snapVerticalGuide {
                    let screenX = vg * scale + imageOffset.x
                    var guidePath = Path()
                    guidePath.move(to: CGPoint(x: screenX, y: 0))
                    guidePath.addLine(to: CGPoint(x: screenX, y: canvasSize.height))
                    context.stroke(guidePath, with: .color(snapColor),
                                   style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                }
                if let hg = snapHorizontalGuide {
                    let screenY = hg * scale + imageOffset.y
                    var guidePath = Path()
                    guidePath.move(to: CGPoint(x: 0, y: screenY))
                    guidePath.addLine(to: CGPoint(x: canvasSize.width, y: screenY))
                    context.stroke(guidePath, with: .color(snapColor),
                                   style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                }

            }
            .gesture(drawingGesture(in: canvasSize))
            .onTapGesture(count: 2) { location in
                handleDoubleTap(at: location, in: canvasSize)
            }
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    updateCursor(at: location, in: canvasSize)
                    if selectedTool == .eyedropper {
                        let imageSize = image.size
                        let scale = min(canvasSize.width / imageSize.width, canvasSize.height / imageSize.height)
                        let scaledImageSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
                        let imageOffset = CGPoint(
                            x: (canvasSize.width - scaledImageSize.width) / 2,
                            y: (canvasSize.height - scaledImageSize.height) / 2
                        )
                        let imageLocation = CGPoint(
                            x: (location.x - imageOffset.x) / scale,
                            y: (location.y - imageOffset.y) / scale
                        )
                        let screenPoint = NSEvent.mouseLocation
                        onEyedropperHover?(imageLocation, screenPoint)
                    }
                case .ended:
                    NSCursor.arrow.set()
                }
            }
    }

    private func handleDoubleTap(at location: CGPoint, in canvasSize: CGSize) {
        let imageSize = image.size
        let scale = min(canvasSize.width / imageSize.width, canvasSize.height / imageSize.height)
        let scaledImageSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let imageOffset = CGPoint(
            x: (canvasSize.width - scaledImageSize.width) / 2,
            y: (canvasSize.height - scaledImageSize.height) / 2
        )

        let imageLocation = CGPoint(
            x: (location.x - imageOffset.x) / scale,
            y: (location.y - imageOffset.y) / scale
        )

        if let (id, index) = findAnnotation(at: imageLocation) {
            let annotation = viewModel.annotations[index]
            if annotation.tool == .text {
                selectedAnnotationID = id
                selectedTool = .select
                onStartEditingText(index)
                showToolControls = true
            }
        }
    }

    private func updateCursor(at location: CGPoint, in canvasSize: CGSize) {
        let imageSize = image.size
        let scale = min(canvasSize.width / imageSize.width, canvasSize.height / imageSize.height)
        let scaledImageSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let imageOffset = CGPoint(
            x: (canvasSize.width - scaledImageSize.width) / 2,
            y: (canvasSize.height - scaledImageSize.height) / 2
        )

        let imageLocation = CGPoint(
            x: (location.x - imageOffset.x) / scale,
            y: (location.y - imageOffset.y) / scale
        )

        if selectedTool != .eraser {
            if (selectedTool == .select || selectedTool == .move) {
                if let selectedID = selectedAnnotationID,
                   let annotation = viewModel.annotations.first(where: { $0.id == selectedID }),
                   !isEditingText {
                    if let _ = detectHandle(at: imageLocation, for: annotation.rect, tool: annotation.tool) {
                        NSCursor.crosshair.set()
                        return
                    }
                }
            }

            if let _ = findAnnotation(at: imageLocation) {
                NSCursor.openHand.set()
                return
            }
        }

        switch selectedTool {
        case .pen:
            NSCursor.crosshair.set()
        case .eraser:
            NSCursor.crosshair.set()
        default:
            NSCursor.arrow.set()
        }
    }

    private func drawingGesture(in canvasSize: CGSize) -> some Gesture {
        let imageSize = image.size
        let scale = min(canvasSize.width / imageSize.width, canvasSize.height / imageSize.height)

        let scaledImageSize = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )

        let imageOffset = CGPoint(
            x: (canvasSize.width - scaledImageSize.width) / 2,
            y: (canvasSize.height - scaledImageSize.height) / 2
        )

        func toImageCoords(_ point: CGPoint) -> CGPoint {
            return CGPoint(
                x: (point.x - imageOffset.x) / scale,
                y: (point.y - imageOffset.y) / scale
            )
        }

        func toImageSize(_ size: CGSize) -> CGSize {
            return CGSize(width: size.width / scale, height: size.height / scale)
        }

        return DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                let imageLocation = toImageCoords(value.location)

                // Control point dragging for curved arrows
                if draggingControlPoint {
                    if let selectedID = selectedAnnotationID,
                       let index = viewModel.annotations.firstIndex(where: { $0.id == selectedID }) {
                        viewModel.annotations[index].controlPoint = imageLocation
                    }
                    return
                }

                // Direct endpoint dragging for arrows/lines/rulers
                if let isStart = draggingEndpointIsStart {
                    if let selectedID = selectedAnnotationID,
                       let index = viewModel.annotations.firstIndex(where: { $0.id == selectedID }) {
                        if isStart {
                            viewModel.annotations[index].startPoint = imageLocation
                        } else {
                            viewModel.annotations[index].endPoint = imageLocation
                        }
                        let s = viewModel.annotations[index].startPoint ?? imageLocation
                        let e = viewModel.annotations[index].endPoint ?? imageLocation
                        viewModel.annotations[index].rect = CGRect(from: s, to: e)
                    }
                    return
                }

                if movingAnnotationID != nil {
                    dragOffset = value.translation
                    return
                }

                switch selectedTool {
                case .select:
                    if resizingHandle == nil, movingAnnotationID == nil {
                        if let selectedID = selectedAnnotationID,
                           let annotation = viewModel.annotations.first(where: { $0.id == selectedID }) {
                            let isEditingThisText = isEditingText && viewModel.annotations.firstIndex(where: { $0.id == selectedID }) == editingTextIndex

                            if !isEditingThisText {
                                // Direct endpoint/controlpoint detection for arrows/lines/rulers.
                                // If the click didn't land on a control point or endpoint we
                                // FALL THROUGH to the normal resize/move/findAnnotation chain,
                                // so clicking the middle of a line can still move it.
                                var consumedByEndpointDrag = false

                                if (annotation.tool == .arrow || annotation.tool == .line || annotation.tool == .ruler),
                                   let start = annotation.startPoint,
                                   let end = annotation.endPoint {
                                    if annotation.tool == .arrow {
                                        let cp = annotation.controlPoint ?? CGPoint(
                                            x: (start.x + end.x) / 2,
                                            y: (start.y + end.y) / 2
                                        )
                                        let dist = hypot(imageLocation.x - cp.x, imageLocation.y - cp.y)
                                        if dist < 12 {
                                            preDragControlPoint = annotation.controlPoint
                                            preDragStartPoint = start
                                            preDragEndPoint = end
                                            preDragRect = annotation.rect
                                            if annotation.controlPoint == nil,
                                               let idx = viewModel.annotations.firstIndex(where: { $0.id == annotation.id }) {
                                                viewModel.annotations[idx].controlPoint = cp
                                            }
                                            draggingControlPoint = true
                                            consumedByEndpointDrag = true
                                        }
                                    }

                                    if !consumedByEndpointDrag {
                                        let startDist = hypot(imageLocation.x - start.x, imageLocation.y - start.y)
                                        let endDist = hypot(imageLocation.x - end.x, imageLocation.y - end.y)
                                        if startDist < 12 {
                                            preDragStartPoint = start
                                            preDragEndPoint = end
                                            preDragRect = annotation.rect
                                            draggingEndpointIsStart = true
                                            consumedByEndpointDrag = true
                                        } else if endDist < 12 {
                                            preDragStartPoint = start
                                            preDragEndPoint = end
                                            preDragRect = annotation.rect
                                            draggingEndpointIsStart = false
                                            consumedByEndpointDrag = true
                                        }
                                    }
                                }

                                if consumedByEndpointDrag {
                                    return
                                }

                                // For lines/arrows/rulers, clicking the middle of the shaft should
                                // select-and-move even though rect.contains() fails for zero-height /
                                // zero-width bounding rects. Use the distance-based hit test.
                                let isStrokeShape = annotation.tool == .arrow ||
                                                    annotation.tool == .line ||
                                                    annotation.tool == .ruler

                                if let handle = detectHandle(at: imageLocation, for: annotation.rect, tool: annotation.tool) {
                                    resizingHandle = handle
                                    originalRect = annotation.rect
                                } else if !isStrokeShape && annotation.rect.contains(imageLocation) {
                                    movingAnnotationID = selectedID
                                    dragOffset = .zero
                                } else if isStrokeShape, let hit = findAnnotation(at: imageLocation), hit.id == selectedID {
                                    // Clicked on the stroke (middle of the line) — start moving it.
                                    movingAnnotationID = selectedID
                                    dragOffset = .zero
                                } else if let (id, index) = findAnnotation(at: imageLocation) {
                                    let clickedAnnotation = viewModel.annotations[index]
                                    selectedAnnotationID = id

                                    let isEditingThisText = clickedAnnotation.tool == .text && isEditingText && editingTextIndex == index
                                    if !isEditingThisText {
                                        movingAnnotationID = id
                                        dragOffset = .zero
                                    }
                                }
                            }
                        } else if let (id, index) = findAnnotation(at: imageLocation) {
                            let clickedAnnotation = viewModel.annotations[index]
                            selectedAnnotationID = id

                            let isEditingThisText = clickedAnnotation.tool == .text && isEditingText && editingTextIndex == index
                            if !isEditingThisText {
                                movingAnnotationID = id
                                dragOffset = .zero
                            }
                        }
                    }

                    if let handle = resizingHandle, let original = originalRect,
                       let selectedID = selectedAnnotationID,
                       let index = viewModel.annotations.firstIndex(where: { $0.id == selectedID }) {
                        let newRect = calculateResizedRect(originalRect: original, handle: handle, dragTo: imageLocation)
                        viewModel.annotations[index].rect = newRect
                        // Dragging a handle on text is a width decision, so
                        // it moves the wrap limit too. Setting only the rect
                        // would let the next keystroke re-clamp the box back
                        // to the old limit and undo the drag.
                        if viewModel.annotations[index].tool == .text {
                            viewModel.annotations[index].textWrapWidth = newRect.width
                        }
                    } else if let movID = movingAnnotationID,
                              let movIdx = viewModel.annotations.firstIndex(where: { $0.id == movID }) {
                        let imgTrans = toImageSize(value.translation)
                        let candidate = viewModel.annotations[movIdx].rect.offsetBy(dx: imgTrans.width, dy: imgTrans.height)
                        let snap = SnappingEngine.snap(movingRect: candidate, annotations: viewModel.annotations, excludeID: movID, imageSize: image.size)
                        snapVerticalGuide = snap.verticalGuide
                        snapHorizontalGuide = snap.horizontalGuide
                        dragOffset = value.translation
                    }
                case .move:
                    if resizingHandle == nil, movingAnnotationID == nil {
                        if let selectedID = selectedAnnotationID,
                           let annotation = viewModel.annotations.first(where: { $0.id == selectedID }) {
                            // Direct endpoint/controlpoint detection for arrows/lines/rulers
                            if (annotation.tool == .arrow || annotation.tool == .line || annotation.tool == .ruler),
                               let start = annotation.startPoint,
                               let end = annotation.endPoint {
                                if annotation.tool == .arrow {
                                    let cp = annotation.controlPoint ?? CGPoint(
                                        x: (start.x + end.x) / 2,
                                        y: (start.y + end.y) / 2
                                    )
                                    let dist = hypot(imageLocation.x - cp.x, imageLocation.y - cp.y)
                                    if dist < 12 {
                                        preDragControlPoint = annotation.controlPoint
                                        preDragStartPoint = start
                                        preDragEndPoint = end
                                        preDragRect = annotation.rect
                                        if annotation.controlPoint == nil,
                                           let idx = viewModel.annotations.firstIndex(where: { $0.id == annotation.id }) {
                                            viewModel.annotations[idx].controlPoint = cp
                                        }
                                        draggingControlPoint = true
                                        return
                                    }
                                }
                                let startDist = hypot(imageLocation.x - start.x, imageLocation.y - start.y)
                                let endDist = hypot(imageLocation.x - end.x, imageLocation.y - end.y)
                                if startDist < 12 {
                                    preDragStartPoint = start
                                    preDragEndPoint = end
                                    preDragRect = annotation.rect
                                    draggingEndpointIsStart = true
                                    return
                                } else if endDist < 12 {
                                    preDragStartPoint = start
                                    preDragEndPoint = end
                                    preDragRect = annotation.rect
                                    draggingEndpointIsStart = false
                                    return
                                }
                            } else if let handle = detectHandle(at: imageLocation, for: annotation.rect, tool: annotation.tool) {
                                resizingHandle = handle
                                originalRect = annotation.rect
                            }
                            if let (id, _) = findAnnotation(at: imageLocation) {
                                movingAnnotationID = id
                                dragOffset = .zero
                            }
                        } else if let (id, _) = findAnnotation(at: imageLocation) {
                            movingAnnotationID = id
                            dragOffset = .zero
                        }
                    }

                    if let handle = resizingHandle, let original = originalRect,
                       let selectedID = selectedAnnotationID,
                       let index = viewModel.annotations.firstIndex(where: { $0.id == selectedID }) {
                        let newRect = calculateResizedRect(originalRect: original, handle: handle, dragTo: imageLocation)
                        viewModel.annotations[index].rect = newRect
                        // Dragging a handle on text is a width decision, so
                        // it moves the wrap limit too. Setting only the rect
                        // would let the next keystroke re-clamp the box back
                        // to the old limit and undo the drag.
                        if viewModel.annotations[index].tool == .text {
                            viewModel.annotations[index].textWrapWidth = newRect.width
                        }
                    } else if let movID = movingAnnotationID,
                              let movIdx = viewModel.annotations.firstIndex(where: { $0.id == movID }) {
                        let imgTrans = toImageSize(value.translation)
                        let candidate = viewModel.annotations[movIdx].rect.offsetBy(dx: imgTrans.width, dy: imgTrans.height)
                        let snap = SnappingEngine.snap(movingRect: candidate, annotations: viewModel.annotations, excludeID: movID, imageSize: image.size)
                        snapVerticalGuide = snap.verticalGuide
                        snapHorizontalGuide = snap.horizontalGuide
                        dragOffset = value.translation
                    }
                case .eraser:
                     if let (id, _) = findAnnotation(at: imageLocation) {
                        viewModel.removeAnnotation(with: id, undoManager: undoManager)
                    }
                case .pin, .emoji:
                    if resizingHandle == nil,
                       let selectedID = selectedAnnotationID,
                       let annotation = viewModel.annotations.first(where: { $0.id == selectedID }) {
                        if let handle = detectHandle(at: imageLocation, for: annotation.rect, tool: annotation.tool) {
                            resizingHandle = handle
                            originalRect = annotation.rect
                        }
                    } else if resizingHandle != nil {
                        if let handle = resizingHandle, let original = originalRect,
                           let selectedID = selectedAnnotationID,
                           let index = viewModel.annotations.firstIndex(where: { $0.id == selectedID }) {
                            let newRect = calculateResizedRect(originalRect: original, handle: handle, dragTo: imageLocation)
                            viewModel.annotations[index].rect = newRect
                            if viewModel.annotations[index].tool == .text {
                                viewModel.annotations[index].textWrapWidth = newRect.width
                            }
                        }
                    }
                case .text:
                    // Drag defines the text box, the way it does in every
                    // other annotation app: click for a default-width box,
                    // drag when you want to say exactly how wide the text
                    // should wrap. Previously dragging did nothing at all,
                    // so the box was always a fixed guess.
                    if movingAnnotationID != nil || resizingHandle != nil {
                        break
                    }
                    if liveDrawingStart == nil {
                        liveDrawingStart = value.location
                    }
                    liveDrawingEnd = value.location

                case .pen:
                    if movingAnnotationID != nil {
                        break
                    }

                    if liveDrawingPath == nil {
                        liveDrawingPath = [imageLocation]
                    } else {
                        liveDrawingPath?.append(imageLocation)
                    }
                default:
                    if movingAnnotationID != nil {
                        break
                    }

                    if resizingHandle == nil, liveDrawingStart == nil,
                       let selectedID = selectedAnnotationID,
                       let annotation = viewModel.annotations.first(where: { $0.id == selectedID }) {
                        if let handle = detectHandle(at: imageLocation, for: annotation.rect, tool: annotation.tool) {
                            resizingHandle = handle
                            originalRect = annotation.rect
                        } else if annotation.tool == selectedTool {
                            liveDrawingStart = value.location
                            liveDrawingEnd = value.location
                        } else {
                            liveDrawingStart = value.location
                            liveDrawingEnd = value.location
                        }
                    } else if resizingHandle != nil {
                        if let handle = resizingHandle, let original = originalRect,
                           let selectedID = selectedAnnotationID,
                           let index = viewModel.annotations.firstIndex(where: { $0.id == selectedID }) {
                            let newRect = calculateResizedRect(originalRect: original, handle: handle, dragTo: imageLocation)
                            viewModel.annotations[index].rect = newRect
                            if viewModel.annotations[index].tool == .text {
                                viewModel.annotations[index].textWrapWidth = newRect.width
                            }
                        }
                    } else {
                        if liveDrawingStart == nil {
                            liveDrawingStart = value.location
                        }
                        liveDrawingEnd = value.location
                    }
                }
            }
            .onEnded { value in
                let imageLocation = toImageCoords(value.location)
                let imageTranslation = toImageSize(value.translation)
                let dragDistance = hypot(value.translation.width, value.translation.height)

                if draggingControlPoint {
                    if let selectedID = selectedAnnotationID,
                       let index = viewModel.annotations.firstIndex(where: { $0.id == selectedID }) {
                        let ann = viewModel.annotations[index]
                        viewModel.updateAnnotationEndpoints(
                            at: index,
                            newStart: ann.startPoint, newEnd: ann.endPoint, newControlPoint: ann.controlPoint, newRect: ann.rect,
                            oldStart: preDragStartPoint, oldEnd: preDragEndPoint, oldControlPoint: preDragControlPoint, oldRect: preDragRect ?? ann.rect,
                            undoManager: undoManager
                        )
                    }
                    draggingControlPoint = false
                    preDragControlPoint = nil
                    preDragStartPoint = nil
                    preDragEndPoint = nil
                    preDragRect = nil
                    return
                }

                if draggingEndpointIsStart != nil {
                    if let selectedID = selectedAnnotationID,
                       let index = viewModel.annotations.firstIndex(where: { $0.id == selectedID }) {
                        let ann = viewModel.annotations[index]
                        viewModel.updateAnnotationEndpoints(
                            at: index,
                            newStart: ann.startPoint, newEnd: ann.endPoint, newControlPoint: ann.controlPoint, newRect: ann.rect,
                            oldStart: preDragStartPoint, oldEnd: preDragEndPoint, oldControlPoint: ann.controlPoint, oldRect: preDragRect ?? ann.rect,
                            undoManager: undoManager
                        )
                    }
                    draggingEndpointIsStart = nil
                    preDragStartPoint = nil
                    preDragEndPoint = nil
                    preDragRect = nil
                    return
                }

                if resizingHandle != nil, let original = originalRect,
                   let selectedID = selectedAnnotationID,
                   let index = viewModel.annotations.firstIndex(where: { $0.id == selectedID }) {

                    if dragDistance >= 5 {
                        let finalRect = viewModel.annotations[index].rect
                        viewModel.updateAnnotationRect(at: index, newRect: finalRect, oldRect: original, undoManager: undoManager)
                        resizingHandle = nil
                        self.originalRect = nil
                        return
                    } else {
                        resizingHandle = nil
                        self.originalRect = nil
                    }
                }

                if let movingID = movingAnnotationID, let index = viewModel.annotations.firstIndex(where: { $0.id == movingID }) {
                    if dragDistance >= 5 {
                        let oldRect = viewModel.annotations[index].rect
                        let candidateRect = oldRect.offsetBy(dx: imageTranslation.width, dy: imageTranslation.height)
                        let snapResult = SnappingEngine.snap(
                            movingRect: candidateRect,
                            annotations: viewModel.annotations,
                            excludeID: movingID,
                            imageSize: image.size
                        )
                        let newRect = snapResult.adjustedRect
                        viewModel.moveAnnotation(at: index, to: newRect, from: oldRect, undoManager: undoManager)

                        let snappedDx = newRect.origin.x - oldRect.origin.x
                        let snappedDy = newRect.origin.y - oldRect.origin.y
                        let tool = viewModel.annotations[index].tool
                        if tool == .arrow || tool == .line || tool == .ruler {
                            if let start = viewModel.annotations[index].startPoint,
                               let end = viewModel.annotations[index].endPoint {
                                viewModel.annotations[index].startPoint = CGPoint(
                                    x: start.x + snappedDx,
                                    y: start.y + snappedDy
                                )
                                viewModel.annotations[index].endPoint = CGPoint(
                                    x: end.x + snappedDx,
                                    y: end.y + snappedDy
                                )
                            }
                            if let cp = viewModel.annotations[index].controlPoint {
                                viewModel.annotations[index].controlPoint = CGPoint(
                                    x: cp.x + snappedDx,
                                    y: cp.y + snappedDy
                                )
                            }
                        }
                        if tool == .pen, let path = viewModel.annotations[index].path {
                            viewModel.annotations[index].path = path.map {
                                CGPoint(x: $0.x + snappedDx, y: $0.y + snappedDy)
                            }
                        }

                        selectedAnnotationID = movingID
                        showToolControls = true
                        movingAnnotationID = nil
                        dragOffset = .zero
                        snapVerticalGuide = nil
                        snapHorizontalGuide = nil

                        liveDrawingStart = nil
                        liveDrawingEnd = nil
                        liveDrawingPath = nil
                        resizingHandle = nil
                        self.originalRect = nil

                        return
                    } else {
                        let annotation = viewModel.annotations[index]

                        if annotation.tool == .text {
                            selectedAnnotationID = movingID
                            showToolControls = true
                            onStartEditingText(index)
                        } else {
                            selectedAnnotationID = movingID
                            showToolControls = true
                        }

                        movingAnnotationID = nil
                        dragOffset = .zero
                        snapVerticalGuide = nil
                        snapHorizontalGuide = nil

                        liveDrawingStart = nil
                        liveDrawingEnd = nil
                        liveDrawingPath = nil

                        return
                    }
                }

                snapVerticalGuide = nil
                snapHorizontalGuide = nil

                if selectedTool == .select || selectedTool == .move {
                    if let (id, _) = findAnnotation(at: imageLocation) {
                        selectedAnnotationID = id
                        showToolControls = true
                        return
                    } else {
                        selectedAnnotationID = nil
                        showToolControls = false
                        resizingHandle = nil
                        self.originalRect = nil
                        movingAnnotationID = nil
                        dragOffset = .zero
                        if isEditingText {
                            onStopEditingText()
                        }
                    }
                } else if selectedTool == .eraser {
                    if dragDistance < 5 {
                        selectedAnnotationID = nil
                        showToolControls = false
                    }
                }

                switch selectedTool {
                case .select:
                    break
                case .move:
                    break
                case .eraser:
                    break
                case .eyedropper:
                    onPickColor?(imageLocation)
                    return
                case .pin:
                    // Clicking something that's already there selects it
                    // instead of stacking a new pin on top. The pin tool
                    // deliberately stays active after placing one (you
                    // usually want 1, 2, 3 in a row), which meant every
                    // attempt to adjust a pin created another one.
                    if let (existingID, _) = findAnnotation(at: imageLocation) {
                        selectedAnnotationID = existingID
                        showToolControls = true
                        break
                    }

                    let rect = CGRect(
                        x: imageLocation.x - numberSize / 2,
                        y: imageLocation.y - numberSize / 2,
                        width: numberSize,
                        height: numberSize
                    )

                    var newAnnotation = Annotation(rect: rect, color: selectedColor, lineWidth: selectedLineWidth, tool: .pin)
                    newAnnotation.number = viewModel.currentNumber
                    newAnnotation.numberShape = numberShape
                    newAnnotation.opacity = annotationOpacity
                    viewModel.currentNumber += 1
                    viewModel.addAnnotation(newAnnotation, undoManager: undoManager)
                    selectedAnnotationID = newAnnotation.id

                case .pen:
                    if movingAnnotationID != nil {
                        break
                    }

                    if let path = liveDrawingPath, path.count > 1 {
                        let minX = path.map { $0.x }.min() ?? 0
                        let maxX = path.map { $0.x }.max() ?? 0
                        let minY = path.map { $0.y }.min() ?? 0
                        let maxY = path.map { $0.y }.max() ?? 0
                        let rect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)

                        var newAnnotation = Annotation(rect: rect, color: selectedColor, lineWidth: selectedLineWidth, tool: .pen)
                        newAnnotation.path = path
                        newAnnotation.brushStyle = selectedBrushStyle
                        newAnnotation.opacity = annotationOpacity
                        viewModel.addAnnotation(newAnnotation, undoManager: undoManager)

                    }

                    liveDrawingPath = nil

                case .emoji:
                    if movingAnnotationID != nil {
                        break
                    }

                    if resizingHandle != nil, let original = originalRect,
                       let selectedID = selectedAnnotationID,
                       let index = viewModel.annotations.firstIndex(where: { $0.id == selectedID }) {
                        let finalRect = viewModel.annotations[index].rect
                        viewModel.updateAnnotationRect(at: index, newRect: finalRect, oldRect: original, undoManager: undoManager)
                        resizingHandle = nil
                        originalRect = nil
                    } else if let (existingID, _) = findAnnotation(at: imageLocation) {
                        // Same rule as pins: click something that exists and
                        // you get to edit it, not a duplicate on top of it.
                        selectedAnnotationID = existingID
                        showToolControls = true
                    } else {
                        let rect = CGRect(
                            x: imageLocation.x - emojiSize / 2,
                            y: imageLocation.y - emojiSize / 2,
                            width: emojiSize,
                            height: emojiSize
                        )

                        var newAnnotation = Annotation(rect: rect, color: selectedColor, lineWidth: selectedLineWidth, tool: .emoji)
                        newAnnotation.emoji = selectedEmoji
                        newAnnotation.opacity = annotationOpacity
                        viewModel.addAnnotation(newAnnotation, undoManager: undoManager)

                        selectedAnnotationID = newAnnotation.id
                        showToolControls = true

                        selectedTool = .select
                    }

                case .text:
                    if movingAnnotationID != nil {
                        break
                    }

                    if resizingHandle == nil {
                        // Text must not inherit the shape tools' stroke
                        // width. A width of 4 is a sensible line for a
                        // rectangle but means 16pt type — unreadably small
                        // on a Retina screenshot.
                        //
                        // If the user has picked a size before, that choice
                        // stands. Otherwise scale to the image, so a
                        // 2880px-tall capture gets proportionally larger
                        // type than an 800px one.
                        let remembered = textPointSize.wrappedValue
                        let defaultPointSize = remembered > 0
                            ? remembered
                            : min(max(image.size.height * 0.035, 20), 72)
                        let textLineWidth = AnnotationFont.lineWidth(fromPointSize: defaultPointSize)
                        let minHeight = defaultPointSize + CustomTextEditor.contentInset.height * 2

                        // A drag says "wrap the text inside exactly this";
                        // a plain click falls back to a sensible default
                        // width. The 8pt threshold keeps a slightly shaky
                        // click from being read as a tiny drag.
                        // A drag sets the wrap limit; the box still starts
                        // content-sized and grows into that limit as you
                        // type. See `Annotation.textWrapWidth`.
                        let rect: CGRect
                        let wrapWidth: CGFloat?
                        if let startPoint = liveDrawingStart,
                           let endPoint = liveDrawingEnd,
                           hypot(endPoint.x - startPoint.x, endPoint.y - startPoint.y) > 8 {
                            let s = toImageCoords(startPoint)
                            let e = toImageCoords(endPoint)
                            let limit = max(abs(e.x - s.x), 60)
                            rect = CGRect(
                                x: min(s.x, e.x),
                                y: min(s.y, e.y),
                                width: limit,
                                height: max(abs(e.y - s.y), minHeight)
                            )
                            wrapWidth = limit
                        } else {
                            rect = CGRect(
                                x: imageLocation.x,
                                y: imageLocation.y,
                                width: defaultPointSize * 4,
                                height: minHeight
                            )
                            wrapWidth = nil
                        }

                        liveDrawingStart = nil
                        liveDrawingEnd = nil

                        var newAnnotation = Annotation(rect: rect, color: selectedColor, lineWidth: textLineWidth, tool: .text)
                        newAnnotation.textWrapWidth = wrapWidth
                        // No default background — user toggles it on from Inspector with a contrast-aware preset.
                        newAnnotation.backgroundColor = nil
                        newAnnotation.opacity = annotationOpacity
                        newAnnotation.isBold = textIsBold
                        newAnnotation.isItalic = textIsItalic
                        newAnnotation.textAlignment = textAlignment
                        viewModel.addAnnotation(newAnnotation, undoManager: undoManager)

                        selectedAnnotationID = newAnnotation.id
                        showToolControls = true

                        selectedTool = .select

                        if let index = viewModel.annotations.lastIndex(where: { $0.id == newAnnotation.id }) {
                            onStartEditingText(index)
                        }
                    }

                default:
                    if resizingHandle != nil, let original = originalRect,
                       let selectedID = selectedAnnotationID,
                       let index = viewModel.annotations.firstIndex(where: { $0.id == selectedID }) {
                        let finalRect = viewModel.annotations[index].rect
                        viewModel.updateAnnotationRect(at: index, newRect: finalRect, oldRect: original, undoManager: undoManager)
                        resizingHandle = nil
                        originalRect = nil
                    } else if let start = liveDrawingStart {
                        let imageStart = toImageCoords(start)
                        let imageEnd = imageLocation
                        let rect = CGRect(from: imageStart, to: imageEnd)

                        if rect.width > 2 || rect.height > 2 {
                            var newAnnotation = Annotation(rect: rect, color: selectedColor, lineWidth: selectedLineWidth, tool: selectedTool)
                            newAnnotation.startPoint = imageStart
                            newAnnotation.endPoint = imageEnd
                            newAnnotation.opacity = annotationOpacity
                            newAnnotation.dashedStroke = dashedStroke

                            if selectedTool == .rectangle {
                                newAnnotation.cornerRadius = shapeCornerRadius
                                newAnnotation.fillMode = shapeFillMode
                            } else if selectedTool == .ellipse {
                                newAnnotation.fillMode = shapeFillMode
                            } else if selectedTool == .spotlight {
                                newAnnotation.spotlightShape = spotlightShape
                            } else if selectedTool == .blur {
                                newAnnotation.blurRadius = blurRadius
                                newAnnotation.blurMode = blurMode
                            } else if selectedTool == .callout {
                                newAnnotation.cornerRadius = shapeCornerRadius
                                newAnnotation.fillMode = shapeFillMode
                                newAnnotation.calloutTailDirection = calloutTailDirection
                            } else if selectedTool == .magnifier {
                                // Make it square (circular)
                                let side = max(rect.width, rect.height)
                                newAnnotation.rect = CGRect(x: rect.origin.x, y: rect.origin.y, width: side, height: side)
                            } else if selectedTool == .crop {
                                var cropArea = rect
                                if let ratio = cropAspectRatio.ratio {
                                    let w = cropArea.width
                                    let h = w / ratio
                                    cropArea = CGRect(x: cropArea.origin.x, y: cropArea.origin.y, width: w, height: h)
                                }
                                cropRect = cropArea
                                liveDrawingStart = nil
                                liveDrawingEnd = nil
                                return
                            }

                            viewModel.addAnnotation(newAnnotation, undoManager: undoManager)

                            selectedAnnotationID = newAnnotation.id
                            showToolControls = true

                            selectedTool = .select
                        } else if let (existingID, _) = findAnnotation(at: imageLocation) {
                            // The gesture was a click, not a drag, so no
                            // shape was created — that branch was previously
                            // a dead end. If something is under the cursor,
                            // select it so its properties can be edited
                            // without first switching tools.
                            //
                            // Note this only applies to a *click*. A drag
                            // always creates, whatever it starts on top of:
                            // drawing a box around an area that already has
                            // annotations in it has to keep working.
                            selectedAnnotationID = existingID
                            showToolControls = true
                        }
                    }
                }
                liveDrawingStart = nil
                liveDrawingEnd = nil
                resizingHandle = nil
                originalRect = nil
            }
    }

    // MARK: - Hit Testing

    private func findAnnotation(at point: CGPoint) -> (id: UUID, index: Int)? {
        for (index, annotation) in viewModel.annotations.enumerated().reversed() {
            if annotation.tool == .arrow || annotation.tool == .line || annotation.tool == .ruler {
                if let start = annotation.startPoint, let end = annotation.endPoint {
                    let threshold: CGFloat = 10
                    if let cp = annotation.controlPoint {
                        let distance = distanceFromPointToQuadBezier(point: point, start: start, control: cp, end: end)
                        if distance < threshold {
                            return (annotation.id, index)
                        }
                    } else {
                        let distance = distanceFromPointToLine(point: point, lineStart: start, lineEnd: end)
                        if distance < threshold {
                            return (annotation.id, index)
                        }
                    }
                }
            }

            if annotation.tool == .text && !annotation.text.isEmpty {
                if annotation.rect.contains(point) {
                    return (annotation.id, index)
                }

                let font = NSFont.systemFont(ofSize: annotation.lineWidth * 4)
                let textAttributes: [NSAttributedString.Key: Any] = [.font: font]
                let textSize = (annotation.text as NSString).boundingRect(
                    with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: textAttributes
                ).size

                let paddedWidth = textSize.width + 16
                let paddedHeight = textSize.height + 8

                let textRect = CGRect(
                    x: annotation.rect.origin.x,
                    y: annotation.rect.origin.y,
                    width: paddedWidth,
                    height: paddedHeight
                )

                if textRect.contains(point) {
                    return (annotation.id, index)
                }
                continue
            }

            if annotation.rect.contains(point) {
                return (annotation.id, index)
            }
        }
        return nil
    }

    private func distanceFromPointToLine(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        let lengthSq = dx * dx + dy * dy

        if lengthSq == 0 {
            return hypot(point.x - lineStart.x, point.y - lineStart.y)
        }

        // Project point onto line segment, clamping t to [0,1]
        let t = max(0, min(1, ((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) / lengthSq))
        let projX = lineStart.x + t * dx
        let projY = lineStart.y + t * dy
        return hypot(point.x - projX, point.y - projY)
    }

    private func distanceFromPointToQuadBezier(point: CGPoint, start: CGPoint, control: CGPoint, end: CGPoint, samples: Int = 20) -> CGFloat {
        var minDist: CGFloat = .greatestFiniteMagnitude
        for i in 0...samples {
            let t = CGFloat(i) / CGFloat(samples)
            let oneMinusT = 1 - t
            let bx = oneMinusT * oneMinusT * start.x + 2 * oneMinusT * t * control.x + t * t * end.x
            let by = oneMinusT * oneMinusT * start.y + 2 * oneMinusT * t * control.y + t * t * end.y
            let dist = hypot(point.x - bx, point.y - by)
            if dist < minDist { minDist = dist }
        }
        return minDist
    }

    // MARK: - Handle Detection & Resizing

    private func getHandlePositions(for rect: CGRect, tool: DrawingTool) -> [ResizeHandle: CGPoint] {
        switch tool {
        case .line, .arrow, .ruler:
            // These tools use direct endpoint dragging, no resize handles needed
            return [:]
        case .text:
            return [:]
        case .emoji:
            return [
                .topLeft: CGPoint(x: rect.minX, y: rect.minY),
                .topRight: CGPoint(x: rect.maxX, y: rect.minY),
                .bottomLeft: CGPoint(x: rect.minX, y: rect.maxY),
                .bottomRight: CGPoint(x: rect.maxX, y: rect.maxY)
            ]
        case .pin:
            return [:]
        case .pen:
            return [
                .topLeft: CGPoint(x: rect.minX, y: rect.minY),
                .top: CGPoint(x: rect.midX, y: rect.minY),
                .topRight: CGPoint(x: rect.maxX, y: rect.minY),
                .left: CGPoint(x: rect.minX, y: rect.midY),
                .right: CGPoint(x: rect.maxX, y: rect.midY),
                .bottomLeft: CGPoint(x: rect.minX, y: rect.maxY),
                .bottom: CGPoint(x: rect.midX, y: rect.maxY),
                .bottomRight: CGPoint(x: rect.maxX, y: rect.maxY)
            ]
        case .magnifier:
            return [
                .topLeft: CGPoint(x: rect.minX, y: rect.minY),
                .topRight: CGPoint(x: rect.maxX, y: rect.minY),
                .bottomLeft: CGPoint(x: rect.minX, y: rect.maxY),
                .bottomRight: CGPoint(x: rect.maxX, y: rect.maxY)
            ]
        case .rectangle, .ellipse, .highlighter, .pixelate, .spotlight, .blur, .callout:
            return [
                .topLeft: CGPoint(x: rect.minX, y: rect.minY),
                .top: CGPoint(x: rect.midX, y: rect.minY),
                .topRight: CGPoint(x: rect.maxX, y: rect.minY),
                .left: CGPoint(x: rect.minX, y: rect.midY),
                .right: CGPoint(x: rect.maxX, y: rect.midY),
                .bottomLeft: CGPoint(x: rect.minX, y: rect.maxY),
                .bottom: CGPoint(x: rect.midX, y: rect.maxY),
                .bottomRight: CGPoint(x: rect.maxX, y: rect.maxY)
            ]
        case .select, .move, .eraser, .crop, .eyedropper:
            return [:]
        }
    }

    private func detectHandle(at point: CGPoint, for rect: CGRect, tool: DrawingTool) -> ResizeHandle? {
        let handleSize: CGFloat = 12
        let positions = getHandlePositions(for: rect, tool: tool)

        for (handle, position) in positions {
            let handleRect = CGRect(x: position.x - handleSize / 2,
                                   y: position.y - handleSize / 2,
                                   width: handleSize,
                                   height: handleSize)
            if handleRect.contains(point) {
                return handle
            }
        }
        return nil
    }

    private func calculateResizedRect(originalRect: CGRect, handle: ResizeHandle, dragTo point: CGPoint) -> CGRect {
        var newRect = originalRect

        switch handle {
        case .topLeft:
            newRect = CGRect(x: point.x, y: point.y,
                           width: originalRect.maxX - point.x,
                           height: originalRect.maxY - point.y)
        case .top:
            newRect = CGRect(x: originalRect.minX, y: point.y,
                           width: originalRect.width,
                           height: originalRect.maxY - point.y)
        case .topRight:
            newRect = CGRect(x: originalRect.minX, y: point.y,
                           width: point.x - originalRect.minX,
                           height: originalRect.maxY - point.y)
        case .left:
            newRect = CGRect(x: point.x, y: originalRect.minY,
                           width: originalRect.maxX - point.x,
                           height: originalRect.height)
        case .right:
            newRect = CGRect(x: originalRect.minX, y: originalRect.minY,
                           width: point.x - originalRect.minX,
                           height: originalRect.height)
        case .bottomLeft:
            newRect = CGRect(x: point.x, y: originalRect.minY,
                           width: originalRect.maxX - point.x,
                           height: point.y - originalRect.minY)
        case .bottom:
            newRect = CGRect(x: originalRect.minX, y: originalRect.minY,
                           width: originalRect.width,
                           height: point.y - originalRect.minY)
        case .bottomRight:
            newRect = CGRect(x: originalRect.minX, y: originalRect.minY,
                           width: point.x - originalRect.minX,
                           height: point.y - originalRect.minY)
        }

        let minSize: CGFloat = 20
        if abs(newRect.width) < minSize || abs(newRect.height) < minSize {
            return originalRect
        }

        return newRect.standardized
    }

    // MARK: - Annotation Rendering

    private func drawSingleAnnotation(_ annotation: Annotation, rect: CGRect, in context: inout GraphicsContext, canvasSize: CGSize, nsImage: NSImage? = nil) {
        let opacity = annotation.opacity
        let dashed = annotation.dashedStroke

        func strokeStyle(lineWidth: CGFloat) -> StrokeStyle {
            // Prefer the richer per-annotation lineStyle (solid/dashed/dotted/dashDot/dashDotDot).
            // Scale dash pattern by lineWidth so thick strokes keep recognizable dash proportions,
            // and use .butt caps so short "dots" in dash-dot patterns aren't swallowed by round caps.
            if let basePattern = annotation.lineStyle.dashPattern {
                let scale = max(1.0, lineWidth / 2.0)
                let scaled = basePattern.map { $0 * scale }
                return StrokeStyle(lineWidth: lineWidth, lineCap: .butt, lineJoin: .round, dash: scaled)
            }
            if dashed {
                let scale = max(1.0, lineWidth / 2.0)
                return StrokeStyle(lineWidth: lineWidth, lineCap: .butt, dash: [8 * scale, 4 * scale])
            }
            return StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        }

        context.opacity = opacity

        let sketch = annotation.sketchStyle
        let seed = annotation.id.hashValue

        switch annotation.tool {
        case .rectangle:
            if sketch {
                let sketchPath = SketchRenderer.sketchRect(rect, seed: seed)
                switch annotation.fillMode {
                case .fill:
                    context.fill(Path(rect), with: .color(annotation.color))
                case .stroke:
                    context.stroke(sketchPath, with: .color(annotation.color), lineWidth: annotation.lineWidth)
                case .both:
                    context.fill(Path(rect), with: .color(annotation.color.opacity(0.3)))
                    context.stroke(sketchPath, with: .color(annotation.color), lineWidth: annotation.lineWidth)
                }
            } else {
                let cornerRadius = annotation.cornerRadius
                let rectPath = Path(roundedRect: rect, cornerRadius: cornerRadius)

                switch annotation.fillMode {
                case .fill:
                    context.fill(rectPath, with: .color(annotation.color))
                case .stroke:
                    context.stroke(rectPath, with: .color(annotation.color), style: strokeStyle(lineWidth: annotation.lineWidth))
                case .both:
                    context.fill(rectPath, with: .color(annotation.color.opacity(0.3)))
                    context.stroke(rectPath, with: .color(annotation.color), style: strokeStyle(lineWidth: annotation.lineWidth))
                }
            }

        case .ellipse:
            if sketch {
                let sketchPath = SketchRenderer.sketchEllipse(rect, seed: seed)
                switch annotation.fillMode {
                case .fill:
                    context.fill(Path(ellipseIn: rect), with: .color(annotation.color))
                case .stroke:
                    context.stroke(sketchPath, with: .color(annotation.color), lineWidth: annotation.lineWidth)
                case .both:
                    context.fill(Path(ellipseIn: rect), with: .color(annotation.color.opacity(0.3)))
                    context.stroke(sketchPath, with: .color(annotation.color), lineWidth: annotation.lineWidth)
                }
            } else {
                let ellipsePath = Path(ellipseIn: rect)

                switch annotation.fillMode {
                case .fill:
                    context.fill(ellipsePath, with: .color(annotation.color))
                case .stroke:
                    context.stroke(ellipsePath, with: .color(annotation.color), style: strokeStyle(lineWidth: annotation.lineWidth))
                case .both:
                    context.fill(ellipsePath, with: .color(annotation.color.opacity(0.3)))
                    context.stroke(ellipsePath, with: .color(annotation.color), style: strokeStyle(lineWidth: annotation.lineWidth))
                }
            }

        case .line:
            if let start = annotation.startPoint, let end = annotation.endPoint {
                if sketch {
                    let sketchPath = SketchRenderer.sketchLine(from: start, to: end, seed: seed)
                    context.stroke(sketchPath, with: .color(annotation.color), lineWidth: annotation.lineWidth)
                } else {
                    var path = Path()
                    path.move(to: start)
                    path.addLine(to: end)
                    context.stroke(path, with: .color(annotation.color), style: strokeStyle(lineWidth: annotation.lineWidth))
                }
            }
        case .highlighter:
            // A real highlighter darkens what's beneath it; it doesn't wash
            // it out. Plain alpha compositing lightened the text underneath,
            // leaving it grey and less readable than before it was
            // highlighted. Multiply keeps dark text fully dark and tints
            // only the lighter background.
            //
            // The 0.55 alpha is what keeps the darker inks usable: at full
            // strength, multiplying with blue or purple swamps the content.
            let previousBlendMode = context.blendMode
            context.blendMode = .multiply
            context.fill(Path(rect), with: .color(annotation.color.opacity(0.55)))
            context.blendMode = previousBlendMode
        case .arrow:
            let start = annotation.startPoint ?? rect.origin
            let end = annotation.endPoint ?? rect.endPoint
            let shaftLength = hypot(end.x - start.x, end.y - start.y)
            if shaftLength > annotation.lineWidth * 2 {
                // Head scales with the stroke so a thick arrow still reads
                // as an arrow. The old `min(30, …)` cap meant a 20pt stroke
                // got a 30pt head (1.5x) and a 30pt stroke got a 30pt head
                // — i.e. no visible head at all. The only ceiling now is
                // the arrow's own length, so short arrows don't become all
                // head.
                //
                // The 16pt floor is what makes thin strokes work: below
                // roughly that size a triangle stops reading as an
                // arrowhead no matter how correct its proportions are, so
                // a 1–2pt line still gets a head you can actually see.
                let headL = min(max(16, annotation.lineWidth * 4.0), shaftLength * 0.45)
                // Wider than long. A head narrower than its length looks
                // like a needle at small sizes; the extra width is what
                // makes the shape legible when it's only a few points tall.
                let headW = headL * 1.10

                // Sketch mode: hand-drawn wobbly shaft + filled arrowhead.
                if sketch {
                    if let cp = annotation.controlPoint {
                        // Sample the quad curve into short segments, wobble each.
                        let samples = 16
                        var prev = start
                        for i in 1...samples {
                            let t = CGFloat(i) / CGFloat(samples)
                            let oneMinusT = 1 - t
                            let x = oneMinusT * oneMinusT * start.x + 2 * oneMinusT * t * cp.x + t * t * end.x
                            let y = oneMinusT * oneMinusT * start.y + 2 * oneMinusT * t * cp.y + t * t * end.y
                            let next = CGPoint(x: x, y: y)
                            let segPath = SketchRenderer.sketchLine(from: prev, to: next, seed: seed &+ i)
                            context.stroke(segPath, with: .color(annotation.color), lineWidth: annotation.lineWidth)
                            prev = next
                        }
                    } else {
                        let sketchPath = SketchRenderer.sketchLine(from: start, to: end, seed: seed)
                        context.stroke(sketchPath, with: .color(annotation.color), lineWidth: annotation.lineWidth)
                    }
                } else {
                    // Clean mode: shaft respects lineStyle (solid/dashed/dotted/dashDot/dashDotDot)
                    //
                    // The shaft stops at the head's base rather than running
                    // to the tip. Drawing it all the way meant a thick
                    // stroke's round cap pushed past the point of the
                    // triangle, blunting it into a blob — worse the heavier
                    // the line. Open heads are the exception: there the
                    // shaft is *supposed* to reach the tip.
                    let shaftEnd = shaftEndPoint(
                        end: end,
                        towards: annotation.controlPoint ?? start,
                        style: annotation.arrowheadStyle,
                        headLength: headL,
                        headWidth: headW
                    )
                    var shaft = Path()
                    if let cp = annotation.controlPoint {
                        shaft.move(to: start)
                        shaft.addQuadCurve(to: shaftEnd, control: cp)
                    } else {
                        shaft.move(to: start)
                        shaft.addLine(to: shaftEnd)
                    }
                    let shaftStroke = strokeStyle(lineWidth: annotation.lineWidth)
                    context.stroke(shaft, with: .color(annotation.color), style: shaftStroke)
                }

                // Arrowhead — same for both modes (sketch wouldn't make it look better anyway)
                drawArrowhead(
                    in: &context,
                    at: end,
                    from: annotation.controlPoint ?? start,
                    style: annotation.arrowheadStyle,
                    color: annotation.color,
                    width: headW,
                    length: headL,
                    lineWidth: annotation.lineWidth
                )
            }
        case .pixelate:
            context.opacity = 1.0
            if let nsImage = nsImage,
               let pixelatedImg = applyPixelateFilter(to: nsImage, in: rect) {
                context.draw(Image(nsImage: pixelatedImg), in: rect)
            } else {
                context.fill(Path(rect), with: .color(.gray.opacity(0.7)))
            }

        case .pin:
            let diameter = rect.width
            let shapeRect = CGRect(x: rect.minX, y: rect.minY, width: diameter, height: diameter)

            let shape = annotation.numberShape ?? .circle
            let shapePath: Path
            switch shape {
            case .circle:
                shapePath = Path(ellipseIn: shapeRect)
            case .square:
                shapePath = Path(shapeRect)
            case .roundedSquare:
                shapePath = Path(roundedRect: shapeRect, cornerRadius: diameter * 0.2)
            }
            // Drop shadow, so a badge whose colour happens to match what's
            // behind it still separates from the screenshot.
            context.drawLayer { layer in
                layer.addFilter(.shadow(color: .black.opacity(0.35),
                                        radius: diameter * 0.07,
                                        x: 0, y: diameter * 0.025))
                layer.fill(shapePath, with: .color(annotation.color))
            }

            // Light ring — the other half of standing out on any backdrop.
            let ringInset = diameter * 0.045
            let ringPath: Path
            switch shape {
            case .circle:
                ringPath = Path(ellipseIn: shapeRect.insetBy(dx: ringInset, dy: ringInset))
            case .square:
                ringPath = Path(shapeRect.insetBy(dx: ringInset, dy: ringInset))
            case .roundedSquare:
                ringPath = Path(roundedRect: shapeRect.insetBy(dx: ringInset, dy: ringInset),
                                cornerRadius: diameter * 0.18)
            }
            context.stroke(ringPath, with: .color(.white.opacity(0.9)),
                           lineWidth: diameter * 0.07)

            if let number = annotation.number {
                let fontSize = diameter * 0.55
                let numberText = "\(number)"

                // The number colour used to be hard-coded white, which made
                // a yellow or light-green badge hard to read and a white one
                // literally blank. Pick whichever of black/white actually
                // contrasts with the fill.
                let text = Text(numberText)
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundColor(annotation.color.readableForeground)

                let resolved = context.resolve(text)

                context.draw(resolved, at: CGPoint(x: shapeRect.midX, y: shapeRect.midY), anchor: .center)
            }

        case .text:
            let isEditing = editingTextIndex == viewModel.annotations.firstIndex(where: { $0.id == annotation.id })

            if !isEditing && !annotation.text.isEmpty {
                // Use the user-set annotation rect directly — honors manual resizing
                // from the Inspector BOX section instead of shrink-wrapping around text.
                let bgRect = rect

                if let bgColor = annotation.backgroundColor {
                    let bgPath = Path(roundedRect: bgRect, cornerRadius: 6)
                    context.fill(bgPath, with: .color(bgColor))
                }

                // Drawn as an attributed string rather than a SwiftUI `Text`.
                // `Text` has no way to express an outline, letter spacing or
                // line height, so those settings (and even alignment) were
                // stored and shown in the Inspector but never reached the
                // canvas. Core Text handles all of them in one pass.
                let inset = CustomTextEditor.contentInset
                let maxDrawWidth = rect.width - inset.width * 2
                let attributed = AnnotationTextStyle.attributedString(for: annotation)

                let measured = attributed.boundingRect(
                    with: NSSize(width: maxDrawWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading]
                )
                let availableHeight = bgRect.height - inset.height * 2
                let dy = AnnotationTextStyle.verticalOffset(
                    for: annotation,
                    textHeight: measured.height,
                    containerHeight: availableHeight
                )

                let textFrame = CGRect(
                    x: rect.minX + inset.width,
                    y: rect.minY + inset.height + dy,
                    width: maxDrawWidth,
                    height: max(measured.height, availableHeight - dy)
                )

                // Shadow is applied once for every tool at the call site in
                // `body`, so nothing tool-specific is needed here.
                context.withCGContext { cgContext in
                    let nsContext = NSGraphicsContext(cgContext: cgContext, flipped: true)
                    NSGraphicsContext.saveGraphicsState()
                    NSGraphicsContext.current = nsContext
                    attributed.draw(with: textFrame, options: [.usesLineFragmentOrigin, .usesFontLeading])
                    NSGraphicsContext.restoreGraphicsState()
                }
            }

            // Frame around the text field while editing.
            //
            // This used to be drawn only when the text was *empty*, so it
            // vanished on the first keystroke and never appeared at all
            // when re-editing something — leaving no indication of where
            // the field actually was.
            if isEditing {
                strokeContrastOutline(Path(roundedRect: rect, cornerRadius: 3),
                                      in: &context,
                                      accent: Ember.Palette.amber)

                // The wrap limit, when the box has tightened inside it.
                // Without this the limit is invisible until you type enough
                // to hit it — you can't see how much room is left.
                let limit = annotation.textWrapWidth
                if let limit, limit > rect.width + 4 {
                    var edge = Path()
                    edge.move(to: CGPoint(x: rect.minX + limit, y: rect.minY))
                    edge.addLine(to: CGPoint(x: rect.minX + limit, y: rect.maxY))
                    context.stroke(edge, with: .color(Ember.Palette.amber.opacity(0.5)),
                                   style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
                }
            }
        case .emoji:
            if let emoji = annotation.emoji {
                let fontSize = rect.width * 0.8
                let emojiText = Text(emoji)
                    .font(.system(size: fontSize))

                let resolved = context.resolve(emojiText)

                context.draw(resolved, at: CGPoint(x: rect.midX, y: rect.midY), anchor: .center)
            }

        case .pen:
            if let points = annotation.path, points.count > 1 {
                let simplified = simplifyPoints(points, tolerance: 1.0)
                let bezierPath = smoothPath(from: simplified)

                let brushStyle = annotation.brushStyle ?? .solid
                switch brushStyle {
                case .solid:
                    context.stroke(bezierPath, with: .color(annotation.color), style: StrokeStyle(lineWidth: annotation.lineWidth, lineCap: .round, lineJoin: .round))
                case .dashed:
                    context.stroke(bezierPath, with: .color(annotation.color), style: StrokeStyle(lineWidth: annotation.lineWidth, lineCap: .round, lineJoin: .round, dash: [10, 5]))
                case .marker:
                    context.stroke(bezierPath, with: .color(annotation.color.opacity(0.5)), style: StrokeStyle(lineWidth: annotation.lineWidth * 2, lineCap: .round, lineJoin: .round))
                }
            }

        case .spotlight:
            context.opacity = 1.0
            var fullScreenPath = Path(CGRect(origin: .zero, size: canvasSize))

            let spotPath: Path
            if annotation.spotlightShape == .rectangle {
                spotPath = Path(roundedRect: rect, cornerRadius: 8)
            } else {
                spotPath = Path(ellipseIn: rect)
            }
            fullScreenPath.addPath(spotPath)

            context.fill(fullScreenPath, with: .color(.black.opacity(0.6)), style: FillStyle(eoFill: true))

            context.stroke(spotPath, with: .color(.white.opacity(0.5)), lineWidth: 2)

        case .blur:
            context.opacity = 1.0
            switch annotation.blurMode {
            case .full:
                if let nsImage = nsImage,
                   let blurredImg = applyGaussianBlurFilter(to: nsImage, in: rect, radius: annotation.blurRadius) {
                    context.draw(Image(nsImage: blurredImg), in: rect)
                } else {
                    context.fill(Path(rect), with: .color(.gray.opacity(0.3)))
                }
            case .textOnly:
                if let nsImage = nsImage {
                    let textRects = TextRegionDetector.detectTextRegions(in: nsImage, within: rect)
                    for textRect in textRects {
                        if let blurredImg = applyGaussianBlurFilter(to: nsImage, in: textRect, radius: annotation.blurRadius) {
                            context.draw(Image(nsImage: blurredImg), in: textRect)
                        }
                    }
                }
            case .erase:
                context.fill(Path(rect), with: .color(.white))
            case .textErase:
                if let nsImage = nsImage {
                    let textRects = TextRegionDetector.detectTextRegions(in: nsImage, within: rect)
                    for textRect in textRects {
                        context.fill(Path(textRect), with: .color(.white))
                    }
                }
            }

        case .callout:
            let cornerRadius = annotation.cornerRadius
            let bodyRect = rect
            let bodyPath = Path(roundedRect: bodyRect, cornerRadius: cornerRadius)

            let tailWidth: CGFloat = min(20, bodyRect.width * 0.2)
            let tailHeight: CGFloat = min(16, bodyRect.height * 0.4)

            var tailPath = Path()
            switch annotation.calloutTailDirection {
            case .bottomLeft:
                let baseX = bodyRect.minX + bodyRect.width * 0.2
                tailPath.move(to: CGPoint(x: baseX, y: bodyRect.maxY))
                tailPath.addLine(to: CGPoint(x: baseX - tailWidth * 0.3, y: bodyRect.maxY + tailHeight))
                tailPath.addLine(to: CGPoint(x: baseX + tailWidth, y: bodyRect.maxY))
            case .bottomCenter:
                let baseX = bodyRect.midX
                tailPath.move(to: CGPoint(x: baseX - tailWidth / 2, y: bodyRect.maxY))
                tailPath.addLine(to: CGPoint(x: baseX, y: bodyRect.maxY + tailHeight))
                tailPath.addLine(to: CGPoint(x: baseX + tailWidth / 2, y: bodyRect.maxY))
            case .bottomRight:
                let baseX = bodyRect.maxX - bodyRect.width * 0.2
                tailPath.move(to: CGPoint(x: baseX - tailWidth, y: bodyRect.maxY))
                tailPath.addLine(to: CGPoint(x: baseX + tailWidth * 0.3, y: bodyRect.maxY + tailHeight))
                tailPath.addLine(to: CGPoint(x: baseX, y: bodyRect.maxY))
            case .topLeft:
                let baseX = bodyRect.minX + bodyRect.width * 0.2
                tailPath.move(to: CGPoint(x: baseX, y: bodyRect.minY))
                tailPath.addLine(to: CGPoint(x: baseX - tailWidth * 0.3, y: bodyRect.minY - tailHeight))
                tailPath.addLine(to: CGPoint(x: baseX + tailWidth, y: bodyRect.minY))
            case .topCenter:
                let baseX = bodyRect.midX
                tailPath.move(to: CGPoint(x: baseX - tailWidth / 2, y: bodyRect.minY))
                tailPath.addLine(to: CGPoint(x: baseX, y: bodyRect.minY - tailHeight))
                tailPath.addLine(to: CGPoint(x: baseX + tailWidth / 2, y: bodyRect.minY))
            case .topRight:
                let baseX = bodyRect.maxX - bodyRect.width * 0.2
                tailPath.move(to: CGPoint(x: baseX - tailWidth, y: bodyRect.minY))
                tailPath.addLine(to: CGPoint(x: baseX + tailWidth * 0.3, y: bodyRect.minY - tailHeight))
                tailPath.addLine(to: CGPoint(x: baseX, y: bodyRect.minY))
            }
            tailPath.closeSubpath()

            switch annotation.fillMode {
            case .fill:
                context.fill(bodyPath, with: .color(annotation.color))
                context.fill(tailPath, with: .color(annotation.color))
            case .stroke:
                context.stroke(bodyPath, with: .color(annotation.color), style: strokeStyle(lineWidth: annotation.lineWidth))
                context.stroke(tailPath, with: .color(annotation.color), style: strokeStyle(lineWidth: annotation.lineWidth))
            case .both:
                context.fill(bodyPath, with: .color(annotation.color.opacity(0.3)))
                context.fill(tailPath, with: .color(annotation.color.opacity(0.3)))
                context.stroke(bodyPath, with: .color(annotation.color), style: strokeStyle(lineWidth: annotation.lineWidth))
                context.stroke(tailPath, with: .color(annotation.color), style: strokeStyle(lineWidth: annotation.lineWidth))
            }

            if !annotation.text.isEmpty {
                let textInset = CGRect(x: bodyRect.minX + 8, y: bodyRect.minY + 4, width: bodyRect.width - 16, height: bodyRect.height - 8)
                let text = Text(annotation.text)
                    .font(.system(size: annotation.lineWidth * 3))
                    .foregroundColor(annotation.fillMode == .fill ? .white : annotation.color)
                context.draw(text, in: textInset)
            }

        case .magnifier:
            if let nsImage = nsImage {
                let mag = annotation.magnification
                // Source region in annotation's display space: centered, 1/mag size
                let sourceW = rect.width / mag
                let sourceH = rect.height / mag
                let sourceRect = CGRect(
                    x: rect.midX - sourceW / 2,
                    y: rect.midY - sourceH / 2,
                    width: sourceW,
                    height: sourceH
                )

                // Clip to ellipse
                context.drawLayer { layerCtx in
                    layerCtx.clip(to: Path(ellipseIn: rect))

                    // We need to draw the portion of the image that corresponds to sourceRect, scaled to rect
                    // Convert from canvas coords back to image coords for cropping
                    let imageSize = nsImage.size
                    let canvasScale = min(canvasSize.width / imageSize.width, canvasSize.height / imageSize.height)
                    let imgOffset = CGPoint(
                        x: (canvasSize.width - imageSize.width * canvasScale) / 2,
                        y: (canvasSize.height - imageSize.height * canvasScale) / 2
                    )

                    let imgSourceRect = CGRect(
                        x: (sourceRect.origin.x - imgOffset.x) / canvasScale,
                        y: (sourceRect.origin.y - imgOffset.y) / canvasScale,
                        width: sourceRect.width / canvasScale,
                        height: sourceRect.height / canvasScale
                    )

                    // Crop the source region from the image
                    if let bitmap = nsImage.storageBitmapRep,
                       let cgFull = bitmap.cgImage {
                        // Convert from image point coords to pixel coords (Retina 2x etc.)
                        let pxScaleX = imageSize.width > 0 ? CGFloat(cgFull.width) / imageSize.width : 1
                        let pxScaleY = imageSize.height > 0 ? CGFloat(cgFull.height) / imageSize.height : 1
                        let clampedX = max(0, min(Int(imgSourceRect.origin.x * pxScaleX), cgFull.width - 1))
                        let clampedY = max(0, min(Int(imgSourceRect.origin.y * pxScaleY), cgFull.height - 1))
                        let clampedW = max(1, min(Int(imgSourceRect.width * pxScaleX), cgFull.width - clampedX))
                        let clampedH = max(1, min(Int(imgSourceRect.height * pxScaleY), cgFull.height - clampedY))
                        let cropCGRect = CGRect(x: clampedX, y: clampedY, width: clampedW, height: clampedH)

                        if let croppedCG = cgFull.cropping(to: cropCGRect) {
                            let croppedNS = NSImage(cgImage: croppedCG, size: NSSize(width: clampedW, height: clampedH))
                            layerCtx.draw(Image(nsImage: croppedNS), in: rect)
                        }
                    }
                }

                // Border
                context.stroke(Path(ellipseIn: rect), with: .color(.white), lineWidth: 3)
                context.stroke(Path(ellipseIn: rect.insetBy(dx: 1.5, dy: 1.5)), with: .color(.black.opacity(0.3)), lineWidth: 1)

                // Magnification label
                let label = Text("\(String(format: "%.1f", mag))x")
                    .font(.system(size: max(9, rect.width * 0.08), weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                let resolved = context.resolve(label)
                let labelBG = CGRect(x: rect.midX - 16, y: rect.maxY - 18, width: 32, height: 14)
                context.fill(Path(roundedRect: labelBG, cornerRadius: 4), with: .color(.black.opacity(0.6)))
                context.draw(resolved, at: CGPoint(x: rect.midX, y: rect.maxY - 11), anchor: .center)
            }

        case .ruler:
            let start = annotation.startPoint ?? CGPoint(x: rect.minX, y: rect.minY)
            let end = annotation.endPoint ?? CGPoint(x: rect.maxX, y: rect.maxY)

            let dx = end.x - start.x
            let dy = end.y - start.y
            let distance = sqrt(dx * dx + dy * dy)
            let angle = atan2(dy, dx)

            // Main line
            var linePath = Path()
            linePath.move(to: start)
            linePath.addLine(to: end)
            context.stroke(linePath, with: .color(annotation.color), style: StrokeStyle(lineWidth: annotation.lineWidth))

            // Tick marks at endpoints (perpendicular, 10px each side)
            let tickLen: CGFloat = 10
            let perpX = -sin(angle) * tickLen
            let perpY = cos(angle) * tickLen

            var tickPath = Path()
            tickPath.move(to: CGPoint(x: start.x + perpX, y: start.y + perpY))
            tickPath.addLine(to: CGPoint(x: start.x - perpX, y: start.y - perpY))
            tickPath.move(to: CGPoint(x: end.x + perpX, y: end.y + perpY))
            tickPath.addLine(to: CGPoint(x: end.x - perpX, y: end.y - perpY))
            context.stroke(tickPath, with: .color(annotation.color), style: StrokeStyle(lineWidth: annotation.lineWidth))

            // Distance label at midpoint
            // Convert display coords back to image coords for accurate pixel measurement
            let imageSize = nsImage?.size ?? CGSize(width: 1, height: 1)
            let canvasScale = min(canvasSize.width / imageSize.width, canvasSize.height / imageSize.height)
            let imgDist: CGFloat
            if canvasScale > 0 {
                imgDist = distance / canvasScale
            } else {
                imgDist = distance
            }

            let label = Text("\(Int(imgDist))px")
                .font(.system(size: max(10, annotation.lineWidth * 3), weight: .bold, design: .rounded))
                .foregroundColor(annotation.color)
            let resolvedLabel = context.resolve(label)
            let midPoint = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
            let labelOffset: CGFloat = 14
            let labelPos = CGPoint(x: midPoint.x - sin(angle) * labelOffset, y: midPoint.y + cos(angle) * labelOffset)

            // Background pill behind label
            let labelSize = resolvedLabel.measure(in: CGSize(width: 200, height: 50))
            let pillRect = CGRect(x: labelPos.x - labelSize.width / 2 - 4, y: labelPos.y - labelSize.height / 2 - 2, width: labelSize.width + 8, height: labelSize.height + 4)
            context.fill(Path(roundedRect: pillRect, cornerRadius: 4), with: .color(.black.opacity(0.6)))
            context.draw(resolvedLabel, at: labelPos, anchor: .center)

        case .crop, .move, .eraser, .select, .eyedropper:
            break
        }

        context.opacity = 1.0
    }
}

// MARK: - Arrowhead rendering

/// Draws an outline that stays visible over any screenshot.
///
/// A single 1pt line disappears the moment the image behind it happens to
/// be the same tone — which on a screenshot is most of the time. Laying a
/// light dashed stroke over a solid dark one means one of the two always
/// contrasts, whatever is underneath. It's the same trick as the classic
/// "marching ants", and what Figma, Sketch and Photoshop all use.
private func strokeContrastOutline(_ path: Path,
                                   in context: inout GraphicsContext,
                                   accent: Color? = nil,
                                   lineWidth: CGFloat = 1.5) {
    context.stroke(path, with: .color(.black.opacity(0.55)),
                   style: StrokeStyle(lineWidth: lineWidth + 1))
    context.stroke(path, with: .color(accent ?? .white),
                   style: StrokeStyle(lineWidth: lineWidth, dash: [5, 3]))
}

extension Color {
    /// Black or white — whichever stays legible on top of this colour.
    ///
    /// Uses relative luminance (the Rec. 709 weighting, which is what
    /// WCAG contrast is built on) rather than plain brightness, because
    /// the eye is far more sensitive to green than to blue: pure blue and
    /// pure yellow have similar RGB averages but wildly different
    /// perceived lightness.
    var readableForeground: Color {
        guard let srgb = NSColor(self).usingColorSpace(.sRGB) else { return .white }
        let luminance = 0.2126 * srgb.redComponent
                      + 0.7152 * srgb.greenComponent
                      + 0.0722 * srgb.blueComponent
        return luminance > 0.6 ? .black : .white
    }
}

/// Where the shaft should stop so it meets the arrowhead cleanly instead
/// of poking through its tip.
///
/// Filled heads (triangle, diamond, circle) cover the shaft, so it's cut
/// back to roughly where the head's body begins — a small overlap is kept
/// so no gap shows through a dashed stroke. An open head is just two
/// strokes meeting at the point, so the shaft runs the whole way.
private func shaftEndPoint(
    end: CGPoint,
    towards origin: CGPoint,
    style: ArrowheadStyle,
    headLength: CGFloat,
    headWidth: CGFloat
) -> CGPoint {
    let trim: CGFloat
    switch style {
    case .closedTriangle: trim = headLength * 0.85
    case .diamond:        trim = headLength * 0.85
    case .circle:         trim = max(headWidth, headLength) * 0.85
    case .openTriangle, .none: return end
    }

    let dx = end.x - origin.x
    let dy = end.y - origin.y
    let len = hypot(dx, dy)
    guard len > 0.001 else { return end }
    return CGPoint(x: end.x - dx / len * trim,
                   y: end.y - dy / len * trim)
}

private func drawArrowhead(
    in context: inout GraphicsContext,
    at end: CGPoint,
    from origin: CGPoint,
    style: ArrowheadStyle,
    color: Color,
    width: CGFloat,
    length: CGFloat,
    lineWidth: CGFloat
) {
    guard style != .none else { return }

    let angle = atan2(end.y - origin.y, end.x - origin.x)

    switch style {
    case .closedTriangle:
        var path = Path()
        path.move(to: end)
        path.addLine(to: CGPoint(
            x: end.x - length * cos(angle) + width / 2 * sin(angle),
            y: end.y - length * sin(angle) - width / 2 * cos(angle)
        ))
        path.addLine(to: CGPoint(
            x: end.x - length * cos(angle) - width / 2 * sin(angle),
            y: end.y - length * sin(angle) + width / 2 * cos(angle)
        ))
        path.closeSubpath()
        context.fill(path, with: .color(color))

    case .openTriangle:
        var path = Path()
        path.move(to: CGPoint(
            x: end.x - length * cos(angle) + width / 2 * sin(angle),
            y: end.y - length * sin(angle) - width / 2 * cos(angle)
        ))
        path.addLine(to: end)
        path.addLine(to: CGPoint(
            x: end.x - length * cos(angle) - width / 2 * sin(angle),
            y: end.y - length * sin(angle) + width / 2 * cos(angle)
        ))
        context.stroke(path, with: .color(color),
                       style: StrokeStyle(lineWidth: max(1.5, lineWidth),
                                          lineCap: .round, lineJoin: .round))

    case .diamond:
        let backCenter = CGPoint(
            x: end.x - length * cos(angle),
            y: end.y - length * sin(angle)
        )
        let midCenter = CGPoint(
            x: end.x - (length / 2) * cos(angle),
            y: end.y - (length / 2) * sin(angle)
        )
        var path = Path()
        path.move(to: end)
        path.addLine(to: CGPoint(
            x: midCenter.x + (width / 2) * sin(angle),
            y: midCenter.y - (width / 2) * cos(angle)
        ))
        path.addLine(to: backCenter)
        path.addLine(to: CGPoint(
            x: midCenter.x - (width / 2) * sin(angle),
            y: midCenter.y + (width / 2) * cos(angle)
        ))
        path.closeSubpath()
        context.fill(path, with: .color(color))

    case .circle:
        let diameter = max(width, length)
        let center = CGPoint(
            x: end.x - (diameter / 2) * cos(angle),
            y: end.y - (diameter / 2) * sin(angle)
        )
        let circle = Path(ellipseIn: CGRect(
            x: center.x - diameter / 2,
            y: center.y - diameter / 2,
            width: diameter,
            height: diameter
        ))
        context.fill(circle, with: .color(color))

    case .none:
        break
    }
}
