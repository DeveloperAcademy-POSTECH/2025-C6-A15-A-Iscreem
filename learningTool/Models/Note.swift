//
//  Note.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import Foundation
import SwiftData


/// 요약 재활용을 위한 챕터 캐시(제목 + 4줄 요약)
struct CachedChapter: Codable, Hashable {
    var title: String
    var bullets: [String]
}

@Model
final class Note {
    var title: String
    var lastRead: Date
    var thumbnailURL: String?
    var createdAt: Date
    @Relationship var folder: Folder?
    // 원본 영상 링크(선택사항). 기존에 썸네일 URL에 링크를 넣어뒀다면 점진 전환용으로 둡니다.
    var videoURL: String?

    // ✅ 요약/키워드/챕터 캐시(요약이 완료되면 저장하고, 노트 재오픈 시 재활용)
    var cachedFinalSummary: String?
    var cachedSummaryLines: [String] = []     // "• 한 줄 요약…" 식의 줄단위 텍스트
    var cachedKeywords: [String] = []         // 키워드 목록
    var cachedChaptersBlob: Data?             // [CachedChapter]를 JSON으로 직렬화하여 보관
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
        self.cachedFinalSummary = cachedFinalSummary
        self.cachedSummaryLines = cachedSummaryLines
        self.cachedKeywords = cachedKeywords
        // blob 필드로 직렬화하여 저장
        self.cachedChaptersBlob = try? JSONEncoder().encode(cachedChapters)
    }
}
