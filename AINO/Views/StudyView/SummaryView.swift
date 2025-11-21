//
//  SummaryView.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI

struct Summary: Identifiable, Hashable {
    let id: UUID
    let title: String
    let items: [String]
    let progress: String
}

struct SummaryView: View {
    @EnvironmentObject private var captionAnalyzer: CaptionAnalyzer
    @State private var currentPage: Int = 0
    
    @Binding var isExpanded: Bool
    
    private var isIPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }
    
    init(isExpanded: Binding<Bool> = .constant(true)) {
        self._isExpanded = isExpanded
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 헤더
            HStack(spacing: 12) {
                Text("AI가 구간별 요약을 제공합니다.")
                    .font(.bodyText)
                    .foregroundStyle(Color.text2)
                
                if isIPhone {
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.bodyText)
                            .foregroundStyle(Color.text3)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)

            Divider().background(Color.borderColor)

            // 스크롤 영역만 조건부 표시
            if !isIPhone || isExpanded {
                content
            }
        }
        .background(Color.background1)
        .onAppear {
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
        switch captionAnalyzer.summaryStatus {
        case .idle:
            progressView
        case .summarizing, .ready:
            if list.isEmpty {
                progressView
            } else {
                pagedChapters(list)
            }
        case .failed(let msg):
            VStack(alignment: .leading, spacing: 12) {
                Text("요약을 불러올 수 없습니다.")
                    .font(.system(size: isIPhone ? 18 : 16, weight: .semibold))
                    .foregroundStyle(Color.text1)
                Text(msg)
                    .font(.system(size: isIPhone ? 16 : 14))
                    .foregroundStyle(Color.text2)
            }
            .padding(16)
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    // MARK: - Progress
    private var progressView: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
            Text(statusLine)
                .font(.system(size: isIPhone ? 16 : 14))
                .foregroundStyle(Color.text3)
            if captionAnalyzer.summaryDebug.total > 0 {
                Text("\(captionAnalyzer.summaryDebug.processed) / \(captionAnalyzer.summaryDebug.total)")
                    .font(.system(size: isIPhone ? 14 : 12))
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

    // MARK: - Summaries
    private var summaries: [Summary] {
        let total = max(captionAnalyzer.chapters.count, 1)
        return captionAnalyzer.chapters.enumerated().map { (idx, ch) in
            let title = ch.title.isEmpty ? "제목 생성 중…" : ch.title
            let bullets = captionAnalyzer.chapterBullets[ch.id] ?? fallbackBullets(for: ch)
            return Summary(
                id: ch.id,
                title: title,
                items: Array(bullets.prefix(7)).map(stripBulletPrefix),
                progress: "\(idx + 1) / \(total)"
            )
        }
    }

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
                    VStack(spacing: isIPhone ? 12 : 8) {
                        SummaryDisclosureCard(
                            index: idx + 1,
                            summary: s
                        )
                        .padding(isIPhone ? 16 : 12)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(minHeight: isIPhone ? 500 : nil) // iPhone에서만 최소 높이 적용

            // 좌상단 페이지 인디케이터 + 처음으로 버튼
            HStack(spacing: 8) {
                // 처음으로 버튼 (첫 페이지가 아닐 때만 표시)
                if currentPage > 0 {
                    Button(action: {
                        withAnimation {
                            currentPage = 0
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(isIPhone ? .bodyTextSemibold : .system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.text1)
                            .frame(width: isIPhone ? 28 : 24, height: isIPhone ? 28 : 24)
                            .background(Color.background2)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                
                // 페이지 인디케이터
                Text("\(currentPage + 1) / \(max(list.count, 1))")
                    .font(isIPhone ? .bodyText : .system(size: 13))
                    .padding(.horizontal, isIPhone ? 10 : 8)
                    .padding(.vertical, isIPhone ? 6 : 5)
                    .background(Color.background2)
                    .cornerRadius(8)
                    .foregroundStyle(Color.text3)
            }
            .padding(isIPhone ? 12 : 10)
        }
    }

    private func fallbackBullets(for chapter: CaptionAnalyzer.Chapter) -> [String] {
        let s = chapter.gist
            .replacingOccurrences(of: "•", with: "")
        let parts = s.split(whereSeparator: { ".!?".contains($0) }).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        let top4 = Array(parts.prefix(7))
        return top4.isEmpty ? [s] : top4
    }
}

// MARK: - Card
private struct SummaryDisclosureCard: View {
    let index: Int
    let summary: Summary
    
    // 디바이스 타입 감지
    private var isIPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }
    
    // 디바이스별 폰트 크기
    private var titleFontSize: CGFloat {
        isIPhone ? 22 : 18
    }
    
    private var contentFontSize: CGFloat {
        isIPhone ? 18 : 15
    }
    
    private var cardPadding: CGFloat {
        isIPhone ? 16 : 12
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isIPhone ? 12 : 10) {
            // Header
            Text("#\(index). \(summary.title)")
                .font(.system(size: titleFontSize, weight: .semibold))
                .foregroundStyle(Color.text1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            
            // 항상 표시되는 내용
            VStack(alignment: .leading, spacing: isIPhone ? 8 : 6) {
                ForEach(Array(summary.items.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•").foregroundStyle(Color.text3)
                            .font(.system(size: contentFontSize))
                        Text(line)
                            .font(.system(size: contentFontSize))
                            .foregroundStyle(Color.text2)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.top, isIPhone ? 8 : 6)
        }
        .padding(cardPadding)
        .background(Color.background2)
        .cornerRadius(12)
    }
}

#Preview(traits: .landscapeLeft) {
    SummaryView()
        .environmentObject(CaptionAnalyzer())
}
