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
    @EnvironmentObject private var learningLogStore: LearningLogStore
    
    @State private var selectedKeyword: String? = nil
    
    private var keywordsToShow: [String] {
        return analyzer.displayKeywords
    }
    
    // MARK: - Body
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                // 헤더
                Text("이 강의에서 자주 언급되는 핵심 키워드들이 나열됩니다.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.text2)
                    .padding(16)
                
                Divider().background(Color.borderColor)
                
                // 스크롤뷰
                keywordScrollView
            }
            
            // 키워드가 없을 때 표시되는 중앙 메시지
            if keywordsToShow.isEmpty {
                emptyStateView
            }
        }
        .background(Color.background2)
    }
    
    // MARK: - Keyword ScrollView
    private var keywordScrollView: some View {
        ScrollView(.vertical) {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 120, maximum: 260), spacing: 16)],
                spacing: 12
            ) {
                ForEach(keywordsToShow, id: \.self) { keyword in
                    KeywordChip(
                        keyword: keyword,
                        isSelected: selectedKeyword == keyword,
                        onTap: {
                            if selectedKeyword == keyword {
                                selectedKeyword = nil
                            } else {
                                selectedKeyword = keyword
                                studyViewModel.selectKeyword(keyword)

                                if let note = studyViewModel.currentNote {
                                    learningLogStore.recordKeywordUse(
                                        folderName: note.folder?.name,
                                        noteTitle: note.title,
                                        noteIdentifier: String(describing: note.id),
                                        videoURL: note.videoURL,
                                        keyword: keyword
                                    )
                                }
                            }
                        }
                    )
                }
            }
            .padding(.top, 10)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
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

// MARK: - Keyword Chip
struct KeywordChip: View {
    let keyword: String
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: onTap) {
            Text(keyword)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isSelected ? Color.white : Color.text1)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(
                    ZStack {
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
                            Color.background1
                                .background(.ultraThinMaterial)
                            
                            if isHovering {
                                Color.HoverColor.opacity(0.7)
                            }
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            isSelected
                            ? Color.white.opacity(0.3)
                            : (isHovering ? Color.HoverColor.opacity(0.8) : Color.white.opacity(0.15)),
                            lineWidth: isSelected ? 1 : 0.5
                        )
                )
                .shadow(
                    color: isSelected
                    ? Color.secondColor.opacity(0.25)
                    : (isHovering ? Color.HoverColor.opacity(0.3) : .black.opacity(0.06)),
                    radius: isSelected ? 10 : (isHovering ? 8 : 6),
                    x: 0,
                    y: isSelected ? 4 : (isHovering ? 3 : 2)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
    }
}

// MARK: - Preview
#Preview {
    KeywordView(
        analyzer: CaptionAnalyzer(),
        studyViewModel: StudyViewModel()
    )
}
