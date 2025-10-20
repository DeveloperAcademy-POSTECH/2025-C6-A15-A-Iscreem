//
//  HomeView.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showCreateNote = false
    
    /// 노트 선택 콜백
    let onNoteSelected: ((Note) -> Void)?
    /// 노트 생성 콜백
    let onNoteCreated: ((Note) -> Void)?
    
    /// 적응형 그리드 레이아웃 (최소 200pt 너비의 카드)
    private let columns = [
        GridItem(.adaptive(minimum: 200, maximum: 250), spacing: 16),
    ]
    
    init(
        onNoteSelected: ((Note) -> Void)? = nil,
        onNoteCreated: ((Note) -> Void)? = nil
    ) {
        self.onNoteSelected = onNoteSelected
        self.onNoteCreated = onNoteCreated
    }
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(
                    min: 280,
                    ideal: 320,
                    max: 400
                )
        } detail: {
            VStack(spacing: 0) {
                /// 헤더 영역
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("{$app_name}")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(Color.text1)
                        
                        Text("최근 열어본 항목")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(Color.text2)
                    }
                    
                    Spacer()
                    
                    /// 검색바 및 뷰 옵션
                    HStack(spacing: 12) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(Color.text3)
                            TextField(
                                "노트 검색",
                                text: $viewModel.searchText,
                                axis: .horizontal
                            )
                            .font(.system(size: 16))
                            .lineLimit(1)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(minWidth: 200, maxWidth: 300)
                        .background(Color.background2)
                        .cornerRadius(8)
                        
                        Button(action: {
                            viewModel.viewModeButtonTapped(.compact)
                        }) {
                            Image(systemName: "line.3.horizontal")
                                .foregroundStyle(Color.text3)
                        }
                        
                        Button(action: {
                            viewModel.viewModeButtonTapped(.grid)
                        }) {
                            Image(systemName: "square.grid.2x2")
                                .foregroundStyle(Color.text3)
                        }
                        
                        Button(action: {
                            viewModel.viewModeButtonTapped(.list)
                        }) {
                            Image(systemName: "list.bullet")
                                .foregroundStyle(Color.text3)
                        }
                    }
                }
                .padding()
                
                Divider()
                    .background(Color.borderColor)
                
                /// 노트 그리드
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.notes) { note in
                            NoteComponent(note: note)
                                .onTapGesture {
                                    onNoteSelected?(note)
                                }
                        }
                    }
                    .padding()
                }
                
                /// 플로팅 추가 버튼
                .overlay(alignment: .bottomTrailing) {
                    Button(action: {
                        viewModel.addButtonTapped()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showCreateNote = true
                        }
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 22))
                            .foregroundStyle(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.secondColor)
                            .clipShape(Circle())
                            .shadow(
                                color: Color.secondColor.opacity(0.4),
                                radius: 8,
                                x: 0,
                                y: 4
                            )
                    }
                    .padding(32)
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .keyboardOverlay()
        .overlay {
            if showCreateNote {
                GeometryReader { geometry in
                    ZStack {
                        /// 반투명 배경
                        Color.black.opacity(0.5)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showCreateNote = false
                                }
                            }
                        
                        /// 입력 창
                        CreateNoteView { note in
                            onNoteCreated?(note)
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showCreateNote = false
                            }
                        }
                        .frame(
                            width: min(500, geometry.size.width * 0.6),
                            height: min(380, geometry.size.height * 0.5)
                        )
                        .background(Color.background1)
                        .cornerRadius(20)
                        .shadow(
                            color: Color.black.opacity(0.3),
                            radius: 20,
                            x: 0,
                            y: 10
                        )
                    }
                    .transition(
                        .opacity.animation(.easeInOut(duration: 0.2))
                    )
                }
            }
        }
    }
}

#Preview(traits: .landscapeLeft) {
    HomeView()
}