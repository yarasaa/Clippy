//
//  EditorSidebar.swift
//  Clippy
//

import SwiftUI

struct EditorSidebar: View {
    @Binding var selectedTool: DrawingTool
    @Binding var isEditingText: Bool
    @Binding var showToolControls: Bool
    @Binding var selectedAnnotationID: UUID?
    @Binding var showShapePicker: Bool
    @Binding var showEmojiPicker: Bool
    @Binding var selectedEmoji: String
    var onStopEditingText: () -> Void
    var onRotateLeft: (() -> Void)?
    var onRotateRight: (() -> Void)?
    var onFlipHorizontal: (() -> Void)?
    var onFlipVertical: (() -> Void)?
    var onExpandCanvas: (() -> Void)?

    struct ToolGroup {
        let tools: [DrawingTool]
    }

    let toolGroups: [ToolGroup] = [
        ToolGroup(tools: [.select, .move]),
        ToolGroup(tools: [.crop]),
        ToolGroup(tools: [.rectangle, .ellipse, .line, .arrow, .callout]),
        ToolGroup(tools: [.pen, .highlighter, .eraser]),
        ToolGroup(tools: [.text]),
        ToolGroup(tools: [.pin, .emoji, .spotlight]),
        ToolGroup(tools: [.blur, .pixelate, .eyedropper, .magnifier]),
        ToolGroup(tools: [.ruler]),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 2) {
                    ForEach(Array(toolGroups.enumerated()), id: \.offset) { groupIndex, group in
                        if groupIndex > 0 {
                            Divider()
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                        }

                        ForEach(group.tools) { tool in
                            sidebarButton(for: tool)
                        }
                    }

                    // MARK: Image Actions
                    Divider()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)

                    imageActionButton(icon: "rotate.left", tooltip: "Rotate Left") {
                        onRotateLeft?()
                    }
                    imageActionButton(icon: "rotate.right", tooltip: "Rotate Right") {
                        onRotateRight?()
                    }
                    imageActionButton(icon: "arrow.left.and.right.righttriangle.left.righttriangle.right", tooltip: "Flip Horizontal") {
                        onFlipHorizontal?()
                    }
                    imageActionButton(icon: "arrow.up.and.down.righttriangle.up.righttriangle.down", tooltip: "Flip Vertical") {
                        onFlipVertical?()
                    }
                    imageActionButton(icon: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left", tooltip: "Expand Canvas") {
                        onExpandCanvas?()
                    }
                }
                .padding(.vertical, 8)
            }

            Spacer()
        }
        .frame(width: 44)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private func imageActionButton(icon: String, tooltip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }

    @ViewBuilder
    private func sidebarButton(for tool: DrawingTool) -> some View {
        Button(action: {
            selectTool(tool)
        }) {
            Image(systemName: tool.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(selectedTool == tool ? .white : .secondary)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(selectedTool == tool ? Color.accentColor : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(tool.localizedName)
        .popover(isPresented: popoverBinding(for: tool), arrowEdge: .trailing) {
            popoverContent(for: tool)
        }
    }

    private func popoverBinding(for tool: DrawingTool) -> Binding<Bool> {
        switch tool {
        case .emoji:
            return $showEmojiPicker
        default:
            return .constant(false)
        }
    }

    @ViewBuilder
    private func popoverContent(for tool: DrawingTool) -> some View {
        switch tool {
        case .emoji:
            EmojiPickerView(selectedEmoji: $selectedEmoji, isPresented: $showEmojiPicker)
        default:
            EmptyView()
        }
    }

    private func selectTool(_ tool: DrawingTool) {
        if isEditingText {
            onStopEditingText()
        }

        selectedTool = tool

        let toolsWithControlPanel: [DrawingTool] = [.text, .pin, .spotlight, .pen, .emoji, .rectangle, .ellipse, .line, .arrow, .highlighter, .pixelate, .crop, .blur, .callout, .magnifier, .ruler]
        if toolsWithControlPanel.contains(tool) {
            showToolControls = true
            selectedAnnotationID = nil
        } else {
            showToolControls = false
            selectedAnnotationID = nil
        }

        if tool == .emoji {
            showEmojiPicker = true
        }
    }
}
