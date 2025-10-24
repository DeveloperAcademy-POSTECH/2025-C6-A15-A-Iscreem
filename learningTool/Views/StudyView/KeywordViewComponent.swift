//
//  KeywordViewComponent.swift
//  learningtool
//
//  Created by Mumin on 10/24/25.
//

import SwiftUI

/// 키워드 태그 컴포넌트 (140 x 32 알약 형태)
struct KeywordViewComponent: View {
    let keyword: String
    var isSelected: Bool = false
    
    var body: some View {
        Text(keyword)
            .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? .white : Color.text1)
            .multilineTextAlignment(.center)
            .frame(width: 140, height: 32)
            .background(
                isSelected ? Color.accentColor : Color.background2
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.borderColor, lineWidth: 1)
            )
    }
}

#Preview(traits: .landscapeLeft){
    VStack(spacing: 16) {
        KeywordViewComponent(keyword: "트랜스포트", isSelected: false)
        KeywordViewComponent(keyword: "트랜스포트", isSelected: true)
    }
    .padding()
}

