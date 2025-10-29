//
//  ChatBubble.swift
//  learningTool
//
//  Created by coulson on 10/30/25.
//  QuestionView에서 사용하던 말풍선 UI를 분리
//  ChatBubbleShape 는 QuestionBubbleComponent.swift 에 이미 존재(재사용)

import SwiftUI

struct ChatBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isUser {
                Spacer(minLength: 40)
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.system(size: 14))
                    .foregroundStyle(message.isUser ? .white : Color.text1)
                    .multilineTextAlignment(message.isUser ? .trailing : .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        ChatBubbleShape(isRightAligned: message.isUser)
                            .fill(
                                message.isUser
                                ? Color.primaryColor
                                : Color.secondColor.opacity(0.15)
                            )
                    )
                
                Text(timeString(from: message.timestamp))
                    .font(.system(size: 11))
                    .foregroundStyle(Color.text3)
                    .padding(.horizontal, 4)
            }
            
            if !message.isUser {
                Spacer(minLength: 40)
            }
        }
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: date)
    }
}
