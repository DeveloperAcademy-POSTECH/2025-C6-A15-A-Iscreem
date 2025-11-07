//
//  Note.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import Foundation
import SwiftData

/// 요약 재활용을 위한 챕터 캐시(제목 + 4줄 요약 + 키워드)
struct CachedChapter: Codable, Hashable {
    var title: String
    var bullets: [String]
    var keywords: [String] = [] // 🔹 챕터별 키워드 추가
}

@Model
final class Note {
    var title: String
    var lastRead: Date
    var thumbnailURL: String?
    var createdAt: Date
    @Relationship var folder: Folder?
    var videoURL: String?

    // ✅ 마지막 시청 위치(초)
    var lastPositionSeconds: Double?

    // ✅ 요약/키워드/챕터 캐시
    var cachedFinalSummary: String?
    var cachedSummaryLines: [String] = []
    var cachedKeywords: [String] = []
    var cachedChaptersBlob: Data?
    
    /// 직렬화된 blob을 투명하게 다루기 위한 편의 접근자
    var cachedChapters: [CachedChapter] {
        get {
            guard let d = cachedChaptersBlob else { return [] }
            return (try? JSONDecoder().decode([CachedChapter].self, from: d)) ?? []
        }
        set {
            cachedChaptersBlob = try? JSONEncoder().encode(newValue)
        }
    }
    
    init(
        title: String,
        lastRead: Date = .now,
        thumbnailURL: String? = nil,
        folder: Folder? = nil,
        createdAt: Date = .now,
        videoURL: String? = nil,
        lastPositionSeconds: Double? = nil,
        cachedFinalSummary: String? = nil,
        cachedSummaryLines: [String] = [],
        cachedKeywords: [String] = [],
        cachedChapters: [CachedChapter] = []
    ) {
        self.title = title
        self.lastRead = lastRead
        self.thumbnailURL = thumbnailURL
        self.folder = folder
        self.createdAt = createdAt
        self.videoURL = videoURL
        self.lastPositionSeconds = lastPositionSeconds
        self.cachedFinalSummary = cachedFinalSummary
        self.cachedSummaryLines = cachedSummaryLines
        self.cachedKeywords = cachedKeywords
        self.cachedChaptersBlob = try? JSONEncoder().encode(cachedChapters)
    }
}

