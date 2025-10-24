//
//  Note.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import Foundation
import SwiftData

@Model
final class Note {
    var title: String
    var lastRead: Date
    var thumbnailURL: String?
    var createdAt: Date
    @Relationship var folder: Folder?

    init(
        title: String,
        lastRead: Date = .now,
        thumbnailURL: String? = nil,
        folder: Folder? = nil,
        createdAt: Date = .now
    ) {
        self.title = title
        self.lastRead = lastRead
        self.thumbnailURL = thumbnailURL
        self.folder = folder
        self.createdAt = createdAt
    }
}
