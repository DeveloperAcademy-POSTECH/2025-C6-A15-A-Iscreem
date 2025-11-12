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

// MARK: - Preview용 컨테이너
struct HeaderComponents: View {
    var body: some View {
        ZStack {
            Color.background1
                .ignoresSafeArea()
        }
    }
}

#Preview(traits: .landscapeLeft) {
    HeaderComponents()
}
