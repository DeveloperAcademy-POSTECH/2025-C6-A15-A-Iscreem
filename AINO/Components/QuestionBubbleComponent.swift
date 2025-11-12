//
//  QuestionBubbleComponent.swift
//  learningtool
//
//  Created by Mumin on 10/22/25.
//

import SwiftUI

struct QuestionBubbleComponent: View {
    let message: ChatMessage
    let screenWidth: CGFloat
    
    /// iPad 11인치 기준 너비
    private let referenceWidth: CGFloat = 1194
    /// 기준 말풍선 너비
    private let referenceBubbleWidth: CGFloat = 214
    
    private var scaledMaxWidth: CGFloat {
        referenceBubbleWidth * (screenWidth / referenceWidth)
    }
    
    var body: some View {
        Text(message.text)
            .font(.system(size: 14))
            .foregroundStyle(.white)
            .multilineTextAlignment(message.isUser ? .trailing : .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                ChatBubbleShape(isRightAligned: message.isUser)
                    .fill(message.isUser ? Color.primaryColor : Color.secondColor)
            )
            .frame(maxWidth: scaledMaxWidth)
    }
}

/// 말풍선 꼬리가 있는 Shape
struct ChatBubbleShape: Shape {
    let isRightAligned: Bool
    private let cornerRadius: CGFloat = 16
    private let tailWidth: CGFloat = 12
    private let tailHeight: CGFloat = 16
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tailTopPosition = rect.midY - tailHeight / 2
        let tailBottomPosition = rect.midY + tailHeight / 2
        let tailTipPosition = rect.midY
        
        if isRightAligned {
            // 오른쪽 말풍선 (오른쪽 중앙에 삼각형 꼬리)
            path.move(to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY))
            path.addArc(
                center: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY + cornerRadius),
                radius: cornerRadius,
                startAngle: .degrees(-90),
                endAngle: .degrees(0),
                clockwise: false
            )
            
            // 꼬리 시작 전까지 오른쪽 선
            path.addLine(to: CGPoint(x: rect.maxX, y: tailTopPosition))
            
            // 오른쪽 삼각형 꼬리
            path.addLine(to: CGPoint(x: rect.maxX + tailWidth, y: tailTipPosition))
            path.addLine(to: CGPoint(x: rect.maxX, y: tailBottomPosition))
            
            // 꼬리 이후 오른쪽 선 계속
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius))
            path.addArc(
                center: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY - cornerRadius),
                radius: cornerRadius,
                startAngle: .degrees(0),
                endAngle: .degrees(90),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY))
            path.addArc(
                center: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY - cornerRadius),
                radius: cornerRadius,
                startAngle: .degrees(90),
                endAngle: .degrees(180),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
            path.addArc(
                center: CGPoint(x: rect.minX + cornerRadius, y: rect.minY + cornerRadius),
                radius: cornerRadius,
                startAngle: .degrees(180),
                endAngle: .degrees(270),
                clockwise: false
            )
        } else {
            // 왼쪽 말풍선 (왼쪽 중앙에 삼각형 꼬리)
            path.move(to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY))
            path.addArc(
                center: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY + cornerRadius),
                radius: cornerRadius,
                startAngle: .degrees(-90),
                endAngle: .degrees(0),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius))
            path.addArc(
                center: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY - cornerRadius),
                radius: cornerRadius,
                startAngle: .degrees(0),
                endAngle: .degrees(90),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY))
            path.addArc(
                center: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY - cornerRadius),
                radius: cornerRadius,
                startAngle: .degrees(90),
                endAngle: .degrees(180),
                clockwise: false
            )
            
            // 꼬리 끝 지점까지 왼쪽 선
            path.addLine(to: CGPoint(x: rect.minX, y: tailBottomPosition))
            
            // 왼쪽 삼각형 꼬리
            path.addLine(to: CGPoint(x: rect.minX - tailWidth, y: tailTipPosition))
            path.addLine(to: CGPoint(x: rect.minX, y: tailTopPosition))
            
            // 꼬리 이후 왼쪽 선 계속
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
            path.addArc(
                center: CGPoint(x: rect.minX + cornerRadius, y: rect.minY + cornerRadius),
                radius: cornerRadius,
                startAngle: .degrees(180),
                endAngle: .degrees(270),
                clockwise: false
            )
        }
        
        path.closeSubpath()
        return path
    }
}

#Preview(traits: .landscapeLeft) {
    GeometryReader { geometry in
        VStack(spacing: 20) {
            HStack {
                Spacer()
                QuestionBubbleComponent(
                    message: ChatMessage(
                        text: "안녕하세요! 질문이 있어요.",
                        isUser: true
                    ),
                    screenWidth: geometry.size.width
                )
            }
            
            HStack {
                QuestionBubbleComponent(
                    message: ChatMessage(
                        text: "안녕하세요! 무엇을 도와드릴까요?",
                        isUser: false
                    ),
                    screenWidth: geometry.size.width
                )
                Spacer()
            }
            
            HStack {
                Spacer()
                QuestionBubbleComponent(
                    message: ChatMessage(
                        text: "이것은 긴 텍스트 예시입니다. 텍스트가 길어지면 말풍선의 크기가 자동으로 조정됩니다.",
                        isUser: true
                    ),
                    screenWidth: geometry.size.width
                )
            }
        }
        .padding()
        .background(Color.background1)
    }
}

