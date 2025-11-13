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
    
    init() { }
    
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
        
        // 외부 API 호출을 제거하므로, 여기서 질문을 소비하고 입력만 초기화
        currentMessage = ""
    }
    
    private func handleError(_ error: Error) {
        isLoading = false
        let errorMessage = ChatMessage(
            text: "오류가 발생했습니다: \(error.localizedDescription)",
            isUser: false
        )
        messages.append(errorMessage)
    }
    
    func clearMessages() {
        messages.removeAll()
    }
}

