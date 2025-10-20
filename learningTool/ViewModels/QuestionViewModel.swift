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
        loadSampleMessages()
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
    
    /// LLM API 호출 (추후 구현)
    private func sendToLLMAPI(question: String) {
        isLoading = true
        
        // TODO: 실제 API 연동
        // 예시:
        // Task {
        //     do {
        //         let response = try await APIService.shared
        //             .sendChatMessage(question)
        //         await MainActor.run {
        //             let aiMessage = ChatMessage(
        //                 text: response,
        //                 isUser: false
        //             )
        //             messages.append(aiMessage)
        //             isLoading = false
        //         }
        //     } catch {
        //         await MainActor.run {
        //             handleError(error)
        //         }
        //     }
        // }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            let aiResponse = ChatMessage(
                text: "API 연동 준비 완료. 실제 LLM 응답이 여기에 표시됩니다.",
                isUser: false
            )
            self.messages.append(aiResponse)
            self.isLoading = false
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
    
    /// 샘플 메시지 로드
    private func loadSampleMessages() {
        messages = [
            ChatMessage(
                text: "OSI 7 계층에서, 데이터링크의 역할은 무엇인가요?",
                isUser: true
            ),
            ChatMessage(
                text: """
                    데이터링크 계층은, 물리적으로 연결된 두 장치 간 \
                    데이터를 안전하고 효율적으로 보내고, 프레임 단위로 \
                    조직화(MAC)과, 오류 검출 및 재전송(MAC), 그리고 \
                    접근 제어를 담당합니다.
                    """,
                isUser: false
            ),
        ]
    }
}

