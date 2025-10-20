//
//  Folder.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import Foundation

struct Folder: Identifiable {
    let id: UUID
    let name: String
    
    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}