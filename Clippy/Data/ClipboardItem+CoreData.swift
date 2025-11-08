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
                             sourceAppBundleIdentifier: self.sourceAppBundleIdentifier)
    }
}
