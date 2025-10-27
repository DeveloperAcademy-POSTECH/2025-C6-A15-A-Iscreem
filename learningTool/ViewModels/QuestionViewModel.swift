//
//  QuestionViewModel.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI
import Combine

class QuestionViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var currentMessage = ""
    @Published var isLoading = false
    
    init() {
        // 샘플 메시지 로드 제거 - 빈 상태로 시작
    }
    
    /// 메시지 전송
    func sendMessage() {
        guard !currentMessage.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty else { return }
        
        let userMessage = ChatMessage(
            text: currentMessage,
            isUser: true
        )
        messages.append(userMessage)
        
        let question = currentMessage
        currentMessage = ""
        
        sendToLLMAPI(question: question)
    }
    
    /// LLM API 호출
    private func sendToLLMAPI(question: String) {
        isLoading = true
        
        Task {
            do {
                // Gemini API에 메시지 전송 (대화 히스토리 포함)
                let response = try await GeminiAPIService.shared
                    .sendMessage(question, conversationHistory: messages)
                
                await MainActor.run {
                    let aiMessage = ChatMessage(
                        text: response,
                        isUser: false
                    )
                    messages.append(aiMessage)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    handleError(error)
                }
            }
        }
    }
    
    /// 에러 처리
    private func handleError(_ error: Error) {
        isLoading = false
        let errorMessage = ChatMessage(
            text: "오류가 발생했습니다: \(error.localizedDescription)",
            isUser: false
        )
        messages.append(errorMessage)
    }
    
    /// 대화 초기화
    func clearMessages() {
        messages.removeAll()
    }
    
}

