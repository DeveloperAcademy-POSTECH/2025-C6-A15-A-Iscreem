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
                text: "안녕하세요! 질문이 있어요.",
                isUser: true
            ),
            ChatMessage(
                text: "안녕하세요! 무엇을 도와드릴까요?",
                isUser: false
            ),
            ChatMessage(
                text: "OSI 7 계층에서, 데이터링크의 역할은 무엇인지가 궁금해요.",
                isUser: true
            ),
            ChatMessage(
                text: "데이터링크 계층은 물리적으로 연결된 두 장치 간 데이터의 오류 없는 전송을 보장하고, 프레임 단위로 주소지정(MAC)과 오류 검출 및 재전송을 담당합니다.",
                isUser: false
            ),
            ChatMessage(
                text: "그렇다면 TCP/IP 프로토콜에서 3-way handshake는 어떻게 동작하나요? 자세히 설명해주실 수 있나요?",
                isUser: true
            ),
            ChatMessage(
                text: "3-way handshake는 클라이언트가 SYN 패킷을 보내면, 서버가 SYN-ACK로 응답하고, 마지막으로 클라이언트가 ACK를 보내 연결을 확립하는 과정입니다. 이를 통해 안정적인 연결을 보장합니다.",
                isUser: false
            ),
        ]
    }
}

