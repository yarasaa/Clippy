//
//  WindowHierarchy.swift
//  Clippy
//
//  Safe parent/child window attachment.
//
//  AppKit propagates a window's level down its child chain recursively
//  (`-[NSWindow _applyWindowLevelWithTagUpdateNeeded:]`) and performs no
//  cycle detection of its own. If a window ever ends up as its own
//  ancestor, nothing throws — AppKit simply recurses until the thread's
//  stack is exhausted and the process dies with
//
//      EXC_BAD_ACCESS (code=2) · KERN_PROTECTION_FAILURE
//      "Thread stack size exceeded due to excessive recursion"
//
//  The fatal recursion contains no application frames at all, and it
//  surfaces at whatever unrelated `orderFront` runs next — the dock
//  preview panel, say — which makes the crash look random and unrelated
//  to the code that actually formed the cycle.
//
//  Every `addChildWindow` in the app goes through the helper below so a
//  cycle can't be formed in the first place.
//

import AppKit

extension NSWindow {

    /// True when `window` is this window, or is reachable by walking up
    /// this window's `parent` chain.
    func isAncestorOrSelf(_ window: NSWindow) -> Bool {
        var node: NSWindow? = self
        while let current = node {
            if current === window { return true }
            node = current.parent
        }
        return false
    }

    /// `addChildWindow(_:ordered:)` that refuses to close a loop.
    ///
    /// Attaching is skipped when `child` is this window or already one of
    /// its ancestors. A window can only have one parent, so any existing
    /// edge is detached first rather than left dangling.
    func addChildWindowSafely(_ child: NSWindow, ordered order: NSWindow.OrderingMode) {
        guard !isAncestorOrSelf(child) else { return }
        child.parent?.removeChildWindow(child)
        addChildWindow(child, ordered: order)
    }

    /// Detach from whatever window currently owns this one.
    ///
    /// Looking the parent up via `self.parent` matters: the previous code
    /// re-derived it from the popover's content view, which returns nil
    /// once the popover has closed — so the edge was silently left in
    /// place exactly when cleanup was needed most.
    func detachFromParentWindow() {
        parent?.removeChildWindow(self)
    }
}
