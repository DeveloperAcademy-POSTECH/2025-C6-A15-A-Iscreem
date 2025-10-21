//
//  SidebarView.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI

struct SidebarView: View {
    @StateObject private var viewModel = SidebarViewModel()
    @State private var showSortMenu = false
    
    // 256:762 비율 유지 (사이드바:메인 컨텐츠)
    private let sidebarRatio: CGFloat = 256.0 / (256.0 + 762.0) // ≈ 0.2514
    
    var body: some View {
        VStack(spacing: 0) {
            /// 상단 폴더 섹션
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    /// 폴더 추가 아이콘
                    Button(action: { viewModel.addFolderTapped() }) {
                        ZStack {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(Color.secondColor)
                                .font(.system(size: 20))
                            ZStack {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 12, height: 12)
                                Image(systemName: "plus")
                                    .foregroundStyle(Color.secondColor)
                                    .font(.system(size: 8, weight: .bold))
                            }
                            .offset(x: 8, y: -6)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    /// 폴더 삭제 아이콘
                    Button(action: { viewModel.deleteFolderTapped() }) {
                        ZStack {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(Color.secondColor)
                                .font(.system(size: 20))
                            ZStack {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 12, height: 12)
                                Image(systemName: "minus")
                                    .foregroundStyle(Color.secondColor)
                                    .font(.system(size: 8, weight: .bold))
                            }
                            .offset(x: 8, y: -6)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    /// 폴더 설정 아이콘
                    Button(action: { viewModel.editFolderTapped() }) {
                        ZStack {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(Color.secondColor)
                                .font(.system(size: 20))
                            ZStack {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 12, height: 12)
                                Image(systemName: "gearshape.fill")
                                    .foregroundStyle(Color.secondColor)
                                    .font(.system(size: 7))
                            }
                            .offset(x: 8, y: -6)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    /// 정렬 버튼
                    Button(action: { showSortMenu.toggle() }) {
                        Image(systemName: "arrow.up.arrow.down")
                            .foregroundStyle(Color.secondColor)
                            .font(.system(size: 20))
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showSortMenu, arrowEdge: .top) {
                        VStack(spacing: 0) {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Button(action: {
                                    viewModel.selectSortOption(option)
                                    showSortMenu = false
                                }) {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .stroke(viewModel.currentSortOption == option ? Color.text1 : Color.text3, lineWidth: 1.5)
                                                .frame(width: 18, height: 18)
                                            
                                            if viewModel.currentSortOption == option {
                                                Circle()
                                                    .fill(Color.text1)
                                                    .frame(width: 10, height: 10)
                                            }
                                            
                                            // 아이콘 추가
                                            if option == .nameAscending || option == .nameDescending {
                                                Text("A")
                                                    .foregroundStyle(viewModel.currentSortOption == option ? Color.text1 : Color.text3)
                                                    .font(.system(size: 10, weight: .semibold))
                                            } else {
                                                Image(systemName: "clock")
                                                    .foregroundStyle(viewModel.currentSortOption == option ? Color.text1 : Color.text3)
                                                    .font(.system(size: 10))
                                            }
                                        }
                                        
                                        Text(option.rawValue)
                                            .foregroundStyle(viewModel.currentSortOption == option ? Color.text1 : Color.text3)
                                            .font(.buttonText)
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                
                                if option != SortOption.allCases.last {
                                    Divider()
                                        .background(Color.borderColor)
                                        .padding(.horizontal, 16)
                                }
                            }
                        }
                        .frame(width: 204, height: 145)
                        .background(Color.background1)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.borderColor, lineWidth: 1)
                        )
                        .presentationCompactAdaptation(.popover)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)
                .padding(.bottom, 16)
                
                /// 구분선
                HStack {
                    Rectangle()
                        .fill(Color.borderColor)
                        .frame(height: 1)
                }
                .padding(.horizontal, 20)
            }
            .background(Color.clear)
            
            /// 중간 스크롤 가능 영역
            List {
            
            /// 전체 보기
            Section {
                Button(action: { viewModel.allViewTapped() }) {
                    HStack(spacing: 12) {
                        Image(systemName: "square.grid.2x2.fill")
                            .foregroundStyle(Color.text2)
                            .font(.system(size: 20))
                        
                        Text("전체 보기")
                            .foregroundStyle(Color.text2)
                            .font(.buttonText)
                        
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
            }
            
            /// 폴더 목록
            Section {
                ForEach(viewModel.folders) { folder in
                    Button(action: { viewModel.folderTapped(folder) }) {
                        HStack(spacing: 12) {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(Color.text2)
                                .font(.system(size: 20))
                            
                            Text(folder.name)
                                .foregroundStyle(Color.text2)
                                .font(.buttonText)
                            
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 6, leading: 32, bottom: 6, trailing: 20))
                }
            }
            
            /// 최근 열어본 항목
            Section {
                Button(action: { viewModel.recentItemsTapped() }) {
                    HStack(spacing: 12) {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(Color.secondColor)
                            .font(.system(size: 20))
                        
                        Text("최근 열어본 항목")
                            .foregroundStyle(Color.secondColor)
                            .font(.buttonText)
                        
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
            }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            
            /// 하단 구분선
            HStack {
                Rectangle()
                    .fill(Color.borderColor)
                    .frame(height: 1)
            }
            .padding(.horizontal, 20)
            
            /// 하단 고정 메뉴
            VStack(spacing: 0) {
                Button(action: { viewModel.helpTapped() }) {
                    HStack(spacing: 12) {
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundStyle(Color.text2)
                            .font(.system(size: 20))
                        
                        Text("도움말")
                            .foregroundStyle(Color.text2)
                            .font(.buttonText)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                
                Button(action: { viewModel.settingsTapped() }) {
                    HStack(spacing: 12) {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(Color.text2)
                            .font(.system(size: 20))
                        
                        Text("설정")
                            .foregroundStyle(Color.text2)
                            .font(.buttonText)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                
                Button(action: { viewModel.trashTapped() }) {
                    HStack(spacing: 12) {
                        Image(systemName: "trash")
                            .foregroundStyle(Color.errorColor)
                            .font(.system(size: 20))
                        
                        Text("휴지통")
                            .foregroundStyle(Color.errorColor)
                            .font(.buttonText)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 30)
        }
        .background(Color.background2)
    }
}

#Preview(traits: .landscapeLeft) {
    GeometryReader { geometry in
        let sidebarWidth = geometry.size.width * (256.0 / (256.0 + 762.0))
        
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(
                    min: sidebarWidth * 0.9,
                    ideal: sidebarWidth,
                    max: sidebarWidth * 1.1
                )
        } detail: {
            Color.background1
                .ignoresSafeArea()
        }
        .navigationSplitViewStyle(.balanced)
    }
}
