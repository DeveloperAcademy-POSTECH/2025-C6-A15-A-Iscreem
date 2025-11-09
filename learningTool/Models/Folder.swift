//
//  Folder.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import Foundation
import SwiftData

@Model
final class Folder {
    @Attribute(.unique) var name: String
    var createdAt: Date

    // 휴지통(소프트 삭제) 상태
    var isTrashed: Bool = false
    var trashedAt: Date? = nil
    
    // 폴더 삭제 시 포함된 노트도 함께 삭제
    @Relationship(deleteRule: .cascade, inverse: \Note.folder)
    var notes: [Note] = []
    
    init(name: String, createdAt: Date = .now){
        self.name = name
        self.createdAt = createdAt
    }
}
