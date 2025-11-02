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
        static let width: CGFloat = 116
        static let height: CGFloat = 36
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
        .frame(width: Layout.width, height: Layout.height)
        .background(.ultraThinMaterial, in: Capsule())               // 리퀴드 글래스 베이스
        .overlay(Capsule().stroke(Color.borderColor.opacity(0.5),    // 테두리
                                  lineWidth: 1))
        .onChange(of: selection) { newValue in
            onChange?(newValue)
        }
        .accessibilityLabel("View mode")
        .accessibilityValue(selection == .grid ? "Grid" : "List")
    }
}
