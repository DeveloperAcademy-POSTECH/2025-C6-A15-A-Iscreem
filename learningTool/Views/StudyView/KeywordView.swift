//
//  KeywordView.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI

struct KeywordView: View {
    @ObservedObject var analyzer: CaptionAnalyzer
    
    // 키워드 한 번에 하나만 클릭
    @State private var selectedKeyword: String? = nil
    
    private var keywordsToShow: [String] {
        // 우선 챕터별 키워드 사용 (첫 번째 챕터 기준)
        if let firstChapterId = analyzer.chapters.first?.id,
           let chapterKeywords = analyzer.chapterKeywords[firstChapterId],
           !chapterKeywords.isEmpty {
            return Array(chapterKeywords.prefix(10))
        }
        // 챕터 키워드가 없으면 누적 키워드 사용
        else if !analyzer.accumulatedKeywords.isEmpty {
            return Array(analyzer.accumulatedKeywords.prefix(10))
        }
        // 그래도 없으면 최종 요약 기반 키워드
        else {
            return Array(analyzer.extractedKeywords.prefix(10))
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
