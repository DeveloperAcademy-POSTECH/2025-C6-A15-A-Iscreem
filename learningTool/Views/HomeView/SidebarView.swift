//
//  SidebarView.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI

struct SidebarView: View {
    @StateObject private var viewModel = SidebarViewModel()
    
    var body: some View {
        List {
            /// 상단 폴더 섹션
            Section {
                HStack(spacing: 16) {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(Color.secondColor)
                        .font(.system(size: 22))
                    
                    Image(systemName: "folder.fill")
                        .foregroundStyle(Color.secondColor)
                        .font(.system(size: 22))
                    
                    Image(systemName: "folder.fill")
                        .foregroundStyle(Color.secondColor)
                        .font(.system(size: 22))
                    
                    Spacer()
                    
                    Button(action: { viewModel.sortButtonTapped() }) {
                        Image(systemName: "arrow.up.arrow.down")
                            .foregroundStyle(Color.text3)
                            .imageScale(.medium)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
                .listRowBackground(Color.clear)
                .listRowInsets(
                    EdgeInsets(
                        top: 0,
                        leading: 16,
                        bottom: 0,
                        trailing: 16
                    )
                )
            }
            
            /// 전체 보기
            Section {
                Button(action: { viewModel.allViewTapped() }) {
                    Label("전체 보기", systemImage: "square.grid.2x2")
                        .font(.system(size: 15))
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
            }
            
            /// 폴더 목록
            Section {
                ForEach(viewModel.folders) { folder in
                    Button(action: { viewModel.folderTapped(folder) }) {
                        Label(folder.name, systemImage: "folder")
                            .font(.system(size: 15))
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                }
            } header: {
                Text("폴더")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.text3)
                    .textCase(nil)
            }
            
            /// 최근 열어본 항목
            Section {
                Button(action: { viewModel.recentItemsTapped() }) {
                    Label("최근 열어본 항목", systemImage: "clock.fill")
                        .font(.system(size: 15))
                }
                .buttonStyle(.plain)
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondColor.opacity(0.15))
                )
            }
            
            /// 하단 메뉴
            Section {
                Button(action: { viewModel.helpTapped() }) {
                    Label("도움말", systemImage: "questionmark.circle")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.text1)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                
                Button(action: { viewModel.settingsTapped() }) {
                    Label("설정", systemImage: "gearshape")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.text1)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                
                Button(action: { viewModel.trashTapped() }) {
                    Label("휴지통", systemImage: "trash")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.errorColor)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(.ultraThinMaterial)
    }
}

#Preview(traits: .landscapeLeft) {
    NavigationSplitView {
        SidebarView()
            .navigationSplitViewColumnWidth(
                min: 280,
                ideal: 320,
                max: 400
            )
    } detail: {
        Color.background1
            .ignoresSafeArea()
    }
    .navigationSplitViewStyle(.balanced)
}