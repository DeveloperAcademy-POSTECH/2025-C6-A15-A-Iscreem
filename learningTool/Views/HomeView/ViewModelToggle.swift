//
//  ViewModelToggle.swift
//  learningTool
//
//  Created by Yulim KIm on 10/28/25.
//

import SwiftUI


struct ViewModeToggle: View {
    @Binding var selection: HomeViewModel.ViewMode
    var onChange: ((HomeViewModel.ViewMode) -> Void)?

    private enum Layout {
        static let width: CGFloat = 116
        static let height: CGFloat = 36
    }
    
    @Namespace private var ns

    var body: some View {
        let items: [HomeViewModel.ViewMode] = [.grid, .list]

        ZStack {
            Capsule()
                .fill(Color.background2)
                .overlay(Capsule().stroke(Color.borderColor, lineWidth: 1))

            // Two equal slots + moving thumb
            HStack(spacing: 0) {
                ForEach(items, id: \.self) { mode in
                    ZStack {
                        if selection == mode {
                            RoundedRectangle(cornerRadius: (Layout.height - 8) / 2)
                                .fill(Color.white)
                                .matchedGeometryEffect(id: "thumb", in: ns)
                                .padding(4)
                        }
                        
                        Image(systemName: mode == .grid ? "square.grid.2x2" : "list.bullet")
                            .foregroundStyle(Color.text2)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selection = mode
                        }
                        onChange?(mode)
                    }
                }
            }
            .padding(2)
        }
        .frame(width: Layout.width, height: Layout.height)
    }
}
