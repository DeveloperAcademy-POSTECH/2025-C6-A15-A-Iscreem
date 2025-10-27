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
    @Binding var isSelected: Bool  // 클릭/호버 상태
    @State private var isHovering: Bool = false  // 호버 상태
    
    var body: some View {
        Text(keyword)
            .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected || isHovering ? .white : Color.text1)
            .multilineTextAlignment(.center)
            .frame(width: 140, height: 32)
            .background(
                isSelected ? Color.accentColor : (isHovering ? Color.HoverColor : Color.background1)
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.borderColor, lineWidth: 1)
            )
            // 애플펜슬 호버 이벤트
            .onHover { hovering in
                self.isHovering = hovering
            }
            // 클릭 이벤트
            .onTapGesture {
                isSelected.toggle()
            }
    }
}
