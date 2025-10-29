//
//  QuestionView.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI

struct QuestionView: View {
    @ObservedObject var studyViewModel: StudyViewModel
    @StateObject private var viewModel = QuestionViewModel()
    @State private var isAPIKeyConfigured = GeminiAPIService.shared.isAPIKeyConfigured()
    @FocusState private var isTextFieldFocused: Bool
    @State private var showingSuggestions = false
    @State private var suggestedQuestions: [String] = []
    @State private var isLoadingSuggestions = false
    // FocusState<Bool>.Binding → Binding<Bool> 브리지
    private var isFocusedBinding: Binding<Bool> {
        Binding(
            get: { isTextFieldFocused },
            set: { isTextFieldFocused = $0 }
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            /// 헤더
                QuestionHeaderBar(
                    messageCount: viewModel.messages.count,
                    onClear: { viewModel.clearMessages() }
                )
            
            Divider()
                .background(Color.borderColor)
            
            /// 채팅 영역
            ChatAreaView(
                messages: viewModel.messages,
                isAPIKeyConfigured: isAPIKeyConfigured,
                isLoading: viewModel.isLoading,
                isTextFieldFocused: isFocusedBinding
            )
            
            Divider()
                .background(Color.borderColor)
            
            /// 추천 질문 메뉴 (팝업 스타일)
            if showingSuggestions {
                SuggestionsSheetView(
                    isPresented: $showingSuggestions,
                    isLoading: isLoadingSuggestions,
                    suggestedQuestions: suggestedQuestions,
                    currentMessage: viewModel.currentMessage,
                    selectedKeyword: studyViewModel.selectedKeyword,
                    onRegenerate: { regenerateSuggestedQuestions() },
                    onPick: { picked in
                        withAnimation {
                            viewModel.currentMessage = picked
                            isTextFieldFocused = true
                        }
                    }
                )
                .zIndex(1000)
            }
            // NOTE: 입력 UI를 QuestionInputBar로 분리하여 재사용성과 가독성을 높였습니다.
            // - text: 현재 입력 텍스트 바인딩
            // - isEnabled: API 키 설정 및 로딩 상태에 따라 활성화 여부
            // - isSending: 모델 응답 로딩 중 전송 버튼 상태
            // - isGenerating: 추천 질문 생성 스피너 상태
            // - focus: 키보드 포커스 연동(FocusState)
            // - placeholder: 상태에 따른 안내 문구
            // - onTapLightbulb: 추천 질문 생성 트리거
            // - onSend: 메시지 전송 트리거
            // 입력 영역 (컴포넌트화)
            QuestionInputBar(
                text: $viewModel.currentMessage,
                isEnabled: isAPIKeyConfigured && !viewModel.isLoading,
                isSending: viewModel.isLoading,
                isGenerating: isLoadingSuggestions,
                focus: $isTextFieldFocused,
                placeholder: isAPIKeyConfigured ? "메시지를 입력하세요" : "API 키를 먼저 설정해주세요",
                onTapLightbulb: {
                    print("\n💡 ===== 전구 버튼 클릭 (from QuestionInputBar) =====")
                    generateSuggestedQuestions()
                },
                onSend: {
                    if isAPIKeyConfigured {
                        viewModel.sendMessage()
                    }
                }
            )
            .padding(16)
            .background(Color.background1)
        }
        .background(Color.background1)
        .animation(.easeInOut(duration: 0.25), value: showingSuggestions)
        .onAppear {
            isAPIKeyConfigured = GeminiAPIService.shared.isAPIKeyConfigured()
        }
        .onReceive(NotificationCenter.default.publisher(for: GeminiAPIService.apiKeyDidChangeNotification)) { _ in
            // API 키가 변경되면 상태 업데이트
            let wasConfigured = isAPIKeyConfigured
            isAPIKeyConfigured = GeminiAPIService.shared.isAPIKeyConfigured()
            
            // API 키가 새로 설정되면 텍스트필드에 포커스
            if !wasConfigured && isAPIKeyConfigured {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isTextFieldFocused = true
                }
            }
        }
        .onChange(of: studyViewModel.shouldInsertKeyword) { _, shouldInsert in
            if shouldInsert, let keyword = studyViewModel.selectedKeyword {
                // 기존 텍스트가 있으면 공백 추가
                if !viewModel.currentMessage.isEmpty {
                    viewModel.currentMessage += " "
                }
                viewModel.currentMessage += keyword
                
                // 포커스를 텍스트 마지막으로 이동
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isTextFieldFocused = true
                }
                
                // 삽입 완료 표시
                studyViewModel.keywordInserted()
            }
        }
        .onChange(of: studyViewModel.shouldGenerateSuggestions) { _, shouldGenerate in
            if shouldGenerate {
                print("🔔 [자동생성] 키워드 선택 감지 - 추천질문 자동 생성 시작")
                // API 키가 설정되어 있고, 키워드가 선택되어 있으면 자동 생성
                if isAPIKeyConfigured && studyViewModel.selectedKeyword != nil {
                    // 키워드가 텍스트필드에 삽입되는 시간을 고려하여 약간의 딜레이 후 실행
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        performQuestionGeneration()
                    }
                }
                // 생성 완료 표시
                studyViewModel.suggestionsGenerated()
            }
        }
    }
    
    /// AI를 통한 추천 질문 생성 (전구 버튼용 - 토글 기능 포함)
    private func generateSuggestedQuestions() {
        print("🔍 [전구버튼] generateSuggestedQuestions 호출됨")
        print("🔍 [전구버튼] API 설정: \(isAPIKeyConfigured)")
        print("🔍 [전구버튼] 선택된 키워드: \(studyViewModel.selectedKeyword ?? "없음")")
        print("🔍 [전구버튼] 현재 표시 상태: showingSuggestions=\(showingSuggestions), isLoading=\(isLoadingSuggestions)")
        
        guard studyViewModel.selectedKeyword != nil else {
            print("❌ [전구버튼] 키워드 없음 - 종료")
            return
        }
        
        // 이미 표시 중이면 토글 (숨기기)
        if showingSuggestions && !isLoadingSuggestions {
            print("🔄 [전구버튼] 토글 - 메뉴 숨기기")
            showingSuggestions = false
            return
        }
        
        print("✅ [전구버튼] performQuestionGeneration 호출")
        // 새로 생성
        performQuestionGeneration()
    }
    
    /// 추천 질문 재생성 (새로고침 버튼용 - 토글 없이 항상 재생성)
    private func regenerateSuggestedQuestions() {
        print("🔄 [새로고침] regenerateSuggestedQuestions 호출됨")
        performQuestionGeneration()
    }
    
    /// 실제 질문 생성 로직
    private func performQuestionGeneration() {
        print("⚙️ [생성] performQuestionGeneration 시작")
        
        // 텍스트필드 내용 확인
        let userInput = viewModel.currentMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        print("✅ [생성] 텍스트필드 내용: \(userInput)")
        
        // 선택된 키워드 확인 (있으면 참고용으로 사용)
        let keyword = studyViewModel.selectedKeyword
        if let kw = keyword {
            print("✅ [생성] 선택된 키워드: \(kw)")
        }
        
        // 요약 컨텍스트가 비어있어도 진행 (기본 질문 생성)
        let contextText = studyViewModel.summaryContext.isEmpty
        ? "강의 내용에 대한 학습"
        : studyViewModel.summaryContext
        
        print("📝 [생성] 컨텍스트 길이: \(contextText.count)자")
        print("📝 [생성] 컨텍스트 미리보기: \(String(contextText.prefix(100)))...")
        
        // 기존 질문 초기화 후 새로 생성
        suggestedQuestions = []
        isLoadingSuggestions = true
        showingSuggestions = true
        
        print("🎬 [생성] 상태 업데이트: isLoadingSuggestions=true, showingSuggestions=true")
        
        Task {
            do {
                // 프롬프트 생성 - 텍스트필드 내용을 우선으로 사용
                let prompt: String
                if !userInput.isEmpty {
                    // 텍스트필드에 내용이 있으면 그것을 기반으로 질문 생성
                    if let kw = keyword {
                        prompt = """
                        다음은 강의 요약 내용입니다:
                        \(contextText)
                        
                        사용자가 '\(userInput)'에 대해 궁금해하고 있습니다. 
                        '\(kw)' 키워드와 관련하여, 위 입력을 바탕으로 더 깊이 있는 학습 질문 3가지를 생성해주세요.
                        각 질문은 한 줄로 작성하고, 번호나 특수문자 없이 질문만 작성해주세요.
                        """
                    } else {
                        prompt = """
                        다음은 강의 요약 내용입니다:
                        \(contextText)
                        
                        사용자가 '\(userInput)'에 대해 궁금해하고 있습니다. 
                        위 입력을 바탕으로 더 깊이 있는 학습 질문 3가지를 생성해주세요.
                        각 질문은 한 줄로 작성하고, 번호나 특수문자 없이 질문만 작성해주세요.
                        """
                    }
                } else if let kw = keyword {
                    // 텍스트필드가 비어있으면 키워드만으로 질문 생성
                    prompt = """
                    다음은 강의 요약 내용입니다:
                    \(contextText)
                    
                    위 맥락에서 '\(kw)' 키워드와 관련된 학습 질문 3가지를 생성해주세요.
                    각 질문은 한 줄로 작성하고, 번호나 특수문자 없이 질문만 작성해주세요.
                    """
                } else {
                    print("❌ [생성] 키워드와 텍스트 모두 없음 - 종료")
                    await MainActor.run {
                        isLoadingSuggestions = false
                        showingSuggestions = false
                    }
                    return
                }
                
                print("📤 [API] Gemini API 요청 전송 중...")
                print("📤 [API] 프롬프트 길이: \(prompt.count)자")
                
                // 추천 질문 생성은 독립적인 요청이므로 대화 히스토리를 포함하지 않음
                let response = try await GeminiAPIService.shared.sendMessage(prompt, conversationHistory: [])
                
                print("📥 [API] 응답 받음 - 길이: \(response.count)자")
                print("📥 [API] 응답 내용:\n\(response)")
                
                // 응답을 줄바꿈으로 분리하여 질문 목록 생성
                let allLines = response.components(separatedBy: .newlines)
                print("🔍 [파싱] 전체 줄 수: \(allLines.count)")
                
                let questions = allLines
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty && !$0.hasPrefix("#") && !$0.hasPrefix("-") && !$0.hasPrefix("*") }
                    .map { question in
                        // 숫자로 시작하는 경우 제거
                        var cleaned = question
                        if let range = cleaned.range(of: "^[0-9]+\\.?\\s*", options: .regularExpression) {
                            cleaned.removeSubrange(range)
                        }
                        print("   ✓ 파싱된 질문: \(cleaned)")
                        return cleaned
                    }
                    .prefix(3)
                
                print("✅ [파싱] 최종 질문 개수: \(questions.count)")
                
                await MainActor.run {
                    suggestedQuestions = Array(questions)
                    isLoadingSuggestions = false
                    print("🎉 [완료] UI 업데이트 완료 - 질문 \(suggestedQuestions.count)개 표시")
                    print("🎉 [완료] showingSuggestions=\(showingSuggestions)")
                }
            } catch {
                print("❌ [오류] \(error.localizedDescription)")
                if let geminiError = error as? GeminiAPIError {
                    print("❌ [오류] Gemini 오류: \(geminiError)")
                }
                await MainActor.run {
                    isLoadingSuggestions = false
                    showingSuggestions = false
                    print("❌ [오류처리] 상태 초기화 완료")
                }
            }
        }
    }
}

#Preview(traits: .landscapeLeft) {
    QuestionView(studyViewModel: StudyViewModel())
}
