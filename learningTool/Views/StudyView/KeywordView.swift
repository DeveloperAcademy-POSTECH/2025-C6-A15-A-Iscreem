//
//  KeywordView.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI

struct KeywordView: View {

    @ObservedObject var analyzer: CaptionAnalyzer

    let scaleFactor: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: ScaleCalculator.scaled(12, with: scaleFactor)) {
            Text("이 강의에서 자주 언급되는 핵심 키워드들이 나열됩니다.")
                .font(.system(size: ScaleCalculator.scaled(14, with: scaleFactor)))
                .foregroundStyle(Color.text2)
                .padding(.horizontal, ScaleCalculator.scaled(16, with: scaleFactor))
                .padding(.top, ScaleCalculator.scaled(12, with: scaleFactor))
            
            /// 키워드 태그들 (가로 스크롤)
            ScrollView(.horizontal, showsIndicators: false) {

                HStack(spacing: ScaleCalculator.scaled(12, with: scaleFactor)) {
                    ForEach(analyzer.extractedKeywords, id: \.self) { keyword in
                        KeywordTag(keyword: keyword, scaleFactor: scaleFactor)
                    }
                }
                .padding(.horizontal, ScaleCalculator.scaled(16, with: scaleFactor))
            }
            .padding(.bottom, ScaleCalculator.scaled(12, with: scaleFactor))
        }
        .frame(
            width: ScaleCalculator.scaled(800, with: scaleFactor),
            height: ScaleCalculator.scaled(214, with: scaleFactor)
        )
        .background(Color.background2)
        .cornerRadius(ScaleCalculator.scaled(12, with: scaleFactor))
        .onAppear {
            if !analyzer.finalSummary.isEmpty && analyzer.extractedKeywords.isEmpty {
                analyzer.extractedKeywords = analyzer.extractKeywords()
            }
        }
    }
}

struct KeywordTag: View {
    let keyword: String
    var isSelected: Bool = false
    let scaleFactor: CGFloat
    
    var body: some View {
        Text(keyword)
            .font(.system(size: ScaleCalculator.scaled(15, with: scaleFactor), weight: isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? .white : Color.text1)
            .padding(.horizontal, ScaleCalculator.scaled(16, with: scaleFactor))
            .padding(.vertical, ScaleCalculator.scaled(10, with: scaleFactor))
            .background(
                isSelected
                    ? LinearGradient(
                        colors: [Color.orange, Color.orange.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                      )
                    : LinearGradient(
                        colors: [Color.background2, Color.background2],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                      )
            )
            .cornerRadius(ScaleCalculator.scaled(20, with: scaleFactor))
            .overlay(
                RoundedRectangle(cornerRadius: ScaleCalculator.scaled(20, with: scaleFactor))
                    .stroke(isSelected ? Color.orange : Color.borderColor, lineWidth: isSelected ? 2 : 1)
            )
            .shadow(
                color: isSelected ? Color.orange.opacity(0.3) : Color.clear,
                radius: isSelected ? 8 : 0,
                x: 0,
                y: isSelected ? 2 : 0
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
