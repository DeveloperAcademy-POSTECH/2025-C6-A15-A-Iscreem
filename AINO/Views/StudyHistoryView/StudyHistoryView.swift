//
//  StudyHistoryView.swift
//  learningTool
//
//  Created by coulson on 11/6/25.
//

import SwiftUI
import SwiftData

struct StudyHistoryView: View {
    @EnvironmentObject private var learningLogStore: LearningLogStore
    @Query private var notes: [Note]

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {

                // 상단 요약
                headerSummary

                Divider()
                    .background(Color.borderColor)

                if learningLogStore.sessions.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // 날짜별 그룹 섹션
                            ForEach(groupedByDateKeys, id: \.self) { dateKey in
                                if let sessions = groupedByDate[dateKey] {
                                    sectionFor(dateKey: dateKey, sessions: sessions)
                                }
                            }

                            // 전체 키워드 모음
                            keywordCloudSection
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .padding(20)
            .background(Color.background1.ignoresSafeArea())
            .navigationTitle("학습 기록")
        }
    }

    // MARK: - Header Summary

    private var headerSummary: some View {
        let totalSessions = learningLogStore.sessions.count
        let totalNotes = Set(learningLogStore.sessions.map { $0.noteTitle }).count

        return VStack(alignment: .leading, spacing: 8) {
            Text("나의 학습 기록")
                .font(.titleText)
                .foregroundStyle(Color.text1)

            Text("StudyView에서 학습한 노트, 마지막 재생 위치, 선택된 키워드, AI Q&A 기록이 여기에 모입니다.")
                .font(.captionText)
                .foregroundStyle(Color.text2)

            HStack(spacing: 16) {
                summaryChip(label: "총 학습 세션", value: "\(totalSessions)")
                summaryChip(label: "학습한 노트 수", value: "\(totalNotes)")
            }
            .padding(.top, 4)
        }
    }

    private func summaryChip(label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.primaryColor)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Color.text3)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.background2)
        .cornerRadius(20)
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40))
                .foregroundStyle(Color.secondColor.opacity(0.7))

            Text("아직 기록된 학습 세션이 없습니다.")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.text2)

            Text("StudyView에서 영상을 학습하고 키워드를 선택하거나\nAI에게 질문하면 이곳에 자동으로 기록됩니다.")
                .font(.system(size: 13))
                .foregroundStyle(Color.text3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.vertical, 40)
    }

    // MARK: - Grouped Sessions (by day)

    private var groupedByDate: [String: [StudySession]] {
        Dictionary(grouping: learningLogStore.sessions) { session in
            dateFormatter.string(from: session.date)
        }
    }

    private var groupedByDateKeys: [String] {
        groupedByDate.keys.sorted { lhs, rhs in
            // 최신 날짜가 위에 오도록
            if
                let d1 = dateFormatter.date(from: lhs),
                let d2 = dateFormatter.date(from: rhs)
            {
                return d1 > d2
            }
            return lhs > rhs
        }
    }

    // MARK: - Section & Cards

    @ViewBuilder
    private func sectionFor(dateKey: String, sessions: [StudySession]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(dateKey)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.text3)
                .padding(.horizontal, 4)

            ForEach(sessions) { session in
                sessionCard(for: session)
            }
        }
        .padding(.top, 16)
    }

    // MARK: - Helpers: Chapters up to current

    // “마지막 재생 시간에 해당하는 챕터까지”의 챕터 요약/키워드를 배열로 반환
    // 1) Note.cachedChaptersUpToCurrent (영구 저장) — 재실행 보장
    // 2) LearningLogStore의 메모리 맵(chapterSummariesUpToCurrentByNoteID)
    private func chaptersUpToCurrent(for s: StudySession) -> [CachedChapter] {
        if let nid = s.noteIdentifier,
           let note = notes.first(where: { String(describing: $0.id) == nid }) {
            let upTo = note.cachedChaptersUpToCurrent
            if !upTo.isEmpty { return upTo }
        }
        if
            let nid = s.noteIdentifier,
            let chapters = learningLogStore.chapterSummariesUpToCurrentByNoteID[nid],
            !chapters.isEmpty
        {
            return chapters
        }
        return []
    }

    @ViewBuilder
    private func sessionCard(for s: StudySession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 폴더 / 노트 타이틀
            HStack(spacing: 6) {
                if let folder = s.folderName, !folder.isEmpty {
                    Text(folder)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.text3)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.background2)
                        .cornerRadius(10)
                }

                Text(s.noteTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.text1)

                Spacer()
            }

            // 마지막 재생 위치
            if let pos = s.lastPosition {
                let mm = Int(pos) / 60
                let ss = Int(pos) % 60
                Text("마지막 재생 위치 \(String(format: "%d:%02d", mm, ss))")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.text3)
            }

            // 챕터별 요약(현재 시점까지)
            let chapters = chaptersUpToCurrent(for: s)
            if !chapters.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(chapters.enumerated()), id: \.offset) { idx, ch in
                        VStack(alignment: .leading, spacing: 4) {
                            // 챕터 제목
                            HStack(spacing: 6) {
                                Text("챕터 \(idx + 1)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Color.primaryColor)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.background2)
                                    .cornerRadius(6)

                                Text(ch.title.isEmpty ? "제목" : ch.title)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.text1)
                                    .lineLimit(1)
                            }

                            // 불릿(최대 4줄)
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(Array(ch.bullets.prefix(4)), id: \.self) { line in
                                    Text("• " + line)
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.text2)
                                        .lineLimit(2)
                                }
                            }

                            // 챕터 키워드(있으면)
                            if !ch.keywords.isEmpty {
                                HStack(spacing: 6) {
                                    ForEach(Array(ch.keywords.prefix(6)), id: \.self) { kw in
                                        Text(kw)
                                            .font(.system(size: 10))
                                            .foregroundStyle(Color.text2)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Color.background2)
                                            .cornerRadius(8)
                                    }
                                    if ch.keywords.count > 6 {
                                        Text("+\(ch.keywords.count - 6)")
                                            .font(.system(size: 10))
                                            .foregroundStyle(Color.text3)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        if idx < chapters.count - 1 {
                            Divider().background(Color.borderColor.opacity(0.5))
                        }
                    }
                }
                .padding(.top, 4)
            }

            // 해당 세션에서 선택된 키워드(세션 레벨)
            if !s.keywords.isEmpty {
                HStack(spacing: 6) {
                    ForEach(Array(s.keywords.prefix(6)), id: \.self) { kw in
                        Text(kw)
                            .font(.system(size: 10))
                            .foregroundStyle(Color.text2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.background2)
                            .cornerRadius(10)
                    }
                    if s.keywords.count > 6 {
                        Text("+\(s.keywords.count - 6)")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.text3)
                    }
                }
                .padding(.top, 2)
            }

            // 최신 Q&A 한 줄 미리보기
            if let qa = s.qaPairs.last {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Q. \(qa.question)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.primaryColor)
                        .lineLimit(1)

                    Text("A. \(qa.answer)")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.text3)
                        .lineLimit(2)
                }
                .padding(.top, 4)
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.borderColor.opacity(0.4), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.02), radius: 4, x: 0, y: 2)
    }

    // MARK: - Aggregated Keyword Cloud

    private struct KeywordStat: Identifiable, Hashable {
        let id = UUID()
        let keyword: String
        let count: Int
    }

    private var aggregatedKeywordStats: [KeywordStat] {
        var dict: [String: Int] = [:]

        for session in learningLogStore.sessions {
            for kw in session.keywords {
                let trimmed = kw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                dict[trimmed, default: 0] += 1
            }
        }

        return dict
            .sorted { $0.value > $1.value }
            .map { KeywordStat(keyword: $0.key, count: $0.value) }
    }

    private var keywordCloudSection: some View {
        Group {
            let stats = aggregatedKeywordStats
            if stats.isEmpty {
                EmptyView()
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("자주 선택된 키워드")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.text2)
                        .padding(.horizontal, 4)

                    FlexibleView(
                        data: stats,
                        spacing: 8,
                        alignment: .leading
                    ) { stat in
                        keywordChip(for: stat)
                    }
                }
                .padding(.top, 24)
            }
        }
    }

    private func keywordChip(for stat: KeywordStat) -> some View {
        HStack(spacing: 4) {
            Text(stat.keyword)
                .font(.system(size: 11, weight: .medium))
            Text("\(stat.count)")
                .font(.system(size: 10, weight: .regular))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.background2)
        )
        .overlay(
            Capsule()
                .stroke(Color.borderColor.opacity(0.9), lineWidth: 0.5)
        )
        .foregroundStyle(Color.text2)
    }
}

// MARK: - FlexibleView (간단한 플로우 레이아웃)

private struct FlexibleView<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let spacing: CGFloat
    let alignment: HorizontalAlignment
    let content: (Data.Element) -> Content

    init(
        data: Data,
        spacing: CGFloat = 8,
        alignment: HorizontalAlignment = .leading,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.data = data
        self.spacing = spacing
        self.alignment = alignment
        self.content = content
    }

    var body: some View {
        GeometryReader { geometry in
            generateContent(in: geometry)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func generateContent(in geometry: GeometryProxy) -> some View {
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0

        return ZStack(alignment: Alignment(horizontal: alignment, vertical: .top)) {
            ForEach(Array(data), id: \.self) { element in
                content(element)
                    .alignmentGuide(.leading) { d in
                        if currentX + d.width > geometry.size.width {
                            currentX = 0
                            currentY -= (d.height + spacing)
                        }
                        let result = currentX
                        currentX += d.width + spacing
                        return -result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = currentY
                        return result
                    }
            }
        }
    }
}
#if DEBUG
#Preview(traits: .landscapeLeft) {
    StudyHistoryView()
        .environmentObject(LearningLogStore.previewStore())
}
#endif
