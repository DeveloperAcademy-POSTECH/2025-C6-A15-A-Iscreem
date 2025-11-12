//
//  KeywordView.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI

struct KeywordView: View {
    @ObservedObject var analyzer: CaptionAnalyzer
    @ObservedObject var studyViewModel: StudyViewModel
    @EnvironmentObject private var learningLogStore: LearningLogStore
    
    // 키워드 한 번에 하나만 클릭
    @State private var selectedKeyword: String? = nil
    
    private var keywordsToShow: [String] {
        // ✅ displayKeywords만 사용 (챕터별로 실시간 업데이트되는 키워드)
        // 챕터별 키워드가 추출될 때마다 즉시 누적되어 표시됨
        return analyzer.displayKeywords
    }
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 12) {
                // 🔵 제목 텍스트 (Liquid Glass 효과)
                Text("이 강의에서 자주 언급되는 핵심 키워드들이 나열됩니다.")
                    .font(.bodyText)
                    .foregroundStyle(Color.text2)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .background(
                        GeometryReader { geo in
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.15),
                                            Color.white.opacity(0.05)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width, height: 1)
                                .offset(y: geo.size.height + 4)
                        }
                    )
                
                ScrollView(.vertical) {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 120, maximum: 260), spacing: 16)],
                        spacing: 12
                    ) {
                        ForEach(keywordsToShow, id: \.self) { keyword in
                            // 🔵 키워드 컴포넌트 (Liquid Glass)
                            KeywordChip(
                                keyword: keyword,
                                isSelected: selectedKeyword == keyword,
                                onTap: {
                                    if selectedKeyword == keyword {
                                        // 같은 키워드를 다시 탭하면 선택만 해제 (로그는 유지)
                                        selectedKeyword = nil
                                    } else {
                                        // 새 키워드 선택
                                        selectedKeyword = keyword
                                        studyViewModel.selectKeyword(keyword)

                                        // 🔹 학습 로그: 키워드 사용 기록
                                        if let note = studyViewModel.currentNote {
                                            learningLogStore.recordKeywordUse(
                                                folderName: note.folder?.name,
                                                noteTitle: note.title,
                                                noteIdentifier: String(describing: note.id),
                                                videoURL: note.videoURL,
                                                keyword: keyword
                                            )
                                        }
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
                .frame(maxWidth: .infinity)
            }
            
            // 🔵 키워드가 없을 때 표시되는 중앙 메시지 (Liquid Glass)
            if keywordsToShow.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.text2))
                        .scaleEffect(1.2)
                    
                    Text("키워드 도출 중...")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(Color.text2)
                }
                .padding(32)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.background2)
    }
}

// MARK: - 🔵 Keyword Chip (Liquid Glass UI)
struct KeywordChip: View {
    let keyword: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(keyword)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isSelected ? Color.white : Color.text1)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(
                    ZStack {
                        if isSelected {
                            // 선택된 상태: 그라데이션 + Glass
                            LinearGradient(
                                colors: [
                                    Color.HoverColor,
                                    Color.HoverColor.opacity(0.85)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            Color.white.opacity(0.15)
                        } else {
                            // 기본 상태: Liquid Glass
                            Color.background1
                                .background(.ultraThinMaterial)
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            isSelected
                            ? Color.white.opacity(0.3)
                            : Color.white.opacity(0.15),
                            lineWidth: isSelected ? 1 : 0.5
                        )
                )
                .shadow(
                    color: isSelected
                    ? Color.secondColor.opacity(0.25)
                    : .black.opacity(0.06),
                    radius: isSelected ? 10 : 6,
                    x: 0,
                    y: isSelected ? 4 : 2
                )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Preview
#Preview {
    KeywordView(
        analyzer: CaptionAnalyzer(),
        studyViewModel: StudyViewModel()
    )
}
