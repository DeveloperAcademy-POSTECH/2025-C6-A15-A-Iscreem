//
//  QuestionView.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI

/// 말풍선 꼬리 모양
struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        
        // 아래쪽을 향하는 삼각형
        path.move(to: CGPoint(x: width * 0.3, y: 0))
        path.addLine(to: CGPoint(x: width * 0.5, y: height))
        path.addLine(to: CGPoint(x: width * 0.7, y: 0))
        path.closeSubpath()
        
        return path
    }
}

/// lightbulb 버튼 근처에 표시되는 말풍선 형태의 추천질문 뷰
struct SuggestionBubbleView: View {
    @Binding var isPresented: Bool
    let isLoading: Bool
    let suggestedQuestions: [String]
    let currentMessage: String
    let selectedKeyword: String?
    let onRegenerate: () -> Void
    let onPick: (String) -> Void
    
    // 말풍선 크기 설정 (더 넓은 가로 사이즈)
    private let bubbleWidth: CGFloat = 360
    private let bubbleMaxHeight: CGFloat = 220
    private let arrowSize: CGFloat = 12
    
    var body: some View {
        VStack(spacing: 0) {
            // 말풍선 본체
            VStack(spacing: 0) {
                // 헤더
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.orange)
                        Text("AI 추천 질문")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.text1)
                    }
                    
                    Spacer()
                    
                    // 새로고침 버튼
                    Button(action: onRegenerate) {
                        Image(systemName: isLoading ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.secondColor)
                            .frame(width: 24, height: 24)
                            .background(Color.background2)
                            .clipShape(Circle())
                            .rotationEffect(.degrees(isLoading ? 360 : 0))
                            .animation(isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                                       value: isLoading)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading)
                    
                    // 닫기 버튼
                    Button(action: { 
                        withAnimation(.easeOut(duration: 0.2)) { 
                            isPresented = false 
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.text3)
                            .frame(width: 24, height: 24)
                            .background(Color.background2)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.background1)
                
                Divider()
                    .background(Color.borderColor)
                
                // 콘텐츠 영역
                if isLoading {
                    VStack(spacing: 8) {
                        ProgressView()
                            .tint(Color.secondColor)
                            .scaleEffect(0.8)
                        Text("질문을 생성하고 있습니다...")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.text3)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 80)
                    .background(Color.background1)
                } else if !suggestedQuestions.isEmpty {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(Array(suggestedQuestions.enumerated()), id: \.offset) { index, question in
                                Button(action: {
                                    // 즉시 말풍선 닫기
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        isPresented = false
                                    }
                                    // 질문 선택 및 자동 전송
                                    onPick(question)
                                }) {
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("\(index + 1)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(.white)
                                            .frame(width: 18, height: 18)
                                            .background(
                                                LinearGradient(
                                                    colors: [Color.secondColor, Color.secondColor.opacity(0.7)],
                                                    startPoint: .topLeading, 
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .clipShape(Circle())
                                        
                                        Text(question)
                                            .font(.system(size: 13))
                                            .foregroundStyle(Color.text1)
                                            .multilineTextAlignment(.leading)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .lineLimit(2)
                                        
                                        Image(systemName: "paperplane.fill")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color.secondColor)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.background2)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.secondColor.opacity(0.15), lineWidth: 1)
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                    .frame(maxHeight: bubbleMaxHeight - 60) // 헤더 공간 제외
                    .background(Color.background1)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.orange)
                        Text("추천질문을 생성할 수 없습니다")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.text3)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 80)
                    .background(Color.background1)
                }
            }
            .frame(width: bubbleWidth)
            .frame(maxHeight: bubbleMaxHeight)
            .background(Color.background1)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.borderColor, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
            
            // 말풍선 꼬리 (아래쪽 화살표)
            BubbleTail()
                .fill(Color.background1)
                .frame(width: arrowSize * 2, height: arrowSize)
                .overlay(
                    BubbleTail()
                        .stroke(Color.borderColor, lineWidth: 1)
                        .frame(width: arrowSize * 2, height: arrowSize)
                )
                .offset(x: 100) // 더 넓어진 말풍선에 맞춰 lightbulb 버튼 위치 조정
        }
    }
}

struct QuestionView: View {
    @ObservedObject var studyViewModel: StudyViewModel
    @ObservedObject var viewModel: QuestionViewModel
    @Binding var isGlobalInputActive: Bool
    
    // ChatGPT API 키 상태는 ViewModel에서 관리
    
    @FocusState private var isTextFieldFocused: Bool
    
    @EnvironmentObject private var learningLogStore: LearningLogStore
    
    private var isFocusedBinding: Binding<Bool> {
        Binding(
            get: { isTextFieldFocused },
            set: { isTextFieldFocused = $0 }
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            QuestionHeaderBar(
                messageCount: viewModel.messages.count,
                onClear: { viewModel.clearMessages() }
            )
            
            Divider()
                .background(Color.borderColor)
            
            // 채팅 영역
            ChatAreaView(
                messages: viewModel.messages,
                isAPIKeyConfigured: viewModel.isAPIKeyValid,
                isLoading: viewModel.isLoading,
                isTextFieldFocused: isFocusedBinding
            )
            
            Divider().background(Color.borderColor)
            
            // 인라인 입력 바 (항상 표시)
            QuestionInputBar(
                text: $viewModel.currentMessage,
                includeScreenshot: $viewModel.includeScreenshot,
                isEnabled: viewModel.isAPIKeyValid && !viewModel.isLoading,
                isSending: viewModel.isLoading,
                isGenerating: viewModel.isLoadingSuggestions,
                focus: $isTextFieldFocused,
                placeholder: viewModel.isAPIKeyValid ? "AI에게 질문하세요..." : "API 키를 확인해주세요",
                onTapLightbulb: {
                    // 추천질문 생성
                    let context = studyViewModel.summaryContext
                    let keyword = studyViewModel.selectedKeyword
                    viewModel.generateSuggestions(context: context, keyword: keyword)
                },
                onSend: { viewModel.sendMessage() }
            )
            .padding(16)
        }
        .background(Color.background1)
        .overlay(alignment: .bottomTrailing) {
            // 추천질문 말풍선 (lightbulb 버튼 위쪽에 표시)
            if viewModel.showingSuggestions {
                SuggestionBubbleView(
                    isPresented: $viewModel.showingSuggestions,
                    isLoading: viewModel.isLoadingSuggestions,
                    suggestedQuestions: viewModel.suggestedQuestions,
                    currentMessage: viewModel.currentMessage,
                    selectedKeyword: studyViewModel.selectedKeyword,
                    onRegenerate: {
                        let context = studyViewModel.summaryContext
                        let keyword = studyViewModel.selectedKeyword
                        viewModel.generateSuggestions(context: context, keyword: keyword)
                    },
                    onPick: { question in
                        viewModel.selectSuggestion(question)
                    }
                )
                .padding(.trailing, 8)
                .padding(.bottom, 80) // QuestionInputBar 위쪽에 위치
                .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .bottomTrailing)))
            }
        }
        // 전역 입력 바 승격 로직 비활성화 (현재 구조에서는 불필요)
        // .onChange(of: isTextFieldFocused) { _, focused in
        //     if focused {
        //         isGlobalInputActive = true
        //         isTextFieldFocused = false
        //     }
        // }
        .onDisappear {
            isGlobalInputActive = false
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.showingSuggestions)
        .onAppear {
            // QuestionViewModel이 자동으로 API 키 상태를 관리
        }
        // 키워드 삽입(내부 기능)과 학습 로그 기록은 유지
        .onChange(of: studyViewModel.shouldInsertKeyword) { _, shouldInsert in
            if shouldInsert, let keyword = studyViewModel.selectedKeyword {
                if !viewModel.currentMessage.isEmpty {
                    viewModel.currentMessage += " "
                }
                viewModel.currentMessage += keyword
                studyViewModel.keywordInserted()
            }
        }
        .onChange(of: studyViewModel.shouldGenerateSuggestions) { _, shouldGenerate in
            if shouldGenerate {
                // 키워드 선택 시 자동으로 추천질문 생성
                let context = studyViewModel.summaryContext
                let keyword = studyViewModel.selectedKeyword
                viewModel.generateSuggestions(context: context, keyword: keyword)
                studyViewModel.suggestionsGenerated()
            }
        }
        .onChange(of: viewModel.messages.count) { oldValue, newValue in
            guard
                newValue > oldValue,
                viewModel.messages.count >= 2,
                let note = studyViewModel.currentNote
            else { return }
            
            let last = viewModel.messages[viewModel.messages.count - 1]
            let prev = viewModel.messages[viewModel.messages.count - 2]
            
            // 직전이 사용자 질문, 마지막이 AI 응답일 때만 Q&A로 기록
            if prev.isUser && !last.isUser {
                learningLogStore.recordQAPair(
                    folderName: note.folder?.name,
                    noteTitle: note.title,
                    noteIdentifier: String(describing: note.id),
                    videoURL: note.videoURL,
                    question: prev.text,
                    answer: last.text
                )
            }
        }
    }
}

