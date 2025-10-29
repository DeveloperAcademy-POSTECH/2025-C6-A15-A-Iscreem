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
        VStack(alignment: .leading, spacing: 12) {
            Text("이 강의에서 자주 언급되는 핵심 키워드들이 나열됩니다.")
                .font(.bodyText)
                .foregroundStyle(Color.text2)
                .padding(.horizontal, 16)
                .padding(.top, 12)
            
            /// 키워드 태그들 (고정 크기, 5열, 세로 스크롤)
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
                                        // 선택: 해당 키워드만 선택 상태로
                                        selectedKeyword = keyword
                                        // StudyViewModel에 키워드 선택 알림 (질문창에 자동 입력 + 추천 질문 생성)
                                        studyViewModel.selectKeyword(keyword)
                                    } else {
                                        // 해제: 현재 선택된 게 이 키워드면 nil로
                                        if selectedKeyword == keyword {
                                            selectedKeyword = nil
                                        }
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
        .background(Color.background2)
    }
}
