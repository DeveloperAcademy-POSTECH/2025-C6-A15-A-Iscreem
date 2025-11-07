//
//  LearningLogStore.swift
//  learningTool
//
//  Created by coulson on 11/6/25.
//  학습 기록/요약/키워드/Q&A를 모으는 중앙 스토어
//

import Foundation
import Combine

// MARK: - Data Models

struct StudyQAPair: Identifiable, Codable, Hashable {
    let id: UUID
    let question: String
    let answer: String
    let createdAt: Date

    init(id: UUID = UUID(), question: String, answer: String, createdAt: Date = Date()) {
        self.id = id
        self.question = question
        self.answer = answer
        self.createdAt = createdAt
    }
}

struct StudySession: Identifiable, Codable, Hashable {
    let id: UUID
    let date: Date            // 학습한 날짜 (일 단위 그룹용)
    let folderName: String?   // 어떤 폴더에서 온 노트인지 (없으면 nil)
    let noteTitle: String     // 노트 제목
    let noteIdentifier: String? // Note의 식별자(필요시 Note.id 등 문자열화)
    let videoURL: String?

    var lastPosition: TimeInterval?   // 마지막 재생 위치 (초)
    var lastTextSnippet: String?      // 그 지점의 원문 텍스트 일부

    var keywords: [String]            // 이 노트에서 선택된 키워드 모음 (편집 가능)
    var qaPairs: [StudyQAPair]        // 이 노트에서 발생한 Q&A

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        folderName: String?,
        noteTitle: String,
        noteIdentifier: String?,
        videoURL: String?,
        lastPosition: TimeInterval? = nil,
        lastTextSnippet: String? = nil,
        keywords: [String] = [],
        qaPairs: [StudyQAPair] = []
    ) {
        self.id = id
        self.date = date
        self.folderName = folderName
        self.noteTitle = noteTitle
        self.noteIdentifier = noteIdentifier
        self.videoURL = videoURL
        self.lastPosition = lastPosition
        self.lastTextSnippet = lastTextSnippet
        self.keywords = keywords
        self.qaPairs = qaPairs
    }
}

// MARK: - Store

@MainActor
final class LearningLogStore: ObservableObject {
    /// 모든 학습 세션 (일단 인메모리. 나중에 SwiftData/파일 저장 연동 가능)
    @Published private(set) var sessions: [StudySession] = []

    // MARK: - Helper: 세션 찾기/생성

    private func indexForSession(
        folderName: String?,
        noteTitle: String,
        noteIdentifier: String?,
        videoURL: String?
    ) -> Int? {
        sessions.firstIndex { s in
            // 식별자 우선, 없으면 제목+URL 조합으로 매칭
            if let nid = noteIdentifier, let sid = s.noteIdentifier {
                if nid == sid { return true }
            }
            if s.noteTitle == noteTitle {
                if let v1 = s.videoURL, let v2 = videoURL, v1 == v2 {
                    return true
                }
                if videoURL == nil { return true }
            }
            return false
        }
    }

    private func ensureSession(
        folderName: String?,
        noteTitle: String,
        noteIdentifier: String?,
        videoURL: String?
    ) -> Int {
        if let idx = indexForSession(
            folderName: folderName,
            noteTitle: noteTitle,
            noteIdentifier: noteIdentifier,
            videoURL: videoURL
        ) {
            return idx
        }
        let session = StudySession(
            folderName: folderName,
            noteTitle: noteTitle,
            noteIdentifier: noteIdentifier,
            videoURL: videoURL
        )
        sessions.append(session)
        return sessions.count - 1
    }

    // MARK: - Public API (뷰/로직에서 호출)

    /// 재생 위치 & 해당 시점 텍스트 기록
    func recordProgress(
        folderName: String?,
        noteTitle: String,
        noteIdentifier: String? = nil,
        videoURL: String? = nil,
        position: TimeInterval?,
        snippet: String?
    ) {
        let idx = ensureSession(
            folderName: folderName,
            noteTitle: noteTitle,
            noteIdentifier: noteIdentifier,
            videoURL: videoURL
        )
        sessions[idx].lastPosition = position
        sessions[idx].lastTextSnippet = snippet
    }

    /// 키워드 사용 기록 (한 번 이상 선택된 키워드 모으기)
    func recordKeywordUse(
        folderName: String?,
        noteTitle: String,
        noteIdentifier: String? = nil,
        videoURL: String? = nil,
        keyword: String
    ) {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let idx = ensureSession(
            folderName: folderName,
            noteTitle: noteTitle,
            noteIdentifier: noteIdentifier,
            videoURL: videoURL
        )
        if !sessions[idx].keywords.contains(trimmed) {
            sessions[idx].keywords.append(trimmed)
        }
    }

    /// 키워드 수동 추가
    func addKeyword(_ keyword: String, to sessionID: UUID) {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let idx = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        if !sessions[idx].keywords.contains(trimmed) {
            sessions[idx].keywords.append(trimmed)
        }
    }

    /// 키워드 삭제
    func removeKeyword(_ keyword: String, from sessionID: UUID) {
        guard let idx = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        sessions[idx].keywords.removeAll { $0 == keyword }
    }

    /// Q&A 기록 (QuestionView에서 호출)
    func recordQAPair(
        folderName: String?,
        noteTitle: String,
        noteIdentifier: String? = nil,
        videoURL: String? = nil,
        question: String,
        answer: String
    ) {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let a = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !a.isEmpty else { return }

        let idx = ensureSession(
            folderName: folderName,
            noteTitle: noteTitle,
            noteIdentifier: noteIdentifier,
            videoURL: videoURL
        )
        let pair = StudyQAPair(question: q, answer: a)
        sessions[idx].qaPairs.append(pair)
    }

    // MARK: - Aggregation (ML/요약용)

    /// 전체 세션에서 최소 1회 이상 등장한 키워드 모음 (빈도순)
    var aggregatedKeywords: [(keyword: String, count: Int)] {
        var freq: [String: Int] = [:]
        for s in sessions {
            for k in s.keywords {
                freq[k, default: 0] += 1
            }
        }
        return freq
            .sorted { $0.value > $1.value }
            .map { ($0.key, $0.value) }
    }
}

#if DEBUG
extension LearningLogStore {
    @MainActor
    static func previewStore() -> LearningLogStore {
        let store = LearningLogStore()
        let now = Date()
        let cal = Calendar.current

        let day0 = now
        let day1 = cal.date(byAdding: .day, value: -1, to: now) ?? now
        let day3 = cal.date(byAdding: .day, value: -3, to: now) ?? now

        let qa1 = StudyQAPair(
            question: "이 강의의 핵심 개념을 한 줄로 정리해줘.",
            answer: "계층형 네트워크 구조와 패킷 교환 원리를 이해하는 것이 핵심입니다."
        )

        let qa2 = StudyQAPair(
            question: "TCP와 UDP 차이점을 인터뷰 답변용으로 정리해줘.",
            answer: "TCP는 연결 지향·신뢰성과 순서를 보장하고, UDP는 비연결·저지연 스트리밍에 적합하다고 설명하면 됩니다."
        )

        let qa3 = StudyQAPair(
            question: "이 노트에서 꼭 외워야 할 키워드는?",
            answer: "OSI 7계층, MTU, 혼잡 제어, 슬라이딩 윈도우, 지연 시간."
        )

        store.sessions = [
            // 오늘: 네트워크 노트 + Q&A + 키워드 + 진행도
            StudySession(
                date: day0,
                folderName: "네트워크",
                noteTitle: "데이터통신 제1장 개요",
                noteIdentifier: "note-001",
                videoURL: "https://youtu.be/example1",
                lastPosition: 842,
                lastTextSnippet: "패킷 교환 방식은 회선 교환보다 회선 효율을 높일 수 있습니다.",
                keywords: ["패킷 교환", "회선 교환", "LAN", "WAN", "프로토콜"],
                qaPairs: [qa1, qa2]
            ),

            // 오늘: iOS 노트 (키워드만)
            StudySession(
                date: day0,
                folderName: "iOS",
                noteTitle: "SwiftUI 기초 총정리",
                noteIdentifier: "note-002",
                videoURL: "https://youtu.be/example2",
                lastPosition: 1260,
                lastTextSnippet: "State와 Binding을 통해 단방향 데이터 플로우를 유지합니다.",
                keywords: ["SwiftUI", "State", "Binding", "MVVM"],
                qaPairs: []
            ),

            // 1일 전: 자료구조 노트 + Q&A
            StudySession(
                date: day1,
                folderName: "자료구조",
                noteTitle: "알고리즘 시간복잡도",
                noteIdentifier: "note-003",
                videoURL: "https://youtu.be/example3",
                lastPosition: 560,
                lastTextSnippet: "빅오 표기법은 최악의 경우를 기준으로 복잡도를 나타냅니다.",
                keywords: ["빅오", "시간복잡도", "선형 시간", "로그 시간"],
                qaPairs: [qa3]
            ),

            // 3일 전: 네트워크 심화 (키워드만)
            StudySession(
                date: day3,
                folderName: "네트워크",
                noteTitle: "TCP 심화",
                noteIdentifier: "note-004",
                videoURL: "https://youtu.be/example4",
                lastPosition: nil,
                lastTextSnippet: nil,
                keywords: ["TCP", "혼잡 제어", "슬라이딩 윈도우"],
                qaPairs: []
            )
        ]

        return store
    }
}
#endif
