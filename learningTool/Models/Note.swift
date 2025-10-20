//
//  Note.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import Foundation

struct Note: Identifiable {
    let id: UUID
    let title: String
    let lastRead: Date
    let thumbnailURL: String?
    
    init(
        id: UUID = UUID(),
        title: String,
        lastRead: Date,
        thumbnailURL: String? = nil
    ) {
        self.id = id
        self.title = title
        self.lastRead = lastRead
        self.thumbnailURL = thumbnailURL
    }
}