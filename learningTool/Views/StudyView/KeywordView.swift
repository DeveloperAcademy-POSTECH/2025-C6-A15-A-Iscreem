//
//  KeywordView.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI

struct KeywordView: View {
    @ObservedObject var analyzer: CaptionAnalyzer
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("이 강의에서 자주 언급되는 핵심 키워드들이 나열됩니다.")
                .font(.system(size: 14))
                .foregroundStyle(Color.text2)
                .padding(.horizontal, 16)
                .padding(.top, 12)
            
            /// 키워드 태그들 (가로 스크롤)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(analyzer.extractedKeywords, id: \.self) { keyword in
                        KeywordTag(keyword: keyword)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 12)
        }
        .background(Color.background1)
        .onAppear {
            if !analyzer.finalSummary.isEmpty && analyzer.extractedKeywords.isEmpty {
                analyzer.extractedKeywords = analyzer.extractKeywords()
            }
        }
    }
}

struct KeywordTag: View {
    let keyword: String
    
    var body: some View {
        Text(keyword)
            .font(.system(size: 15))
            .foregroundStyle(Color.text1)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.background2)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.borderColor, lineWidth: 1)
            )
    }
}

#Preview(traits: .landscapeLeft) {
    let analyzer = CaptionAnalyzer()
    analyzer.finalSummary = "트랜스포트 데이터링크 세션 물리 매체 응용 OSI 7계층 데이터신 표현"
    analyzer.extractedKeywords = analyzer.extractKeywords()
    return KeywordView(analyzer: analyzer)
        .frame(height: 180)
}
