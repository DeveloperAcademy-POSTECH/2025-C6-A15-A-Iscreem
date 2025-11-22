//
//  ViewModeToggle.swift
//  learningTool
//
//  Created by Yulim Kim on 10/28/25.
//

import SwiftUI

struct ViewModeToggle: View {
    @Binding var selection: HomeViewModel.ViewMode
    var onChange: ((HomeViewModel.ViewMode) -> Void)?
    
    private enum Layout {
        // 기준 폭(이상적), 단 소형 기기에서는 더 작게, 대형 기기에서는 약간 더 넓게 허용
        static let minWidth: CGFloat = 96
        static let idealWidth: CGFloat = 116
        static let maxWidth: CGFloat = 160
        // 높이는 시스템 기본을 따르되, 너무 커지지 않도록 얕게 지정 가능
        static let height: CGFloat = 32
        
        // 반응형 아이콘 크기 계산
        static func iconSize(for height: CGFloat) -> CGFloat {
            return height * 0.55  // 높이의 55% 정도
        }
    }
    
    var body: some View {
        Picker("", selection: $selection) {
            Label("Grid", systemImage: "square.grid.2x2")
                .tag(HomeViewModel.ViewMode.grid)
            Label("List", systemImage: "list.bullet")
                .tag(HomeViewModel.ViewMode.list)
        }
        .pickerStyle(.segmented)
        .labelStyle(.iconOnly)          // 아이콘만 표시
        .labelsHidden()                 // 접근성 라벨만 유지, 시각 라벨 숨김
        .tint(Color.text1)              // 선택된 세그먼트 색상
        .font(.system(size: Layout.iconSize(for: Layout.height), weight: .medium))  // ✅ 반응형 아이콘 크기
        // 고정폭/고정높이 제거 → 기기/컨테이너 폭에 반응
        .frame(minWidth: Layout.minWidth, idealWidth: Layout.idealWidth, maxWidth: Layout.maxWidth)
        .frame(height: Layout.height)
        .background(.ultraThinMaterial, in: Capsule())               // 리퀴드 글래스 베이스
        .overlay(Capsule().stroke(Color.borderColor.opacity(0.5),    // 테두리
                                  lineWidth: 1))
        .onChange(of: selection) { _, newValue in
            onChange?(newValue)
        }
        .accessibilityLabel("View mode")
        .accessibilityValue(selection == .grid ? "Grid" : "List")
    }
}
