//
//  KeywordView.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI

struct KeywordView: View {
    @ObservedObject var analyzer: CaptionAnalyzer
    @ObservedObject var studyViewModel: StudyViewModel
    
    // 키워드 한 번에 하나만 클릭
    @State private var selectedKeyword: String? = nil
    
    @State private var stableKeywords: [String] = []
    
    private var keywordsToShow: [String] {
        stableKeywords
    }

    // 중복 제거(대소문자 무시) + 공백 제거
    private func dedup(_ arr: [String]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for raw in arr {
            let k = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !k.isEmpty else { continue }
            let key = k.lowercased()
            if seen.insert(key).inserted { out.append(k) }
        }
        return out
    }
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 12) {
                // 🔵 제목 텍스트 (Liquid Glass 효과)
                Text("이 강의에서 자주 언급되는 핵심 키워드들이 나열됩니다.")
                    .font(.bodyText)
                    .foregroundStyle(Color.text2)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .background(
                        GeometryReader { geo in
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.15),
                                            Color.white.opacity(0.05)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width, height: 1)
                                .offset(y: geo.size.height + 4)
                        }
                    )
                
                ScrollView(.vertical) {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 120, maximum: 260), spacing: 16)],
                        spacing: 12
                    ) {
                        ForEach(Array(keywordsToShow.enumerated()), id: \.offset) { _, keyword in
                            // 🔵 키워드 컴포넌트 (Liquid Glass)
                            KeywordChip(
                                keyword: keyword,
                                isSelected: selectedKeyword == keyword,
                                onTap: {
                                    if selectedKeyword == keyword {
                                        selectedKeyword = nil
                                    } else {
                                        selectedKeyword = keyword
                                        // 선택 직후 리스트 갱신 프레임과의 충돌 방지
                                        DispatchQueue.main.async {
                                            studyViewModel.selectKeyword(keyword)
                                        }
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
                .frame(maxWidth: .infinity)
            }
            
            // 🔵 키워드가 없을 때 표시되는 중앙 메시지 (Liquid Glass)
            if keywordsToShow.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.text2))
                        .scaleEffect(1.2)
                    
                    Text("키워드 도출 중...")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(Color.text2)
                }
                .padding(32)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.background2)
        .onAppear {
            // 초기 표시용 안정화
            self.stableKeywords = dedup(analyzer.displayKeywords)
        }
        .onChange(of: analyzer.displayKeywords) { _, newValue in
            // 비동기 갱신 동안 중복/순서 변동으로 인한 충돌 방지
            self.stableKeywords = dedup(newValue)
        }
    }
}

// MARK: - 🔵 Keyword Chip (Liquid Glass UI)
struct KeywordChip: View {
    let keyword: String
    let isSelected: Bool
    let onTap: () -> Void

    @State private var isHovering: Bool = false
    @State private var isPressed: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let corner: CGFloat = 20
        let baseStroke: CGFloat = isSelected ? 1.0 : 0.5
        let textColor: Color = (isSelected || isHovering) ? .white : .text1
        let baseBgOpacity: Double = colorScheme == .dark ? 0.20 : 0.60
        let shadowOpacity: Double = (isSelected || isHovering || isPressed) ? 0.25 : 0.06

        return Button(action: onTap) {
            Text(keyword)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(textColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(minWidth: 120, maxWidth: .infinity, minHeight: 32)
                .background(
                    ZStack {
                        // Selected gradient underlay
                        if isSelected {
                            LinearGradient(
                                colors: [
                                    Color.HoverColor,
                                    Color.HoverColor.opacity(0.85)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            Color.white.opacity(0.15)
                        } else {
                            // Base tint under material for glass impression
                            RoundedRectangle(cornerRadius: corner)
                                .fill(Color.background1.opacity(baseBgOpacity))
                        }

                        // Official glass-like material layer
                        RoundedRectangle(cornerRadius: corner)
                            .fill(.ultraThinMaterial)

                        // Subtle gloss highlight (top-left)
                        RoundedRectangle(cornerRadius: corner)
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.white.opacity(isHovering || isPressed ? 0.35 : 0.18),
                                        .clear
                                    ],
                                    center: .topLeading,
                                    startRadius: 0,
                                    endRadius: 140
                                )
                            )
                            .blendMode(.plusLighter)

                        // Hover rim highlight
                        if isHovering || isPressed {
                            RoundedRectangle(cornerRadius: corner)
                                .stroke(Color.white.opacity(0.25), lineWidth: 0.8)
                                .blendMode(.overlay)
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: corner))
                .overlay(
                    RoundedRectangle(cornerRadius: corner)
                        .strokeBorder(
                            isSelected
                            ? Color.white.opacity(0.3)
                            : Color.white.opacity(0.15),
                            lineWidth: baseStroke
                        )
                )
                .shadow(
                    color: (isSelected ? Color.secondColor : .black).opacity(shadowOpacity),
                    radius: isSelected ? 10 : 6,
                    x: 0,
                    y: isSelected ? 4 : 2
                )
                .scaleEffect(isHovering || isPressed ? 1.02 : 1.0)
                .contentShape(RoundedRectangle(cornerRadius: corner))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            self.isHovering = hovering
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed { isPressed = true }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
        .hoverEffect(.highlight)
        .animation(.easeInOut(duration: 0.18), value: isHovering)
        .animation(.easeInOut(duration: 0.18), value: isPressed)
        .animation(.easeInOut(duration: 0.18), value: isSelected)
    }
}

// MARK: - Preview
#Preview {
    KeywordView(
        analyzer: CaptionAnalyzer(),
        studyViewModel: StudyViewModel()
    )
}
