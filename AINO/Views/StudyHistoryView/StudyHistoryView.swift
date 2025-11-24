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
    @EnvironmentObject private var localizationManager: LocalizationManager
    @Query private var notes: [Note]

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    // 제목 위쪽에 추가로 줄 패딩 값
    private let headerExtraTopPadding: CGFloat = 16
    // Divider(요약 아래)와 첫 날짜 섹션 사이 간격을 줄이기 위한 상단 패딩
    private let listTopPadding: CGFloat = 4
    // 각 날짜 섹션의 상단 패딩(기존 16 → 더 촘촘하게)
    private let sectionTopPadding: CGFloat = 6
    // 세션 카드 목록과 '자주 선택된 키워드' 섹션 사이 추가 간격
    private let keywordCloudTopPadding: CGFloat = 24
    // '자주 선택된 키워드' 섹션 하단 패딩(스크롤 끝부분 여유 공간)
    private let keywordCloudBottomPadding: CGFloat = 24
    // 세션 카드 안에서 '세션 키워드 칩' 아래쪽 여백
    private let sessionKeywordsBottomPadding: CGFloat = 8
    // 세션 카드 모서리
    private let cardCorner: CGFloat = 20
    // 설명 문장과 summaryChip 사이 간격
    private let chipsTopPadding: CGFloat = 10
    // 세션 카드들 사이 간격
    private let sessionCardSpacing: CGFloat = 16
    // 세션 카드 내부 패딩(세로/가로 분리)
    private let sessionCardVerticalPadding: CGFloat = 14
    private let sessionCardHorizontalPadding: CGFloat = 20
    // '자주 선택된 키워드' 제목과 칩 모음 사이 간격
    private let keywordCloudTitleSpacing: CGFloat = 20
    // 챕터 제목과 bullets 사이 간격
    private let chapterTitleToBulletsSpacing: CGFloat = 6
    // 챕터와 구분선(Divider) 사이 간격
    private let chapterDividerSpacing: CGFloat = 10

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {

                // 상단 요약
                headerSummary
                    .padding(.top, headerExtraTopPadding)

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
                                .padding(.top, keywordCloudTopPadding)     // 세션 카드들과의 간격
                                .padding(.bottom, keywordCloudBottomPadding) // 섹션 아래 추가 여백
                        }
                        .padding(.top, listTopPadding) // 상단 여백 축소
                    }
                }
            }
            .padding(20)
            .background(Color.background1.ignoresSafeArea())
            //.navigationTitle("학습 기록")
        }
    }

    // MARK: - Header Summary

    private var headerSummary: some View {
        let totalSessions = learningLogStore.sessions.count
        let totalNotes = Set(learningLogStore.sessions.map { $0.noteTitle }).count

        return VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedText(korean: "나의 학습 기록", english: "My Learning History").text)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.text1)

            Text(LocalizedText(korean: "학습한 노트의 마지막 재생 위치, 핵심 내용, 선택된 키워드, Q&A 기록이 여기에 모입니다.", english: "Last playback positions, key content, selected keywords, and Q&A records from your studied notes are collected here.").text)
                .font(.captionText)
                .foregroundStyle(Color.text2)

            HStack(spacing: 16) {
                summaryChip(label: LocalizedText(korean: "총 학습 세션", english: "Total Sessions").text, value: "\(totalSessions)")
                summaryChip(label: LocalizedText(korean: "학습한 노트 수", english: "Studied Notes").text, value: "\(totalNotes)")
            }
            .padding(.top, chipsTopPadding) // ← 설명 문장과 칩 사이 간격
        }
    }

    private func summaryChip(label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.secondColor)
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

            Text(LocalizedText(korean: "아직 기록된 학습 세션이 없습니다.", english: "No learning sessions recorded yet.").text)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.text2)

            Text(LocalizedText(korean: "노트에서 영상을 학습하고 키워드를 선택하거나\nAI에게 질문하면 이곳에 자동으로 기록됩니다.", english: "Study videos in notes, select keywords, or ask AI questions,\nand they will be automatically recorded here.").text)
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

            // 세션 카드들 사이 간격을 키우기 위해 별도 VStack으로 감쌈
            VStack(spacing: sessionCardSpacing) {
                ForEach(sessions) { session in
                    sessionCard(for: session)
                }
            }
        }
        .padding(.top, sectionTopPadding) // 섹션 상단 여백 축소
    }

    // MARK: - Helpers: Chapters up to current

    private func chaptersUpToCurrent(for s: StudySession) -> [CachedChapter] {
        if let nid = s.noteIdentifier,
           let note = notes.first(where: { String(describing: $0.id) == nid }) {
            return note.cachedChaptersUpToCurrent
        }
        let titleMatches = notes.filter { $0.title == s.noteTitle }
        if !titleMatches.isEmpty {
            if let url = s.videoURL, !url.isEmpty {
                if let note = titleMatches.first(where: { ($0.videoURL ?? "") == url || ($0.thumbnailURL ?? "") == url }) {
                    return note.cachedChaptersUpToCurrent
                }
            }
            if let note = titleMatches.first {
                return note.cachedChaptersUpToCurrent
            }
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
                Text(LocalizedText(korean: "마지막 재생 위치", english: "Last Position").text + " \(String(format: "%d:%02d", mm, ss))")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.text3)
            }

            // 챕터별 요약(현재 시점까지)
            let chapters = chaptersUpToCurrent(for: s)
            if !chapters.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(chapters.enumerated()), id: \.offset) { idx, ch in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(LocalizedText(korean: "챕터", english: "Chapter").text + " \(idx + 1)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Color.text2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.background2)
                                    .cornerRadius(6)

                                Text(ch.title.isEmpty ? LocalizedText(korean: "제목", english: "Title").text : ch.title)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.text1)
                                    .lineLimit(1)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(Array(ch.bullets.prefix(4)), id: \.self) { line in
                                    Text(line)
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.text2)
                                        .lineLimit(2)
                                }
                            }
                            .padding(.top, chapterTitleToBulletsSpacing)

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
                            Divider()
                                .background(Color.borderColor.opacity(0.5))
                                .padding(.vertical, chapterDividerSpacing)
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
                .padding(.bottom, sessionKeywordsBottomPadding)
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
        .padding(.vertical, sessionCardVerticalPadding)
        .padding(.horizontal, sessionCardHorizontalPadding)
        // 머티리얼(반투명) 카드 배경
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: cardCorner)
                .stroke(Color.borderColor.opacity(0.4), lineWidth: 0.5)
        )
        //.shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
    }

    // 머티리얼 배경 뷰 (iOS 15+), 폴백 포함
    private var cardBackground: some View {
        Group {
            if #available(iOS 15.0, *) {
                Color.clear
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cardCorner))
            } else {
                RoundedRectangle(cornerRadius: cardCorner)
                    .fill(Color.white.opacity(0.9))
            }
        }
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
                VStack(alignment: .leading, spacing: keywordCloudTitleSpacing) {
                    Text(LocalizedText(korean: "자주 선택된 키워드", english: "Frequently Selected Keywords").text)
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

// MARK: - Flow layout without GeometryReader so it sizes inside ScrollView

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
        FlowLayout(spacing: spacing, alignment: alignment) {
            ForEach(Array(data), id: \.self) { element in
                content(element)
            }
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var alignment: HorizontalAlignment = .leading

    init(spacing: CGFloat = 8, alignment: HorizontalAlignment = .leading) {
        self.spacing = spacing
        self.alignment = alignment
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 1000
        let layout = computeLayout(maxWidth: maxWidth, subviews: subviews)
        return layout.totalSize
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        let layout = computeLayout(maxWidth: maxWidth, subviews: subviews)

        var indexInRow = 0
        var rowIndex = 0

        for (i, frame) in layout.frames.enumerated() {
            let xOffset: CGFloat
            switch alignment {
            case .center:
                xOffset = (bounds.width - layout.rowWidths[rowIndex]) / 2
            case .trailing:
                xOffset = bounds.width - layout.rowWidths[rowIndex]
            default:
                xOffset = 0
            }

            let origin = CGPoint(x: bounds.minX + frame.origin.x + xOffset,
                                 y: bounds.minY + frame.origin.y)
            subviews[i].place(at: origin,
                              proposal: ProposedViewSize(width: frame.size.width, height: frame.size.height))

            indexInRow += 1
            if indexInRow >= layout.itemsPerRow[rowIndex] {
                indexInRow = 0
                rowIndex += 1
            }
        }
    }

    private func computeLayout(maxWidth: CGFloat, subviews: Subviews)
    -> (frames: [CGRect], totalSize: CGSize, rowWidths: [CGFloat], itemsPerRow: [Int]) {
        let finiteWidth = max(0, maxWidth)

        var frames: [CGRect] = []
        var rowWidths: [CGFloat] = []
        var itemsPerRow: [Int] = []

        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0

        var currentRowWidth: CGFloat = 0
        var currentItemsInRow: Int = 0

        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: finiteWidth, height: nil))
            let itemWidth = min(size.width, finiteWidth)

            if x > 0 && x + itemWidth > finiteWidth {
                rowWidths.append(max(0, currentRowWidth - spacing))
                itemsPerRow.append(currentItemsInRow)

                x = 0
                y += lineHeight + spacing
                lineHeight = 0
                currentRowWidth = 0
                currentItemsInRow = 0
            }

            let rect = CGRect(origin: CGPoint(x: x, y: y), size: CGSize(width: itemWidth, height: size.height))
            frames.append(rect)

            x += itemWidth + spacing
            currentRowWidth += itemWidth + spacing
            currentItemsInRow += 1
            lineHeight = max(lineHeight, size.height)
        }

        if currentItemsInRow > 0 {
            rowWidths.append(max(0, currentRowWidth - spacing))
            itemsPerRow.append(currentItemsInRow)
        }

        let totalHeight = y + lineHeight
        let totalWidth = min(finiteWidth, rowWidths.max() ?? finiteWidth)

        return (frames, CGSize(width: totalWidth, height: totalHeight), rowWidths, itemsPerRow)
    }
}

#if DEBUG
#Preview(traits: .landscapeLeft) {
    StudyHistoryView()
        .environmentObject(LearningLogStore.previewStore())
}
#endif
