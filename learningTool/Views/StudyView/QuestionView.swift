//
//  QuestionView.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI

struct QuestionView: View {
    @ObservedObject var studyViewModel: StudyViewModel
    let scaleFactor: CGFloat
    
    @StateObject private var viewModel = QuestionViewModel()
    @State private var isAPIKeyConfigured = GeminiAPIService.shared.isAPIKeyConfigured()
    @FocusState private var isTextFieldFocused: Bool
    @State private var showingSuggestions = false
    @State private var suggestedQuestions: [String] = []
    @State private var isLoadingSuggestions = false
    
    var body: some View {
        VStack(spacing: 0) {
            /// 헤더
            HStack {
                VStack(alignment: .leading, spacing: ScaleCalculator.scaled(4, with: scaleFactor)) {
                    Text("AI에게 무엇이든 물어보세요!")
                        .font(.system(size: ScaleCalculator.scaled(15, with: scaleFactor)))
                        .foregroundStyle(Color.text2)
                    
                    Rectangle()
                        .fill(Color.text2)
                        .frame(height: 1)
                }
                .fixedSize()
                
                Spacer()
                
                if viewModel.messages.count > 2 {
                    Button(action: { viewModel.clearMessages() }) {
                        Image(systemName: "trash")
                            .font(.system(size: ScaleCalculator.scaled(14, with: scaleFactor)))
                            .foregroundStyle(Color.errorColor)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, ScaleCalculator.scaled(16, with: scaleFactor))
            .padding(.top, ScaleCalculator.scaled(16, with: scaleFactor))
            .padding(.bottom, ScaleCalculator.scaled(12, with: scaleFactor))
            
            /// 채팅 영역 (302 x 297)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: ScaleCalculator.scaled(16, with: scaleFactor)) {
                        if !isAPIKeyConfigured {
                            /// API 키 미설정 안내
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
                        } else if viewModel.messages.isEmpty && !viewModel.isLoading {
                            /// 메시지 없을 때 안내
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
                            ForEach(viewModel.messages) { message in
                                ChatBubble(message: message, scaleFactor: scaleFactor)
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
                                .padding(.horizontal, 16)
                                .id("loading")
                            }
                        }
                    }
                    .padding(ScaleCalculator.scaled(12, with: scaleFactor))
                }
                .frame(
                    width: ScaleCalculator.scaled(302, with: scaleFactor),
                    height: ScaleCalculator.scaled(297, with: scaleFactor)
                )
                .background(.white)
                .cornerRadius(ScaleCalculator.scaled(12, with: scaleFactor))
                .onChange(of: viewModel.messages.count) {
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: viewModel.isLoading) { oldValue, isLoading in
                    if isLoading {
                        // 로딩이 시작되면 로딩 인디케이터로 스크롤
                        withAnimation {
                            proxy.scrollTo("loading", anchor: .bottom)
                        }
                    } else if let lastMessage = viewModel.messages.last {
                        // 로딩이 끝나면 마지막 메시지로 스크롤
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                        // 응답 완료 후 텍스트필드에 포커스
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isTextFieldFocused = true
                        }
                    }
                }
            }
            .padding(.horizontal, ScaleCalculator.scaled(16, with: scaleFactor))
            
            /// 추천 질문 메뉴 (팝업 스타일)
            if showingSuggestions {
                ZStack(alignment: .bottom) {
                    // 반투명 배경 (클릭하면 닫기)
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            showingSuggestions = false
                        }
                    
                    VStack(spacing: 0) {
                        /// 헤더
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Image(systemName: "lightbulb.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.orange)
                                    
                                    Text("AI 추천 질문")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(Color.text1)
                                }
                                
                                let displayText = viewModel.currentMessage.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !displayText.isEmpty {
                                    Text("'\(displayText.prefix(30))\(displayText.count > 30 ? "..." : "")' 관련 학습 질문")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.text3)
                                } else if let keyword = studyViewModel.selectedKeyword {
                                    Text("'\(keyword)' 관련 학습 질문")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.text3)
                                }
                            }
                            
                            Spacer()
                            
                            /// 새로고침 버튼
                            Button(action: {
                                regenerateSuggestedQuestions()
                            }) {
                                Image(systemName: isLoadingSuggestions ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.secondColor)
                                    .frame(width: 32, height: 32)
                                    .background(Color.background2)
                                    .clipShape(Circle())
                                    .rotationEffect(.degrees(isLoadingSuggestions ? 360 : 0))
                                    .animation(
                                        isLoadingSuggestions
                                            ? .linear(duration: 1).repeatForever(autoreverses: false)
                                            : .default,
                                        value: isLoadingSuggestions
                                    )
                            }
                            .buttonStyle(.plain)
                            .disabled(isLoadingSuggestions)
                            
                            /// 닫기 버튼
                            Button(action: { 
                                withAnimation(.easeOut(duration: 0.2)) {
                                    showingSuggestions = false
                                }
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color.text3)
                                    .frame(width: 32, height: 32)
                                    .background(Color.background2)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(16)
                        .background(Color.background1)
                        
                        Divider()
                            .background(Color.borderColor)
                        
                        /// 질문 목록 또는 로딩
                        if isLoadingSuggestions {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .tint(Color.secondColor)
                                    .scaleEffect(1.2)
                                Text("AI가 질문을 생성하고 있습니다...")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.text3)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 160)
                            .background(Color.background1)
                        } else if !suggestedQuestions.isEmpty {
                            ScrollView {
                                VStack(spacing: 10) {
                                    ForEach(Array(suggestedQuestions.enumerated()), id: \.offset) { index, question in
                                        Button(action: {
                                            withAnimation {
                                                viewModel.currentMessage = question
                                                showingSuggestions = false
                                                isTextFieldFocused = true
                                            }
                                        }) {
                                            HStack(alignment: .top, spacing: 12) {
                                                // 번호 뱃지
                                                Text("\(index + 1)")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundStyle(.white)
                                                    .frame(width: 24, height: 24)
                                                    .background(
                                                        LinearGradient(
                                                            colors: [Color.secondColor, Color.secondColor.opacity(0.7)],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        )
                                                    )
                                                    .clipShape(Circle())
                                                
                                                Text(question)
                                                    .font(.system(size: 14))
                                                    .foregroundStyle(Color.text1)
                                                    .multilineTextAlignment(.leading)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                
                                                Image(systemName: "arrow.right.circle.fill")
                                                    .font(.system(size: 18))
                                                    .foregroundStyle(Color.secondColor.opacity(0.6))
                                            }
                                            .padding(14)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color.background2)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .stroke(Color.secondColor.opacity(0.2), lineWidth: 1)
                                                    )
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(16)
                            }
                            .frame(height: 160)
                            .background(Color.background1)
                        }
                    }
                    .background(Color.background1)
                    .cornerRadius(16, corners: [.topLeft, .topRight])
                    .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: -5)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .zIndex(1000)
            }
            
            /// 입력 영역
            HStack(spacing: ScaleCalculator.scaled(12, with: scaleFactor)) {
                VStack(spacing: ScaleCalculator.scaled(4, with: scaleFactor)) {
                    TextField(
                        isAPIKeyConfigured ? "메시지를 입력하세요" : "API 키를 먼저 설정해주세요",
                        text: $viewModel.currentMessage,
                        axis: .horizontal
                    )
                    .focused($isTextFieldFocused)
                    .font(.system(size: ScaleCalculator.scaled(15, with: scaleFactor)))
                    .lineLimit(1)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.background2)
                    .cornerRadius(20)
                    .disabled(viewModel.isLoading || !isAPIKeyConfigured)
                    .onSubmit {
                        if isAPIKeyConfigured {
                            viewModel.sendMessage()
                        }
                    }
                }
                
                /// 추천 질문 버튼
                Button(action: {
                    print("\n💡 ===== 전구 버튼 클릭 =====")
                    generateSuggestedQuestions()
                }) {
                    Image(systemName: isLoadingSuggestions ? "arrow.triangle.2.circlepath" : "lightbulb.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(
                            // API 미설정 OR (키워드 없고 텍스트도 없음) OR 로딩중이면 비활성
                            !isAPIKeyConfigured || (studyViewModel.selectedKeyword == nil && viewModel.currentMessage.isEmpty) || isLoadingSuggestions
                                ? Color.text3.opacity(0.5)
                                : Color.orange
                        )
                        .clipShape(Circle())
                        .rotationEffect(.degrees(isLoadingSuggestions ? 360 : 0))
                        .animation(
                            isLoadingSuggestions
                                ? .linear(duration: 1).repeatForever(autoreverses: false)
                                : .default,
                            value: isLoadingSuggestions
                        )
                }
                .buttonStyle(.plain)
                .disabled(!isAPIKeyConfigured || (studyViewModel.selectedKeyword == nil && viewModel.currentMessage.isEmpty) || isLoadingSuggestions)
                
                Button(action: { viewModel.sendMessage() }) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: ScaleCalculator.scaled(16, with: scaleFactor)))
                        .foregroundStyle(.white)
                        .frame(
                            width: ScaleCalculator.scaled(36, with: scaleFactor),
                            height: ScaleCalculator.scaled(36, with: scaleFactor)
                        )
                        .background(
                            viewModel.isLoading
                                || viewModel.currentMessage.isEmpty
                                || !isAPIKeyConfigured
                                ? Color.text3.opacity(0.5)
                                : Color.secondColor
                            )
                        .clipShape(Circle())
                            
                }
                .disabled(
                    viewModel.isLoading
                        || viewModel.currentMessage.isEmpty
                        || !isAPIKeyConfigured
                )
            }
            .padding(.horizontal, ScaleCalculator.scaled(16, with: scaleFactor))
            .padding(.top, ScaleCalculator.scaled(8, with: scaleFactor))
            .padding(.bottom, ScaleCalculator.scaled(16, with: scaleFactor))
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
                // 키워드가 입력된 후 (텍스트필드가 비어있지 않을 때) 자동 생성
                if !viewModel.currentMessage.isEmpty && isAPIKeyConfigured {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
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
        
        guard let _ = studyViewModel.selectedKeyword else {
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

struct ChatBubble: View {
    let message: ChatMessage
    let scaleFactor: CGFloat
    
    var body: some View {
        HStack(alignment: .bottom, spacing: ScaleCalculator.scaled(8, with: scaleFactor)) {
            if message.isUser {
                Spacer(minLength: ScaleCalculator.scaled(40, with: scaleFactor))
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: ScaleCalculator.scaled(4, with: scaleFactor)) {
                Text(message.text)
                    .font(.system(size: ScaleCalculator.scaled(14, with: scaleFactor)))
                    .foregroundStyle(message.isUser ? .white : Color.text1)
                    .padding(.horizontal, ScaleCalculator.scaled(16, with: scaleFactor))
                    .padding(.vertical, ScaleCalculator.scaled(12, with: scaleFactor))
                    .background(
                        message.isUser
                            ? Color.primaryColor
                            : Color.secondColor.opacity(0.15)
                    )
                    .cornerRadius(ScaleCalculator.scaled(16, with: scaleFactor))
                
                Text(timeString(from: message.timestamp))
                    .font(.system(size: ScaleCalculator.scaled(11, with: scaleFactor)))
                    .foregroundStyle(Color.text3)
                    .padding(.horizontal, ScaleCalculator.scaled(4, with: scaleFactor))
            }
            
            if !message.isUser {
                Spacer(minLength: ScaleCalculator.scaled(40, with: scaleFactor))
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

// MARK: - View Extensions
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

//#Preview(traits: .landscapeLeft) {
//    QuestionView(studyViewModel: StudyViewModel())
//}
