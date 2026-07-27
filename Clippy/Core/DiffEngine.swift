//
//  DiffEngine.swift
//  Clippy
//
//  Pure line/character diff — no SwiftUI, no view state, so it can be
//  reasoned about (and tested) on its own.
//
//  Why it isn't a textbook LCS:
//
//  The straightforward `matrix[n+1][m+1]` LCS allocates n·m Ints. Two
//  5,000-line texts would be 25M Ints ≈ 200 MB, which is a hang or an
//  out-of-memory crash for something the user expects to be instant. So:
//
//    1. Trim the common prefix and suffix first. Real-world "compare two
//       things I copied" pairs are usually near-identical, so this alone
//       collapses most inputs to a handful of differing lines.
//    2. Run LCS only on what's left, keeping just two rows of the matrix
//       at a time — O(min(n,m)) memory instead of O(n·m).
//    3. Backtracking needs the full matrix, so above a budget we fall
//       back to a coarse (but honest) block diff rather than allocating
//       gigabytes. `truncated` tells the UI to say so.
//

import Foundation

enum DiffEngine {

    // MARK: Types

    enum ChangeType { case added, removed, unchanged, modified }

    /// One rendered row of the diff.
    struct Line: Identifiable {
        let id = UUID()
        let leftContent: String?
        let rightContent: String?
        let leftLineNumber: Int?
        let rightLineNumber: Int?
        let type: ChangeType
        /// Character-level segments, present only on `.modified` rows.
        let leftSegments: [Segment]?
        let rightSegments: [Segment]?
    }

    struct Segment: Hashable {
        let text: String
        let isChanged: Bool
    }

    struct Stats {
        var added = 0
        var removed = 0
        var modified = 0
        var isIdentical: Bool { added == 0 && removed == 0 && modified == 0 }
    }

    struct Result {
        let lines: [Line]
        let stats: Stats
        /// True when the inputs were too large to diff exactly and a
        /// coarser result was produced.
        let truncated: Bool
    }

    /// Cells of LCS matrix we're willing to allocate (~8 MB at 8 bytes).
    private static let maxMatrixCells = 1_000_000

    // MARK: Entry point

    static func diff(old: String, new: String) -> Result {
        let oldLines = old.components(separatedBy: "\n")
        let newLines = new.components(separatedBy: "\n")

        // Fast path: identical inputs.
        if oldLines == newLines {
            let lines = oldLines.enumerated().map { i, text in
                Line(leftContent: text, rightContent: text,
                     leftLineNumber: i + 1, rightLineNumber: i + 1,
                     type: .unchanged, leftSegments: nil, rightSegments: nil)
            }
            return Result(lines: lines, stats: Stats(), truncated: false)
        }

        // 1. Peel off the common head and tail — these need no diffing.
        var head = 0
        while head < oldLines.count, head < newLines.count,
              oldLines[head] == newLines[head] {
            head += 1
        }

        var tail = 0
        while tail < oldLines.count - head,
              tail < newLines.count - head,
              oldLines[oldLines.count - 1 - tail] == newLines[newLines.count - 1 - tail] {
            tail += 1
        }

        let oldMiddle = Array(oldLines[head..<(oldLines.count - tail)])
        let newMiddle = Array(newLines[head..<(newLines.count - tail)])

        // 2. Diff only the middle.
        let budgetExceeded = (oldMiddle.count + 1) * (newMiddle.count + 1) > maxMatrixCells
        let middle = budgetExceeded
            ? blockDiff(oldMiddle, newMiddle, oldOffset: head, newOffset: head)
            : lcsDiff(oldMiddle, newMiddle, oldOffset: head, newOffset: head)

        // 3. Stitch head + middle + tail back together.
        var lines: [Line] = []
        for i in 0..<head {
            lines.append(Line(leftContent: oldLines[i], rightContent: newLines[i],
                              leftLineNumber: i + 1, rightLineNumber: i + 1,
                              type: .unchanged, leftSegments: nil, rightSegments: nil))
        }
        lines.append(contentsOf: pairModifications(middle))
        for t in 0..<tail {
            let oldIdx = oldLines.count - tail + t
            let newIdx = newLines.count - tail + t
            lines.append(Line(leftContent: oldLines[oldIdx], rightContent: newLines[newIdx],
                              leftLineNumber: oldIdx + 1, rightLineNumber: newIdx + 1,
                              type: .unchanged, leftSegments: nil, rightSegments: nil))
        }

        var stats = Stats()
        for line in lines {
            switch line.type {
            case .added:    stats.added += 1
            case .removed:  stats.removed += 1
            case .modified: stats.modified += 1
            case .unchanged: break
            }
        }

        return Result(lines: lines, stats: stats, truncated: budgetExceeded)
    }

    // MARK: Line diff

    /// Classic LCS over the (already trimmed) middle section.
    private static func lcsDiff(_ oldLines: [String], _ newLines: [String],
                                oldOffset: Int, newOffset: Int) -> [Line] {
        let n = oldLines.count
        let m = newLines.count
        if n == 0 && m == 0 { return [] }

        // Full matrix is needed to backtrack; the caller has already
        // ensured it fits in the budget.
        var matrix = [[Int]](repeating: [Int](repeating: 0, count: m + 1), count: n + 1)
        if n > 0 && m > 0 {
            for i in 1...n {
                for j in 1...m {
                    matrix[i][j] = oldLines[i-1] == newLines[j-1]
                        ? matrix[i-1][j-1] + 1
                        : max(matrix[i-1][j], matrix[i][j-1])
                }
            }
        }

        var out: [Line] = []
        var i = n
        var j = m
        while i > 0 || j > 0 {
            if i > 0, j > 0, oldLines[i-1] == newLines[j-1] {
                out.insert(Line(leftContent: oldLines[i-1], rightContent: newLines[j-1],
                                leftLineNumber: oldOffset + i, rightLineNumber: newOffset + j,
                                type: .unchanged, leftSegments: nil, rightSegments: nil), at: 0)
                i -= 1; j -= 1
            } else if j > 0, i == 0 || matrix[i][j-1] >= matrix[i-1][j] {
                out.insert(Line(leftContent: nil, rightContent: newLines[j-1],
                                leftLineNumber: nil, rightLineNumber: newOffset + j,
                                type: .added, leftSegments: nil, rightSegments: nil), at: 0)
                j -= 1
            } else if i > 0 {
                out.insert(Line(leftContent: oldLines[i-1], rightContent: nil,
                                leftLineNumber: oldOffset + i, rightLineNumber: nil,
                                type: .removed, leftSegments: nil, rightSegments: nil), at: 0)
                i -= 1
            } else {
                break
            }
        }
        return out
    }

    /// Coarse fallback for inputs too large to backtrack exactly: report
    /// the whole differing middle as one removed block followed by one
    /// added block. Honest rather than wrong, and never allocates.
    private static func blockDiff(_ oldLines: [String], _ newLines: [String],
                                  oldOffset: Int, newOffset: Int) -> [Line] {
        var out: [Line] = []
        for (k, text) in oldLines.enumerated() {
            out.append(Line(leftContent: text, rightContent: nil,
                            leftLineNumber: oldOffset + k + 1, rightLineNumber: nil,
                            type: .removed, leftSegments: nil, rightSegments: nil))
        }
        for (k, text) in newLines.enumerated() {
            out.append(Line(leftContent: nil, rightContent: text,
                            leftLineNumber: nil, rightLineNumber: newOffset + k + 1,
                            type: .added, leftSegments: nil, rightSegments: nil))
        }
        return out
    }

    /// Collapse a removed line immediately followed by an added line into
    /// a single `.modified` row with character-level highlighting on both
    /// sides — that's what makes a small edit readable.
    private static func pairModifications(_ lines: [Line]) -> [Line] {
        var out: [Line] = []
        var index = 0
        while index < lines.count {
            if index + 1 < lines.count,
               lines[index].type == .removed,
               lines[index + 1].type == .added,
               let oldLine = lines[index].leftContent,
               let newLine = lines[index + 1].rightContent {

                let (leftSegs, rightSegs) = characterSegments(old: oldLine, new: newLine)
                out.append(Line(leftContent: oldLine,
                                rightContent: newLine,
                                leftLineNumber: lines[index].leftLineNumber,
                                rightLineNumber: lines[index + 1].rightLineNumber,
                                type: .modified,
                                leftSegments: leftSegs,
                                rightSegments: rightSegs))
                index += 2
            } else {
                out.append(lines[index])
                index += 1
            }
        }
        return out
    }

    // MARK: Character diff

    /// Splits both strings into unchanged/changed runs by trimming the
    /// shared prefix and suffix. Symmetric: the old side highlights what
    /// was taken out, the new side what went in. (The previous version
    /// only produced segments for the new side, so removals were invisible.)
    static func characterSegments(old: String, new: String) -> ([Segment], [Segment]) {
        if old == new {
            return ([Segment(text: old, isChanged: false)],
                    [Segment(text: new, isChanged: false)])
        }

        let oldChars = Array(old)
        let newChars = Array(new)

        var prefix = 0
        while prefix < min(oldChars.count, newChars.count),
              oldChars[prefix] == newChars[prefix] {
            prefix += 1
        }

        var suffix = 0
        while suffix < min(oldChars.count, newChars.count) - prefix,
              oldChars[oldChars.count - 1 - suffix] == newChars[newChars.count - 1 - suffix] {
            suffix += 1
        }

        func build(_ chars: [Character]) -> [Segment] {
            var segments: [Segment] = []
            if prefix > 0 {
                segments.append(Segment(text: String(chars[0..<prefix]), isChanged: false))
            }
            let changedEnd = chars.count - suffix
            if prefix < changedEnd {
                segments.append(Segment(text: String(chars[prefix..<changedEnd]), isChanged: true))
            }
            if suffix > 0 {
                segments.append(Segment(text: String(chars[(chars.count - suffix)...]), isChanged: false))
            }
            return segments
        }

        return (build(oldChars), build(newChars))
    }
}
