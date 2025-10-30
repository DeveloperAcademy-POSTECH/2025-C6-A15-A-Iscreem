//
//  HeaderComponents.swift
//  learningtool
//
//  Created on 10/30/25.
//

import SwiftUI

// MARK: - 정렬 옵션
enum HeaderSortOption {
    case alphabeticalAsc
    case alphabeticalDesc
    case recentlyOpenedAsc
    case recentlyOpenedDesc
    case progressAsc
    case progressDesc
}

// MARK: - 말풍선 꼬리 Shape (우측 상단에 꼬리)
struct PopoverWithTailShape: Shape {
    let cornerRadius: CGFloat
    let tailWidth: CGFloat
    let tailHeight: CGFloat
    let tailOffsetFromRight: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // 말풍선 본체 영역
        let bodyRect = CGRect(
            x: rect.minX,
            y: rect.minY + tailHeight,
            width: rect.width,
            height: rect.height - tailHeight
        )
        
        // 꼬리 위치
        let tailCenterX = rect.maxX - tailOffsetFromRight
        let tailTipY = rect.minY
        let tailBaseY = bodyRect.minY
        let tailLeftX = tailCenterX - tailWidth / 2
        let tailRightX = tailCenterX + tailWidth / 2
        
        // 시계 방향으로 Path 그리기
        // 좌측 상단 모서리부터 시작
        path.move(to: CGPoint(x: bodyRect.minX + cornerRadius, y: bodyRect.minY))
        
        // 상단 선 (꼬리 왼쪽까지)
        path.addLine(to: CGPoint(x: tailLeftX, y: tailBaseY))
        
        // 꼬리 그리기
        path.addLine(to: CGPoint(x: tailCenterX, y: tailTipY))
        path.addLine(to: CGPoint(x: tailRightX, y: tailBaseY))
        
        // 상단 선 (꼬리 오른쪽부터 우측 상단 모서리)
        path.addLine(to: CGPoint(x: bodyRect.maxX - cornerRadius, y: bodyRect.minY))
        path.addArc(
            center: CGPoint(x: bodyRect.maxX - cornerRadius, y: bodyRect.minY + cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(-90),
            endAngle: .degrees(0),
            clockwise: false
        )
        
        // 우측 선
        path.addLine(to: CGPoint(x: bodyRect.maxX, y: bodyRect.maxY - cornerRadius))
        path.addArc(
            center: CGPoint(x: bodyRect.maxX - cornerRadius, y: bodyRect.maxY - cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        
        // 하단 선
        path.addLine(to: CGPoint(x: bodyRect.minX + cornerRadius, y: bodyRect.maxY))
        path.addArc(
            center: CGPoint(x: bodyRect.minX + cornerRadius, y: bodyRect.maxY - cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        
        // 좌측 선
        path.addLine(to: CGPoint(x: bodyRect.minX, y: bodyRect.minY + cornerRadius))
        path.addArc(
            center: CGPoint(x: bodyRect.minX + cornerRadius, y: bodyRect.minY + cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
        
        path.closeSubpath()
        
        return path
    }
}

// MARK: - 커스텀 정렬 아이콘 (내려갈수록 짧아지는 3선)
struct SortIconView: View {
    var body: some View {
        VStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.text2)
                .frame(width: 16, height: 2)
            
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.text2)
                .frame(width: 12, height: 2)
            
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.text2)
                .frame(width: 8, height: 2)
        }
    }
}

// MARK: - 헤더 메뉴 버튼
struct HeaderMenuButton: View {
    @State private var isMenuOpen = false
    @State private var selectedSort: HeaderSortOption = .recentlyOpenedAsc
    
    var body: some View {
        ZStack {
            // 햄버거 메뉴 아이콘 (고정)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isMenuOpen.toggle()
                }
            } label: {
                SortIconView()
                    .frame(width: 36, height: 36)
                    .background(Color.background2)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.borderColor, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .zIndex(101)
            
            // 말풍선 메뉴 (아이콘 중앙 아래에 배치, 꼬리는 우측)
            if isMenuOpen {
                VStack(spacing: 0) {
                    PopoverMenuContent(
                        selectedSort: $selectedSort,
                        onEditNote: {
                            isMenuOpen = false
                            // 노트 편집 로직
                        }
                    )
                }
                .frame(width: 255, height: 270)
                .background(
                    PopoverWithTailShape(cornerRadius: 12, tailWidth: 20, tailHeight: 10, tailOffsetFromRight: 30)
                        .fill(Color.background1)
                )
                .overlay(
                    PopoverWithTailShape(cornerRadius: 12, tailWidth: 20, tailHeight: 10, tailOffsetFromRight: 30)
                        .stroke(Color.borderColor, lineWidth: 1)
                )
                .offset(x: -195, y: 29)
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .frame(width: 36, height: 36)
        .background {
            // 메뉴 밖 클릭 시 닫기
            if isMenuOpen {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isMenuOpen = false
                        }
                    }
                    .zIndex(98)
            }
        }
    }
}

// MARK: - 말풍선 메뉴 내용
struct PopoverMenuContent: View {
    @Binding var selectedSort: HeaderSortOption
    let onEditNote: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // 정렬 옵션들
            VStack(spacing: 2) {
                MenuItemButton(
                    iconType: .alphabet,
                    title: "가나다 순(↑)",
                    isSelected: selectedSort == .alphabeticalAsc
                ) {
                    selectedSort = .alphabeticalAsc
                }
                
                MenuItemButton(
                    iconType: .alphabet,
                    title: "가나다 순(↓)",
                    isSelected: selectedSort == .alphabeticalDesc
                ) {
                    selectedSort = .alphabeticalDesc
                }
                
                MenuItemButton(
                    iconType: .clock,
                    title: "최근 열어본 항목(↑)",
                    isSelected: selectedSort == .recentlyOpenedAsc
                ) {
                    selectedSort = .recentlyOpenedAsc
                }
                
                MenuItemButton(
                    iconType: .clock,
                    title: "최근 열어본 항목(↓)",
                    isSelected: selectedSort == .recentlyOpenedDesc
                ) {
                    selectedSort = .recentlyOpenedDesc
                }
                
                MenuItemButton(
                    iconType: .sparkle,
                    title: "학습 진행률(↑)",
                    isSelected: selectedSort == .progressAsc
                ) {
                    selectedSort = .progressAsc
                }
                
                MenuItemButton(
                    iconType: .sparkle,
                    title: "학습 진행률(↓)",
                    isSelected: selectedSort == .progressDesc
                ) {
                    selectedSort = .progressDesc
                }
            }
            .padding(.top, 26)
            .padding(.bottom, 8)
            
            // 구분선
            Divider()
                .background(Color.borderColor)
            
            // 노트 편집하기
            Button {
                onEditNote()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.secondColor)
                    
                    Text("노트 편집하기")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color.secondColor)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            .padding(.bottom, 18)
        }
    }
}

// MARK: - 메뉴 아이콘 뷰들
struct AlphabetIconView: View {
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(isSelected ? Color.text1 : Color.text3, lineWidth: 1.5)
                .frame(width: 20, height: 20)
            
            Text("A")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isSelected ? Color.text1 : Color.text3)
        }
        .frame(width: 20, height: 20)
    }
}

struct ClockIconView: View {
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(isSelected ? Color.text1 : Color.text3, lineWidth: 1.5)
                .frame(width: 20, height: 20)
            
            // 시계바늘 (9시 정각) - 직각으로 연결
            Path { path in
                // 분침 (중심에서 12시 방향으로)
                path.move(to: CGPoint(x: 10, y: 10))
                path.addLine(to: CGPoint(x: 10, y: 3))
                
                // 시침 (중심에서 9시 방향으로)
                path.move(to: CGPoint(x: 10, y: 10))
                path.addLine(to: CGPoint(x: 5, y: 10))
            }
            .stroke(isSelected ? Color.text1 : Color.text3, style: StrokeStyle(lineWidth: 1.5, lineCap: .square, lineJoin: .miter))
        }
        .frame(width: 20, height: 20)
    }
}

struct SparkleIconView: View {
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            // 메인 십자 반짝이
            // 세로선
            Capsule()
                .fill(isSelected ? Color.text1 : Color.text3)
                .frame(width: 2, height: 14)
            
            // 가로선
            Capsule()
                .fill(isSelected ? Color.text1 : Color.text3)
                .frame(width: 14, height: 2)
            
            // 대각선 X 반짝이
            // 좌상-우하
            Capsule()
                .fill(isSelected ? Color.text1 : Color.text3)
                .frame(width: 2, height: 10)
                .rotationEffect(.degrees(45))
            
            // 우상-좌하
            Capsule()
                .fill(isSelected ? Color.text1 : Color.text3)
                .frame(width: 2, height: 10)
                .rotationEffect(.degrees(-45))
            
            // 작은 반짝이들
            // 우상
            Circle()
                .fill(isSelected ? Color.text1 : Color.text3)
                .frame(width: 2, height: 2)
                .offset(x: 8, y: -8)
            
            // 좌하
            Circle()
                .fill(isSelected ? Color.text1 : Color.text3)
                .frame(width: 2, height: 2)
                .offset(x: -8, y: 8)
        }
        .frame(width: 20, height: 20)
    }
}

// MARK: - 메뉴 아이템 버튼
struct MenuItemButton: View {
    let iconType: MenuIconType
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    enum MenuIconType {
        case alphabet
        case clock
        case sparkle
    }
    
    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 10) {
                Group {
                    switch iconType {
                    case .alphabet:
                        AlphabetIconView(isSelected: isSelected)
                    case .clock:
                        ClockIconView(isSelected: isSelected)
                    case .sparkle:
                        SparkleIconView(isSelected: isSelected)
                    }
                }
                .frame(width: 20, height: 20)
                
                Text(title)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(isSelected ? Color.text1 : Color.text3)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview용 컨테이너
struct HeaderComponents: View {
    var body: some View {
        ZStack {
            Color.background1
                .ignoresSafeArea()
            
            HeaderMenuButton()
        }
    }
}

#Preview(traits: .landscapeLeft) {
    HeaderComponents()
}
