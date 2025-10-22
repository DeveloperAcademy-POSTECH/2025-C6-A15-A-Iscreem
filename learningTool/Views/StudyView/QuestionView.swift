//
//  QuestionView.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI

struct QuestionView: View {
    @StateObject private var viewModel = QuestionViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            /// 헤더
            HStack {
                Text("AI에게 무엇이든 물어보세요!")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.text2)
                
                Spacer()
                
                if viewModel.messages.count > 2 {
                    Button(action: { viewModel.clearMessages() }) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.errorColor)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            
            Divider()
                .background(Color.borderColor)
            
            /// 채팅 영역
            ScrollViewReader { proxy in
                GeometryReader { geometry in
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(viewModel.messages) { message in
                                HStack {
                                    if message.isUser {
                                        Spacer(minLength: 40)
                                    }
                                    
                                    QuestionBubbleComponent(
                                        message: message,
                                        screenWidth: geometry.size.width
                                    )
                                    
                                    if !message.isUser {
                                        Spacer(minLength: 40)
                                    }
                                }
                                .id(message.id)
                            }
                            
                            if viewModel.isLoading {
                                HStack {
                                    ProgressView()
                                        .tint(Color.secondColor)
                                    Text("AI가 답변을 생성중입니다...")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.text3)
                                    Spacer()
                                }
                            }
                        }
                        .padding(16)
                    }
                    .onChange(of: viewModel.messages.count) {
                        if let lastMessage = viewModel.messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            
            Divider()
                .background(Color.borderColor)
            
            /// 입력 영역
            HStack(spacing: 12) {
                TextField(
                    "메시지를 입력하세요",
                    text: $viewModel.currentMessage,
                    axis: .horizontal
                )
                .font(.system(size: 15))
                .lineLimit(1)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.background2)
                .cornerRadius(20)
                .disabled(viewModel.isLoading)
                .onSubmit {
                    viewModel.sendMessage()
                }
                
                Button(action: { viewModel.sendMessage() }) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(
                            viewModel.isLoading
                                || viewModel.currentMessage.isEmpty
                                ? Color.text3.opacity(0.5)
                                : Color.secondColor
                        )
                        .clipShape(Circle())
                }
                .disabled(
                    viewModel.isLoading
                        || viewModel.currentMessage.isEmpty
                )
            }
            .padding(16)
            .background(Color.background1)
        }
        .background(Color.background1)
    }
}

#Preview(traits: .landscapeLeft) {
    QuestionView()
}