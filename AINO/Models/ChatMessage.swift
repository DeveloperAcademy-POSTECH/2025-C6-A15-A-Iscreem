//
//  ChatMessage.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import Foundation

struct ChatMessage: Identifiable {
    let id: UUID
    let text: String
    let isUser: Bool
    let timestamp: Date
    let imageData: Data?
    
    init(
        id: UUID = UUID(),
        text: String,
        isUser: Bool,
        timestamp: Date = Date(),
        imageData: Data? = nil
    ) {
        self.id = id
        self.text = text
        self.isUser = isUser
        self.timestamp = timestamp
        self.imageData = imageData
    }
}

