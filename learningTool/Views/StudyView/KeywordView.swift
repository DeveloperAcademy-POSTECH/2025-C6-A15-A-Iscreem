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
    
    // 키워드 한 번에 하나만 클릭
    @State private var selectedKeyword: String? = nil
    
    private var keywordsToShow: [String] {
        // 🔹 displayKeywords 우선
        if !analyzer.displayKeywords.isEmpty {
            return analyzer.displayKeywords
        }
        // 챕터별 키워드 fallback
        else if let firstChapterId = analyzer.chapters.first?.id,
                let chapterKeywords = analyzer.chapterKeywords[firstChapterId],
                !chapterKeywords.isEmpty {
            return chapterKeywords
        }
        // accumulatedKeywords fallback
        else if !analyzer.accumulatedKeywords.isEmpty {
            return analyzer.accumulatedKeywords
        }
        // 최종 요약 기반 fallback
        else {
            return analyzer.extractedKeywords
        }
    }
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 12) {
                // 제목 텍스트
                Text("이 강의에서 자주 언급되는 핵심 키워드들이 나열됩니다.")
                    .font(.bodyText)
                    .foregroundStyle(Color.text2)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    // GeometryReader로 텍스트 너비 측정
                    .background(
                        GeometryReader { geo in
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: geo.size.width, height: 1)
                                .offset(y: geo.size.height + 4) // 텍스트 아래에 살짝 떨어뜨림
                        }
                    )

                ScrollView(.vertical) {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 120, maximum: 260), spacing: 16)],
                        spacing: 12
                    ) {
                        ForEach(keywordsToShow, id: \.self) { keyword in
                            KeywordViewComponent(
                                keyword: keyword,
                                isSelected: Binding(
                                    get: { selectedKeyword == keyword },
                                    set: { newValue in
                                        if newValue {
                                            selectedKeyword = keyword
                                            studyViewModel.selectKeyword(keyword)
                                        } else if selectedKeyword == keyword {
                                            selectedKeyword = nil
                                        }
                                    }
                                )
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
                .frame(maxWidth: .infinity)
            }

            // 키워드가 없을 때 표시되는 중앙 메시지
            if keywordsToShow.isEmpty {
                Text("키워드 도출 중...")
                    .font(.title3.italic())
                    .foregroundStyle(Color.gray.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.background2.opacity(0.5))
            }
        }
        .background(Color.background2)
    }
}
