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
    @EnvironmentObject private var localizationManager: LocalizationManager

    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                        if !isAPIKeyConfigured {
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(Color.orange.opacity(0.6))
                                Text(LocalizedText(korean: "AI 기능을 사용할 수 없습니다", english: "AI features are unavailable").text)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.text3)
                                Text(LocalizedText(korean: "ChatGPT API 키를 확인해주세요.\n개발자에게 문의하시기 바랍니다.", english: "Please check your ChatGPT API key.\nContact the developer for assistance.").text)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.text3.opacity(0.8))
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(40)
                        } else if messages.isEmpty && !isLoading {
                            VStack(spacing: 12) {
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(Color.secondColor.opacity(0.6))
                                Text(LocalizedText(korean: "AI에게 학습 관련 질문을 해보세요!\n간결하고 명확한 답변을 받을 수 있습니다.", english: "Ask AI questions about your learning!\nGet concise and clear answers.").text)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.text3.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(4)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(40)
                        } else {
                            ForEach(messages) { message in
                                ChatBubble(message: message)
                                    .id(message.id)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            if isLoading {
                                HStack {
                                    ProgressView()
                                        .tint(Color.secondColor)
                                    Text(LocalizedText(korean: "AI가 답변을 생성중입니다...", english: "AI is generating an answer...").text)
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.text3)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .id("loading")
                            }
                        }
                    }
                    // 전체 VStack의 최소 높이를 화면 높이로 맞추고,
                    // 빈 상태일 때만 세로 중앙 정렬이 되도록 설정
                    .frame(
                        maxWidth: .infinity,
                        minHeight: geo.size.height,
                        alignment: (messages.isEmpty && !isLoading) ? .center : .top
                    )
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
                .scrollDismissesKeyboard(.interactively)
            }
        }
    }
}
