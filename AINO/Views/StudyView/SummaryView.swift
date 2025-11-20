//
//  SummaryView.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI

/// SwiftData 연계를 염두에 둔 요약 레코드 모델(메모리 상 구성)
struct Summary: Identifiable, Hashable {
    let id: UUID            // 챕터 UUID에 매핑
    let title: String       // 챕터 목차형 제목(한 문장)
    let items: [String]     // 6~7줄 요약 (한 문장씩)
    let progress: String    // "N / 총개수"
    let isGenerating: Bool  // ✅ 생성 중 여부 추가
}

struct SummaryView: View {
    @EnvironmentObject private var captionAnalyzer: CaptionAnalyzer
    @State private var currentPage: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 헤더
            Text("AI가 구간별 요약을 제공합니다.")
                .font(.system(size: 15))
                .foregroundStyle(Color.text2)
                .padding(16)

            Divider().background(Color.borderColor)

            content
        }
        .background(Color.background1)
        .onAppear {
            // 자막 준비 + 요약 미진행 시 수동 트리거
            if case .ready = captionAnalyzer.vttStatus,
               captionAnalyzer.summaryStatus == .idle,
               !captionAnalyzer.vttCues.isEmpty {
                Task { await captionAnalyzer.summarizeNow() }
            }
        }
    }

    // MARK: - Content Switch
    @ViewBuilder
    private var content: some View {
        let list = summaries
        let completedCount = list.filter { !$0.isGenerating }.count
        
        switch captionAnalyzer.summaryStatus {
        case .idle:
            progressView
        case .summarizing, .ready:
            if list.isEmpty {
                progressView
            } else if completedCount == 0 {
                // ✅ 아직 하나도 완성 안 됐으면 로딩만 표시
                progressView
            } else {
                // ✅ 하나라도 완성되면 실시간으로 표시 (생성 중인 것도 함께)
                pagedChapters(list)
            }
        case .failed(let msg):
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("요약을 불러올 수 없습니다.")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.text1)
                    Text(msg)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.text2)
                }
                .padding(16)
            }
        }
    }

    // MARK: - Progress
    private var progressView: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
            Text(statusLine)
                .font(.system(size: 14))
                .foregroundStyle(Color.text3)
            if captionAnalyzer.summaryDebug.total > 0 {
                Text("\(captionAnalyzer.summaryDebug.processed) / \(captionAnalyzer.summaryDebug.total)")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.text3)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var statusLine: String {
        switch captionAnalyzer.summaryStatus {
        case .idle: return "준비 중…"
        case .summarizing: return "구간별 요약 생성 중…"
        case .ready: return "완료"
        case .failed: return "실패"
        }
    }

    // MARK: - Summaries (DTO for SwiftData 연동을 위한 형태)
    private var summaries: [Summary] {
        let total = max(captionAnalyzer.chapters.count, 1)
        return captionAnalyzer.chapters.enumerated().map { (idx, ch) in
            let title = ch.title
            let bullets = captionAnalyzer.chapterBullets[ch.id] ?? fallbackBullets(for: ch)
            let isGenerating = title.contains("생성 중") || bullets.isEmpty
            
            return Summary(
                id: ch.id,
                title: title,
                items: Array(bullets.prefix(7)).map(stripBulletPrefix),
                progress: "\(idx + 1) / \(total)",
                isGenerating: isGenerating  // ✅ 생성 중 여부 추가
            )
        }
    }

    /// UI에서 불릿 기호를 제거해 '불릿 없이 최대 6~7줄'을 보이도록 한다.
    private func stripBulletPrefix(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixes = ["•", "-", "–", "—", "∙", "·", "●", "*"]
        if let p = prefixes.first(where: { t.hasPrefix($0) }) {
            t.removeFirst(p.count)
            t = t.trimmingCharacters(in: .whitespaces)
        }
        return t
    }

    private func pagedChapters(_ list: [Summary]) -> some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $currentPage) {
                ForEach(Array(list.enumerated()), id: \.offset) { (idx, s) in
                    ScrollView {
                        VStack(spacing: 12) {
                            Group {
                                if s.isGenerating {
                                    GeneratingChapterCard(index: idx + 1)
                                } else {
                                    SummaryDisclosureCard(
                                        index: idx + 1,
                                        summary: s
                                    )
                                }
                            }
                            .padding(16)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // 우하단 페이지 인디케이터
            Text("\(currentPage + 1) / \(max(list.count, 1))")
                .font(.system(size: 13))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.background2)
                .cornerRadius(8)
                .foregroundStyle(Color.text3)
                .padding(12)
        }
    }

    private func fallbackBullets(for chapter: CaptionAnalyzer.Chapter) -> [String] {
        // gist 기반 최대 6줄
        let s = chapter.gist
            .replacingOccurrences(of: "•", with: "")
        let parts = s.split(whereSeparator: { ".!?".contains($0) }).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        let bullets = Array(parts.prefix(6))
        return bullets.isEmpty ? [s] : bullets
    }
}

// MARK: - Generating Chapter Card
private struct GeneratingChapterCard: View {
    let index: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("#\(index). 요약 생성 중…")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.text2)
                Spacer()
            }
            
            VStack(spacing: 12) {
                ProgressView()
                Text("AI가 이 구간의 요약을 생성하고 있습니다")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.text3)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
        .padding(16)
        .background(Color.background2)
        .cornerRadius(12)
    }
}

// MARK: - Card
private struct SummaryDisclosureCard: View {
    let index: Int
    let summary: Summary
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row with custom chevron (no DisclosureGroup)
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            }) {
                HStack {
                    Text("#\(index). \(summary.title)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.text1)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.text3)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                }
                .contentShape(Rectangle()) // make the whole row tappable
            }
            .buttonStyle(.plain)

            // Collapsible content
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(summary.items.enumerated()), id: \.offset) { _, line in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•").foregroundStyle(Color.text3)
                            Text(line)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.text2)
                                .multilineTextAlignment(.leading)
                        }
                    }
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(Color.background2)
        .cornerRadius(12)
    }
}

#Preview(traits: .landscapeLeft) {
    SummaryView()
        .environmentObject(CaptionAnalyzer())
}
