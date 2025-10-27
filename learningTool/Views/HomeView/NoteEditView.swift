//
//  NoteEditView.swift
//  learningtool
//
//  Created by Mumin on 10/24/25.
//

import SwiftUI

struct NoteEditView: View {
    @State private var isRecentExpanded: Bool = true
    @State private var isLocationExpanded: Bool = true
    
    private let contentPadding: CGFloat = 20
    
    var body: some View {
        HStack(spacing: 0) {
            // 좌측 사이드바 (고정, 접히지 않음)
            VStack(alignment: .leading, spacing: 0) {
                // 취소 버튼
                Button(action: {
                    // 취소 액션
                }) {
                    Text("취소")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.secondColor)
                }
                .padding(.horizontal, contentPadding)
                .padding(.top, contentPadding)
                
                // 사이드바 메뉴
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // 최근 사용
                        SidebarMenuButton(title: "최근 사용", isExpanded: $isRecentExpanded)
                        
                        // 위치
                        SidebarMenuButton(title: "위치", isExpanded: $isLocationExpanded)
                    }
                    .padding(.top, 24)
                    .padding(.bottom, contentPadding)
                }
                
                Spacer()
            }
            .frame(width: 200)
            .background(Color.background2)
            
            // 세로 구분선
            Divider().background(Color.borderColor)
            
            // 우측 노트 목록
            VStack(spacing: 0) {
                // 헤더
                HStack(spacing: 0) {
                    Button(action: {}) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.secondColor)
                    }
                    
                    Spacer().frame(width: 16)
                    
                    Button(action: {}) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.secondColor)
                    }
                    
                    Spacer().frame(width: 16)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.text2)
                        
                        Text("소프트웨어공학및설계")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color.text1)
                    }
                    
                    Spacer()
                    
                    Button(action: {}) {
                        ZStack {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(Color.secondColor)
                                .font(.system(size: 20))
                            ZStack {
                                Circle().fill(.white).frame(width: 12, height: 12)
                                Image(systemName: "plus")
                                    .foregroundStyle(Color.secondColor)
                                    .font(.system(size: 8, weight: .bold))
                            }
                            .offset(x: 8, y: -6)
                        }
                    }
                    
                    Spacer().frame(width: 8)
                    
                    Text("이동")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.secondColor)
                }
                .padding(.top, contentPadding)
                .padding(.bottom, 12)
                
                // 노트 그리드
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ],
                        spacing: 16
                    ) {
                        ForEach(1...4, id: \.self) { index in
                            NoteCardView(title: "소프트웨어 \(index)장")
                        }
                    }
                    .padding(.top, 12)
                    .padding(.bottom, contentPadding)
                }
            }
            .padding(.horizontal, contentPadding)
            .frame(maxWidth: .infinity)
            .background(Color.background1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.background1)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
}

// 사이드바 메뉴 버튼
struct SidebarMenuButton: View {
    let title: String
    @Binding var isExpanded: Bool
    private let contentPadding: CGFloat = 20
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(title)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.text1)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.secondColor)
                }
                .padding(.horizontal, contentPadding)
                .padding(.vertical, 12)
            }
            
            Divider()
                .background(Color.borderColor)
                .padding(.horizontal, contentPadding)
        }
    }
}

// 노트 카드 뷰
struct NoteCardView: View {
    let title: String
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            // 영상 썸네일 영역
            ZStack {
                // 배경 그라데이션
                LinearGradient(
                    colors: [
                        Color.accentColor.opacity(0.3),
                        Color.secondColor.opacity(0.3)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // 패턴 효과
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        ForEach(0..<3) { _ in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 18, height: 12)
                        }
                    }
                    HStack(spacing: 4) {
                        ForEach(0..<3) { _ in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 18, height: 12)
                        }
                    }
                }
            }
            .frame(width: 80, height: 45)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.borderColor, lineWidth: 1)
            )
            
            // 제목
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(Color.text1)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.top, 6)
                .padding(.horizontal, 4)
        }
    }
}

#Preview(traits: .landscapeLeft) {
    GeometryReader { geometry in
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            NoteEditView()
                .frame(
                    width: min(720, geometry.size.width * 0.75),
                    height: min(400, geometry.size.height * 0.55)
                )
        }
    }
}
