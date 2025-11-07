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
    /// 모든 학습 세션 (JSON로 디스크에 저장/복원)
    @Published private(set) var sessions: [StudySession] = [] {
        didSet { persist() }
    }

    // MARK: - Init (load from disk)
    init() {
        load()
    }

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
        persist()
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
            persist()
        }
    }

    /// 키워드 수동 추가
    func addKeyword(_ keyword: String, to sessionID: UUID) {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let idx = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        if !sessions[idx].keywords.contains(trimmed) {
            sessions[idx].keywords.append(trimmed)
            persist()
        }
    }

    /// 키워드 삭제
    func removeKeyword(_ keyword: String, from sessionID: UUID) {
        guard let idx = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        sessions[idx].keywords.removeAll { $0 == keyword }
        persist()
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
        persist()
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

// MARK: - Persistence (JSON on disk)
extension LearningLogStore {
    private var storageURL: URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("learningTool", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("LearningLogSessions.json")
    }

    private func persist() {
        // JSON으로 저장
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(sessions)
            try data.write(to: storageURL, options: [.atomic])
        } catch {
            print("⚠️ LearningLogStore persist failed: \(error)")
        }
    }

    private func load() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let loaded = try decoder.decode([StudySession].self, from: data)
            self.sessions = loaded
        } catch {
            print("⚠️ LearningLogStore load failed: \(error)")
            self.sessions = []
        }
    }
}

#if DEBUG
extension LearningLogStore {
    @MainActor
    static func previewStore() -> LearningLogStore {
        let store = LearningLogStore()
        // 미리보기에서는 더미 데이터를 주입 (디스크 저장은 하지 않음)
        store.objectWillChange.send()
        store.sessions = [
            StudySession(
                date: Date(),
                folderName: "네트워크",
                noteTitle: "데이터통신 제1장 개요",
                noteIdentifier: "note-001",
                videoURL: "https://youtu.be/example1",
                lastPosition: 842,
                lastTextSnippet: "패킷 교환 방식은 회선 교환보다 회선 효율을 높일 수 있습니다.",
                keywords: ["패킷 교환", "회선 교환", "LAN", "WAN", "프로토콜"],
                qaPairs: [
                    StudyQAPair(
                        question: "이 강의의 핵심 개념을 한 줄로 정리해줘.",
                        answer: "계층형 네트워크 구조와 패킷 교환 원리를 이해하는 것이 핵심입니다."
                    ),
                    StudyQAPair(
                        question: "TCP와 UDP 차이점을 인터뷰 답변용으로 정리해줘.",
                        answer: "TCP는 연결 지향·신뢰성과 순서를 보장하고, UDP는 비연결·저지연 스트리밍에 적합하다고 설명하면 됩니다."
                    )
                ]
            )
        ]
        return store
    }
}
#endif
