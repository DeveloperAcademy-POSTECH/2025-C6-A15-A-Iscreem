//
//  ChatAreaView.swift
//  learningTool
//
//  Created by coulson on 10/30/25.
//

import SwiftUI

struct ChatAreaView: View {
    let messages: [ChatMessage]
    let isAPIKeyConfigured: Bool
    let isLoading: Bool
    @Binding var isTextFieldFocused: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    if !isAPIKeyConfigured {
                        // API 키 미설정 안내
                        VStack(spacing: 12) {
                            Image(systemName: "key.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(Color.secondColor.opacity(0.6))

                            Text("API 키가 설정되지 않았습니다")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.text3)

                            Text("우측 상단의 톱니바퀴 버튼을 눌러\nGemini API 키를 설정해주세요.")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.text3.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(40)
                    } else if messages.isEmpty && !isLoading {
                        // 메시지 없을 때 안내
                        VStack(spacing: 12) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(Color.secondColor.opacity(0.6))

                            Text("질문을 입력하고 엔터 또는\n보내기 버튼을 눌러주세요")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.text3.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(40)
                    } else {
                        ForEach(messages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }

                        if isLoading {
                            HStack {
                                ProgressView()
                                    .tint(Color.secondColor)
                                Text("AI가 답변을 생성중입니다...")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.text3)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .id("loading")
                        }
                    }
                }
                .padding(16)
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            .onChange(of: isLoading) { _, newValue in
                if newValue {
                    withAnimation { proxy.scrollTo("loading", anchor: .bottom) }
                } else if let last = messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            // Keyboard dismiss and tap-to-dismiss modifiers
            .scrollDismissesKeyboard(.interactively)
        }
    }
}
