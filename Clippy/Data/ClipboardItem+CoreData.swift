//
//  ClipboardItem+CoreData.swift
//  Clippy
//
//  Created by Mehmet Akbaba on 22.09.2025.
//


import Foundation
import CoreData

extension ClipboardItemEntity {
    func toClipboardItem() -> ClipboardItem {
        let itemContentType: ClipboardItem.ContentType

        if self.contentType == "image", let path = self.content {
            itemContentType = .image(imagePath: path)
        } else {
            itemContentType = .text(self.content ?? "")
        }

        return ClipboardItem(id: self.id ?? UUID(),
                             contentType: itemContentType,
                             date: self.date ?? Date(),
                             isFavorite: self.isFavorite,
                             isCode: self.isCode,
                             title: self.title,
                             isPinned: self.isPinned,
                             isEncrypted: self.isEncrypted,
                             keyword: self.keyword,
                             sourceAppName: self.sourceAppName,
                             sourceAppBundleIdentifier: self.sourceAppBundleIdentifier,
                             category: self.category,
                             usageCount: self.usageCount,
                             lastUsedDate: self.lastUsedDate)
    }
}

// MARK: - What counts as "the user meant to keep this"

extension ClipboardItemEntity {

    /// Items the user deliberately saved: a snippet, something pinned,
    /// starred, or locked.
    ///
    /// One definition, used by everything that deletes in bulk. Automatic
    /// pruning must never touch these, and neither must "Clear
    /// Everything" — if those two ever disagreed about what "protected"
    /// means, one of them would quietly start deleting things the other
    /// promised to keep. That is not a comment anyone would notice going
    /// stale, so it isn't a comment.
    static let protectedPredicate = NSPredicate(format:
        "(keyword != nil AND keyword != '') OR isPinned == YES OR isFavorite == YES OR isEncrypted == YES"
    )

    /// The complement: everything a bulk delete is allowed to remove.
    static let prunablePredicate = NSPredicate(format:
        "(keyword == nil OR keyword == '') AND isPinned == NO AND isFavorite == NO AND isEncrypted == NO"
    )
}
