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
                .font(.bodyText)
                .foregroundStyle(Color.text2)
                .padding(.horizontal, 16)
                .padding(.top, 12)
            
            /// 키워드 태그들 (고정 크기, 5열, 세로 스크롤)
            ScrollView(.vertical) {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(140), spacing: 18), count: 5),
                    spacing: 12
                ) {
                    ForEach(analyzer.displayKeywords, id: \.self) { keyword in
                        KeywordTag(keyword: keyword)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .background(Color.background2)
    }
}

struct KeywordTag: View {
    let keyword: String
    var isSelected: Bool = false
    
    var body: some View {
        Text(keyword)
            .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? .white : Color.text1)
            .frame(width: 140, height: 32, alignment: .center)
            .lineLimit(1)
            .truncationMode(.tail)
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
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
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
