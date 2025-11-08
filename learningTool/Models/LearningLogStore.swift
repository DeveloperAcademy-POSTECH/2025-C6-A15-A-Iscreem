//
//  LearningLogStore.swift
//  learningTool
//
//  Created by coulson on 11/6/25.
//  학습 기록/요약/키워드/Q&A를 SwiftData로 일원화 저장
//

import Foundation
import Combine
import SwiftData

// MARK: - Data Models (@Model)

@Model
final class StudyQAPair {
    var id: UUID
    var question: String
    var answer: String
    var createdAt: Date

    // 세션 역관계(필수는 아님). 세션 삭제 시 Q&A도 함께 삭제되도록 cascade 규칙은 세션 쪽에서 지정.
    @Relationship(inverse: \StudySession.qaPairs)
    var session: StudySession?

    init(id: UUID = UUID(), question: String, answer: String, createdAt: Date = Date()) {
        self.id = id
        self.question = question
        self.answer = answer
        self.createdAt = createdAt
    }
}

@Model
final class StudySession {
    var id: UUID
    var date: Date            // 학습한 날짜 (일 단위 그룹용)
    var folderName: String?   // 어떤 폴더에서 온 노트인지 (없으면 nil)
    var noteTitle: String     // 노트 제목
    var noteIdentifier: String? // Note의 식별자(필요시 Note.id 등 문자열화)
    var videoURL: String?

    var lastPosition: TimeInterval?   // 마지막 재생 위치 (초)

    var keywords: [String]            // 이 노트에서 선택된 키워드 모음 (편집 가능)

    @Relationship(deleteRule: .cascade)
    var qaPairs: [StudyQAPair]        // 이 노트에서 발생한 Q&A

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        folderName: String?,
        noteTitle: String,
        noteIdentifier: String?,
        videoURL: String?,
        lastPosition: TimeInterval? = nil,
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
        self.keywords = keywords
        self.qaPairs = qaPairs
    }
}

// MARK: - Store

@MainActor
final class LearningLogStore: ObservableObject {
    /// SwiftData 컨텍스트
    private let context: ModelContext

    /// 모든 학습 세션 (SwiftData에서 fetch하여 보관)
    @Published private(set) var sessions: [StudySession] = []

    /// 노트별 “00:00 ~ 현재 챕터까지”의 챕터별 요약 스냅샷
    /// - 키: String(describing: Note.id)
    /// - 값: CachedChapter 배열
    @Published var chapterSummariesUpToCurrentByNoteID: [String: [CachedChapter]] = [:]

    // MARK: - Init
    init(context: ModelContext) {
        self.context = context
        refreshSessions()
    }

    // MARK: - Fetch/Refresh
    private func refreshSessions() {
        do {
            var desc = FetchDescriptor<StudySession>()
            // 최신 날짜 순으로 정렬 (원하면 변경)
            desc.sortBy = [
                .init(\.date, order: .reverse),
                .init(\.noteTitle, order: .forward)
            ]
            self.sessions = try context.fetch(desc)
        } catch {
            print("⚠️ LearningLogStore fetch failed: \(error)")
            self.sessions = []
        }
    }

    private func saveAndRefresh() {
        do {
            try context.save()
        } catch {
            print("⚠️ LearningLogStore save failed: \(error)")
        }
        refreshSessions()
    }

    // MARK: - Matching rule (Note ↔ Session)
    /// 동일 노트 판정 규칙: 식별자 우선, 없으면 (제목 + URL 일치) 또는 (제목만 일치하면서 URL 미지정)
    private func isSameNote(session s: StudySession,
                            noteTitle: String,
                            noteIdentifier: String?,
                            videoURL: String?) -> Bool {
        if let nid = noteIdentifier, let sid = s.noteIdentifier, nid == sid {
            return true
        }
        if s.noteTitle == noteTitle {
            if let v1 = s.videoURL, let v2 = videoURL, v1 == v2 {
                return true
            }
            if videoURL == nil { return true }
        }
        return false
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
        context.insert(session)
        saveAndRefresh()
        return sessions.firstIndex(where: { $0.id == session.id }) ?? (sessions.count - 1)
    }

    // MARK: - Public API (기록)

    /// 재생 위치 기록
    func recordProgress(
        folderName: String?,
        noteTitle: String,
        noteIdentifier: String? = nil,
        videoURL: String? = nil,
        position: TimeInterval?
    ) {
        let idx = ensureSession(
            folderName: folderName,
            noteTitle: noteTitle,
            noteIdentifier: noteIdentifier,
            videoURL: videoURL
        )
        sessions[idx].lastPosition = position
        saveAndRefresh()
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
            saveAndRefresh()
        }
    }

    /// 키워드 수동 추가
    func addKeyword(_ keyword: String, to sessionID: UUID) {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let idx = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        if !sessions[idx].keywords.contains(trimmed) {
            sessions[idx].keywords.append(trimmed)
            saveAndRefresh()
        }
    }

    /// 키워드 삭제
    func removeKeyword(_ keyword: String, from sessionID: UUID) {
        guard let idx = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        sessions[idx].keywords.removeAll { $0 == keyword }
        saveAndRefresh()
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
        pair.session = sessions[idx] // 역관계 연결(선택)
        sessions[idx].qaPairs.append(pair)
        saveAndRefresh()
    }

    // MARK: - “현재 챕터까지” 요약 상태 업데이트/노출

    /// 키워드를 UI로 뿌리기 직전에, “00:00 ~ 현재 챕터까지”의 챕터별 요약 스냅샷을 Note에 저장하고
    /// 동시에 메모리 매핑을 갱신하여 학습 기록 UI에서 즉시 활용 가능하도록 한다.
    func updateChapterSummariesUpToCurrent(for note: Note, chapters: [CachedChapter]) {
        // 1) Note에 영속 저장
        note.cachedChaptersUpToCurrent = chapters
        do {
            try context.save()
        } catch {
            print("⚠️ updateChapterSummariesUpToCurrent save failed: \(error)")
        }
        // 2) 메모리 매핑 갱신 (학습 기록 UI에서 noteIdentifier로 조회)
        let nid = String(describing: note.id)
        chapterSummariesUpToCurrentByNoteID[nid] = chapters
    }

    // MARK: - 삭제 API (노트/폴더/전체 초기화)

    /// 특정 노트의 학습 로그 세션을 삭제 (식별자 우선, 없으면 제목+URL 규칙)
    /// - Returns: 삭제된 세션 개수
    @discardableResult
    func deleteSessionsForNote(noteTitle: String, noteIdentifier: String? = nil, videoURL: String? = nil) -> Int {
        let targets = sessions.filter { s in
            isSameNote(session: s, noteTitle: noteTitle, noteIdentifier: noteIdentifier, videoURL: videoURL)
        }
        for s in targets { context.delete(s) }
        let removed = targets.count
        if removed > 0 { saveAndRefresh() }
        return removed
    }

    /// 여러 노트에 대한 학습 로그를 일괄 삭제
    /// - Parameter notes: (title, identifier, url) 튜플 배열
    /// - Returns: 삭제된 총 세션 개수
    @discardableResult
    func deleteSessionsForNotes(_ notes: [(title: String, identifier: String?, url: String?)]) -> Int {
        var removed = 0
        for s in sessions {
            for n in notes {
                if isSameNote(session: s, noteTitle: n.title, noteIdentifier: n.identifier, videoURL: n.url) {
                    context.delete(s)
                    removed += 1
                    break
                }
            }
        }
        if removed > 0 { saveAndRefresh() }
        return removed
    }

    /// 특정 폴더의 학습 로그를 삭제 (폴더 내 모든 노트의 세션)
    /// - Returns: 삭제된 세션 개수
    @discardableResult
    func deleteSessionsInFolder(folderName: String) -> Int {
        let targets = sessions.filter { ($0.folderName ?? "") == folderName }
        for s in targets { context.delete(s) }
        let removed = targets.count
        if removed > 0 { saveAndRefresh() }
        return removed
    }

    /// 모든 학습 로그를 초기화
    func resetAllSessions() {
        for s in sessions { context.delete(s) }
        saveAndRefresh()
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

// MARK: - SwiftData 편의 API (Note/Folder와 직접 연동)
extension LearningLogStore {
    /// 단일 노트 삭제 시 호출
    @discardableResult
    func deleteSessions(for note: Note) -> Int {
        deleteSessionsForNote(
            noteTitle: note.title,
            noteIdentifier: String(describing: note.id),
            videoURL: note.videoURL
        )
    }

    /// 다중 노트 삭제 시 호출
    @discardableResult
    func deleteSessions(for notes: [Note]) -> Int {
        let tuples = notes.map {
            (title: $0.title, identifier: String(describing: $0.id), url: $0.videoURL)
        }
        return deleteSessionsForNotes(tuples)
    }

    /// 폴더 삭제(혹은 폴더 내 전체 삭제) 시 호출
    @discardableResult
    func deleteSessions(in folder: Folder) -> Int {
        deleteSessionsInFolder(folderName: folder.name)
    }

    /// 현재 SwiftData에 남아있는 노트 목록과 동기화하여,
    /// 더 이상 존재하지 않는 노트의 세션(고아 세션)을 정리
    /// - Returns: 제거된 세션 수
    @discardableResult
    func reconcileWithNotes(currentNotes: [Note]) -> Int {
        // 초기 페치 타이밍 보호: 노트가 아직 비어 있으면 아무것도 하지 않음
        guard !currentNotes.isEmpty else { return 0 }

        // 1) 남아있는 노트의 식별자/제목+URL 집합 구성
        let identifiers = Set(currentNotes.map { String(describing: $0.id) })
        // 제목+URL 키 (URL 없으면 제목만) — 세션 생성/보강과 동일하게 videoURL ?? thumbnailURL 사용
        let titleURLKeys: Set<String> = Set(currentNotes.map { note in
            let url = note.videoURL ?? note.thumbnailURL
            if let url, !url.isEmpty {
                return "T:\(note.title)|U:\(url)"
            } else {
                return "T:\(note.title)|U:nil"
            }
        })

        var removed = 0
        for s in sessions {
            // 식별자가 남아있다면 보존
            if let sid = s.noteIdentifier, identifiers.contains(sid) { continue }
            // 식별자가 없거나 매칭 실패 → 제목+URL 키로 재확인
            let key: String = {
                if let url = s.videoURL, !url.isEmpty {
                    return "T:\(s.noteTitle)|U:\(url)"
                } else {
                    return "T:\(s.noteTitle)|U:nil"
                }
            }()
            // 현재 노트 집합에 없는 세션은 제거
            if !titleURLKeys.contains(key) {
                context.delete(s)
                removed += 1
            }
        }
        if removed > 0 { saveAndRefresh() }
        return removed
    }

    /// 앱을 켰을 때 또는 노트 목록이 바뀔 때,
    /// SwiftData의 Note들로부터 학습 세션을 만들어 채워 넣는다(존재하지 않는 경우에만).
    /// - Returns: 새로 생성된 세션 수
    @discardableResult
    func bootstrapSessionsIfNeeded(currentNotes: [Note]) -> Int {
        var created = 0
        for note in currentNotes {
            let folderName = note.folder?.name
            let title = note.title
            let nid = String(describing: note.id)
            // 가능한 한 실제 재생에 쓰는 URL을 우선 사용
            let url = note.videoURL ?? note.thumbnailURL

            if indexForSession(folderName: folderName, noteTitle: title, noteIdentifier: nid, videoURL: url) == nil {
                let session = StudySession(folderName: folderName, noteTitle: title, noteIdentifier: nid, videoURL: url)
                session.lastPosition = note.lastPositionSeconds
                if !note.cachedKeywords.isEmpty {
                    // 중복 제거 후 설정
                    let uniq = Array(Set(note.cachedKeywords)).sorted()
                    session.keywords = uniq
                }
                context.insert(session)
                created += 1
            }
        }
        if created > 0 { saveAndRefresh() }
        return created
    }

    /// 기존 세션도, 비어있는 필드를 Note의 데이터를 이용해 보강한다.
    /// - Returns: 업데이트된 세션 수
    @discardableResult
    func enrichSessionsFromNotes(currentNotes: [Note]) -> Int {
        var updated = 0
        for note in currentNotes {
            let folderName = note.folder?.name
            let title = note.title
            let nid = String(describing: note.id)
            let url = note.videoURL ?? note.thumbnailURL

            if let idx = indexForSession(folderName: folderName, noteTitle: title, noteIdentifier: nid, videoURL: url) {
                // lastPosition이 비어 있고 Note에 값이 있으면 채움
                if sessions[idx].lastPosition == nil, let lp = note.lastPositionSeconds, lp > 0 {
                    sessions[idx].lastPosition = lp
                    updated += 1
                }
                // 키워드 합치기 (세션에 없는 것만 추가)
                if !note.cachedKeywords.isEmpty {
                    var set = Set(sessions[idx].keywords)
                    let before = set.count
                    for k in note.cachedKeywords where !k.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        set.insert(k)
                    }
                    if set.count != before {
                        sessions[idx].keywords = Array(set).sorted()
                        updated += 1
                    }
                }
            }
        }
        if updated > 0 { saveAndRefresh() }
        return updated
    }
}

#if DEBUG
extension LearningLogStore {
    @MainActor
    static func previewStore() -> LearningLogStore {
        // 미리보기/샘플용 인메모리 컨테이너
        let schema = Schema([StudySession.self, StudyQAPair.self, Note.self, Folder.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)
        let ctx = ModelContext(container)

        let store = LearningLogStore(context: ctx)

        // 더미 데이터 주입
        let s = StudySession(
            date: Date(),
            folderName: "네트워크",
            noteTitle: "데이터통신 제1장 개요",
            noteIdentifier: "note-001",
            videoURL: "https://youtu.be/example1",
            lastPosition: 842,
            keywords: ["패킷 교환", "회선 교환", "LAN", "WAN", "프로토콜"]
        )
        let q1 = StudyQAPair(
            question: "이 강의의 핵심 개념을 한 줄로 정리해줘.",
            answer: "계층형 네트워크 구조와 패킷 교환 원리를 이해하는 것이 핵심입니다."
        )
        let q2 = StudyQAPair(
            question: "TCP와 UDP 차이점을 인터뷰 답변용으로 정리해줘.",
            answer: "TCP는 연결 지향·신뢰성과 순서를 보장하고, UDP는 비연결·저지연 스트리밍에 적합하다고 설명하면 됩니다."
        )
        q1.session = s
        q2.session = s
        s.qaPairs = [q1, q2]

        ctx.insert(s)
        try? ctx.save()

        store.refreshSessions()
        return store
    }
}
#endif

