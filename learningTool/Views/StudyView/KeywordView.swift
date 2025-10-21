//
//  KeywordView.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI

struct KeywordView: View {
    /// 샘플 키워드 데이터
    private let keywords = [
        "트랜스포트",
        "데이터링크",
        "세션",
        "물리 매체",
        "응용",
        "OSI",
        "7계층",
        "물리 매체",
        "데이터신",
        "표현",
    ]
    
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
                    ForEach(keywords, id: \.self) { keyword in
                        KeywordTag(keyword: keyword)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 12)
        }
        .background(Color.background1)
    }
}

struct KeywordTag: View {
    let keyword: String
    var isSelected: Bool = false
    
    var body: some View {
        Text(keyword)
            .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? .white : Color.text1)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
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

#Preview(traits: .landscapeLeft) {
    KeywordView()
        .frame(height: 180)
}