//
//  QuestionView.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI

struct QuestionView: View {
    @ObservedObject var studyViewModel: StudyViewModel
    @ObservedObject var viewModel: QuestionViewModel
    @Binding var isGlobalInputActive: Bool
    
    // 외부 API 키 사용 제거에 따라 고정 비활성 상태로 동작
    @State private var isAPIKeyConfigured = false
    
    @FocusState private var isTextFieldFocused: Bool
    @State private var showingSuggestions = false
    @State private var suggestedQuestions: [String] = []
    @State private var isLoadingSuggestions = false
    
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
                isAPIKeyConfigured: false,
                isLoading: viewModel.isLoading,
                isTextFieldFocused: isFocusedBinding
            )
            
            Divider().background(Color.borderColor)
            
            // 인라인 입력 바(전역 바 활성화 시 숨김). 기능은 비활성 상태 유지.
            if !isGlobalInputActive {
                QuestionInputBar(
                    text: $viewModel.currentMessage,
                    isEnabled: false,
                    isSending: viewModel.isLoading,
                    isGenerating: isLoadingSuggestions,
                    focus: $isTextFieldFocused,
                    placeholder: "현재 버전에서는 이 기능을 사용할 수 없습니다",
                    onTapLightbulb: { },
                    onSend: { }
                )
                .padding(16)
                .allowsHitTesting(false)
            }
        }
        .background(Color.background1)
        // 인라인 입력을 탭하면 전역 바로 승격하는 기존 UX는 유지(포커스만 관리)
        .onChange(of: isTextFieldFocused) { _, focused in
            if focused {
                isGlobalInputActive = true
                isTextFieldFocused = false
            }
        }
        .onDisappear {
            isGlobalInputActive = false
        }
        .animation(.easeInOut(duration: 0.25), value: showingSuggestions)
        .onAppear {
            // 외부 API 키 상태 확인 로직 제거 → 고정 false
            isAPIKeyConfigured = false
        }
        // 키워드 삽입(내부 기능)과 학습 로그 기록은 유지
        .onChange(of: studyViewModel.shouldInsertKeyword) { _, shouldInsert in
            if shouldInsert, let keyword = studyViewModel.selectedKeyword {
                if !viewModel.currentMessage.isEmpty {
                    viewModel.currentMessage += " "
                }
                viewModel.currentMessage += keyword
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isTextFieldFocused = true
                }
                studyViewModel.keywordInserted()
            }
        }
        .onChange(of: studyViewModel.shouldGenerateSuggestions) { _, shouldGenerate in
            if shouldGenerate {
                // 외부 API 기반 추천 질문 자동 생성 기능은 제거되었으므로 플래그만 리셋
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

