//
//  QuestionViewModel.swift
//  AINO
//
//  ChatGPT 기반 질문답변 기능을 담당하는 ViewModel
//  GPT-4o-mini를 사용하여 비용 효율적인 AI 대화 제공
//

import SwiftUI
import Combine
import OSLog
import Foundation

// MARK: - API Keys Configuration
/// API 키 및 시크릿 정보를 관리하는 구조체
struct APIKeys {
    /// ChatGPT API 키 (실제 키는 별도 설정 필요)
    static let openAI = "YOUR_OPENAI_API_KEY_HERE"
    
    /// API 엔드포인트
    static let openAIEndpoint = "https://api.openai.com/v1/chat/completions"
    
    /// 사용할 모델 (GPT-4o-mini - 최저 비용)
    static let openAIModel = "gpt-4o-mini"
    
    /// OpenAI 설정
    struct OpenAIConfig {
        static let temperature: Double = 0.3    // 일관된 답변, 토큰 절약
        static let maxTokens = 150             // 간결한 답변으로 비용 절약
        static let systemPrompt = """
        당신은 학습을 도와주는 AI 어시스턴트입니다. 
        간결하고 명확한 답변을 제공하세요. 
        질문에 직접적으로 답변하고 불필요한 부연설명은 피하세요.
        """
    }
    
    /// API 키가 설정되었는지 확인
    static func validateKeys() -> (isValid: Bool, message: String) {
        if openAI == "YOUR_OPENAI_API_KEY_HERE" {
            return (false, "ChatGPT API 키가 설정되지 않았습니다.")
        }
        
        if openAI.isEmpty {
            return (false, "API 키가 비어있습니다.")
        }
        
        return (true, "API 키가 설정되었습니다.")
    }
}

// MARK: - ChatGPT Service
/// ChatGPT API 통신 서비스
class ChatGPTService: ObservableObject {
    
    private let logger = Logger(subsystem: "AINO", category: "ChatGPTService")
    
    /// 메시지 전송 및 응답 받기
    func sendMessage(_ message: String) async throws -> String {
        logger.info("ChatGPT API 요청 시작: \(message.prefix(50))...")
        
        // API 키 검증
        let validation = APIKeys.validateKeys()
        guard validation.isValid else {
            logger.error("API 키 검증 실패: \(validation.message)")
            throw ChatGPTError.invalidAPIKey(validation.message)
        }
        
        // API 요청 구성
        guard let url = URL(string: APIKeys.openAIEndpoint) else {
            logger.error("잘못된 API URL: \(APIKeys.openAIEndpoint)")
            throw ChatGPTError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(APIKeys.openAI)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30.0
        
        // 요청 바디 구성 (비용 최적화 설정 적용)
        let requestBody = ChatGPTRequest(
            model: APIKeys.openAIModel,
            messages: [
                ChatGPTMessage(role: "system", content: APIKeys.OpenAIConfig.systemPrompt),
                ChatGPTMessage(role: "user", content: message)
            ],
            max_tokens: APIKeys.OpenAIConfig.maxTokens,
            temperature: APIKeys.OpenAIConfig.temperature
        )
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            logger.error("요청 바디 인코딩 실패: \(error.localizedDescription)")
            throw ChatGPTError.encodingFailed
        }
        
        // API 호출
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("잘못된 HTTP 응답")
                throw ChatGPTError.invalidResponse
            }
            
            logger.info("HTTP 상태 코드: \(httpResponse.statusCode)")
            
            switch httpResponse.statusCode {
            case 200:
                break
            case 401:
                logger.error("API 키 인증 실패")
                throw ChatGPTError.authenticationFailed
            case 429:
                logger.error("API 사용량 한도 초과")
                throw ChatGPTError.rateLimitExceeded
            case 500...599:
                logger.error("서버 오류: \(httpResponse.statusCode)")
                throw ChatGPTError.serverError
            default:
                logger.error("예상치 못한 상태 코드: \(httpResponse.statusCode)")
                throw ChatGPTError.requestFailed
            }
            
            do {
                let chatResponse = try JSONDecoder().decode(ChatGPTResponse.self, from: data)
                
                guard let firstChoice = chatResponse.choices.first else {
                    logger.error("응답에서 선택지를 찾을 수 없음")
                    throw ChatGPTError.noContent
                }
                
                let content = firstChoice.message.content
                
                logger.info("ChatGPT 응답 성공: \(content.prefix(50))...")
                return content.trimmingCharacters(in: .whitespacesAndNewlines)
                
            } catch {
                logger.error("응답 파싱 실패: \(error.localizedDescription)")
                throw ChatGPTError.decodingFailed
            }
            
        } catch {
            if error is ChatGPTError {
                throw error
            } else {
                logger.error("네트워크 오류: \(error.localizedDescription)")
                throw ChatGPTError.networkError(error.localizedDescription)
            }
        }
    }
}

// MARK: - 데이터 모델
struct ChatGPTRequest: Codable {
    let model: String
    let messages: [ChatGPTMessage]
    let max_tokens: Int
    let temperature: Double
}

struct ChatGPTMessage: Codable {
    let role: String
    let content: String
}

struct ChatGPTResponse: Codable {
    let choices: [ChatGPTChoice]
    let usage: ChatGPTUsage?
}

struct ChatGPTChoice: Codable {
    let message: ChatGPTMessage
    let finish_reason: String?
}

struct ChatGPTUsage: Codable {
    let prompt_tokens: Int
    let completion_tokens: Int
    let total_tokens: Int
}

// MARK: - 에러 처리
enum ChatGPTError: Error, LocalizedError {
    case invalidAPIKey(String)
    case invalidURL
    case encodingFailed
    case networkError(String)
    case invalidResponse
    case authenticationFailed
    case rateLimitExceeded
    case serverError
    case requestFailed
    case decodingFailed
    case noContent
    
    var errorDescription: String? {
        switch self {
        case .invalidAPIKey(let message):
            return message
        case .invalidURL:
            return "잘못된 API URL입니다."
        case .encodingFailed:
            return "요청 데이터 인코딩에 실패했습니다."
        case .networkError(let message):
            return "네트워크 오류: \(message)"
        case .invalidResponse:
            return "잘못된 서버 응답입니다."
        case .authenticationFailed:
            return "API 키 인증에 실패했습니다. API 키를 확인해주세요."
        case .rateLimitExceeded:
            return "API 사용량 한도를 초과했습니다. 잠시 후 다시 시도해주세요."
        case .serverError:
            return "서버에 일시적인 문제가 발생했습니다. 잠시 후 다시 시도해주세요."
        case .requestFailed:
            return "API 요청에 실패했습니다."
        case .decodingFailed:
            return "응답 데이터 파싱에 실패했습니다."
        case .noContent:
            return "응답에서 내용을 찾을 수 없습니다."
        }
    }
    
    /// 사용자에게 표시할 친화적인 메시지
    var userFriendlyMessage: String {
        switch self {
        case .invalidAPIKey:
            return "AI 기능을 사용할 수 없습니다. 설정을 확인해주세요."
        case .authenticationFailed:
            return "AI 서비스 인증에 실패했습니다."
        case .rateLimitExceeded:
            return "잠시 후 다시 질문해주세요."
        case .networkError:
            return "인터넷 연결을 확인해주세요."
        case .serverError:
            return "AI 서비스에 일시적인 문제가 있습니다."
        default:
            return "질문을 처리할 수 없습니다. 다시 시도해주세요."
        }
    }
}

class QuestionViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var currentMessage = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isAPIKeyValid = false
    
    // 추천질문 관련 상태
    @Published var suggestedQuestions: [String] = []
    @Published var isLoadingSuggestions = false
    @Published var showingSuggestions = false
    
    private let chatGPTService = ChatGPTService()
    private let logger = Logger(subsystem: "AINO", category: "QuestionViewModel")
    
    init() {
        validateAPIKey()
    }
    
    /// API 키 유효성 검사
    private func validateAPIKey() {
        let validation = APIKeys.validateKeys()
        isAPIKeyValid = validation.isValid
        
        if !validation.isValid {
            logger.warning("API 키 검증 실패: \(validation.message)")
        } else {
            logger.info("API 키 검증 성공")
        }
    }
    
    /// 메시지 전송 및 ChatGPT 응답 받기
    func sendMessage() {
        guard !currentMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // API 키 유효성 재확인
        guard isAPIKeyValid else {
            showError("AI 기능을 사용할 수 없습니다. API 키를 확인해주세요.")
            return
        }
        
        let userMessage = ChatMessage(text: currentMessage, isUser: true)
        messages.append(userMessage)
        
        let messageToSend = currentMessage
        currentMessage = ""
        isLoading = true
        errorMessage = nil
        
        logger.info("사용자 질문 전송: \(messageToSend.prefix(50))...")
        
        Task {
            do {
                let response = try await chatGPTService.sendMessage(messageToSend)
                
                await MainActor.run {
                    let aiMessage = ChatMessage(text: response, isUser: false)
                    self.messages.append(aiMessage)
                    self.isLoading = false
                    self.logger.info("ChatGPT 응답 수신 완료")
                }
            } catch let error as ChatGPTError {
                await MainActor.run {
                    self.showError(error.userFriendlyMessage)
                    self.logger.error("ChatGPT 오류: \(error.localizedDescription)")
                }
            } catch {
                await MainActor.run {
                    self.showError("예상치 못한 오류가 발생했습니다.")
                    self.logger.error("예상치 못한 오류: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// 에러 메시지 표시
    private func showError(_ message: String) {
        isLoading = false
        errorMessage = message
        
        // 에러 메시지를 채팅에도 추가
        let errorChatMessage = ChatMessage(
            text: "⚠️ \(message)",
            isUser: false
        )
        messages.append(errorChatMessage)
    }
    
    /// 메시지 목록 초기화
    func clearMessages() {
        messages.removeAll()
        errorMessage = nil
        logger.info("채팅 메시지 초기화")
    }
    
    /// 에러 메시지 초기화
    func clearError() {
        errorMessage = nil
    }
    
    /// API 키 재검증
    func refreshAPIKey() {
        validateAPIKey()
    }
    
    /// 추천질문 생성
    func generateSuggestions(context: String = "", keyword: String? = nil) {
        guard isAPIKeyValid else {
            showError("AI 기능을 사용할 수 없습니다. API 키를 확인해주세요.")
            return
        }
        
        isLoadingSuggestions = true
        showingSuggestions = true
        suggestedQuestions = []
        
        let prompt = buildSuggestionPrompt(context: context, keyword: keyword)
        logger.info("추천질문 생성 시작: \(prompt.prefix(100))...")
        
        Task {
            do {
                let response = try await chatGPTService.sendMessage(prompt)
                let questions = parseSuggestedQuestions(response)
                
                await MainActor.run {
                    self.suggestedQuestions = questions
                    self.isLoadingSuggestions = false
                    self.logger.info("추천질문 생성 완료: \(questions.count)개")
                }
            } catch {
                await MainActor.run {
                    self.isLoadingSuggestions = false
                    self.logger.error("추천질문 생성 실패: \(error.localizedDescription)")
                    // 실패 시 기본 질문 제공
                    self.suggestedQuestions = self.getDefaultSuggestions(keyword: keyword)
                }
            }
        }
    }
    
    /// 추천질문 프롬프트 생성
    private func buildSuggestionPrompt(context: String, keyword: String?) -> String {
        var prompt = """
        학습 도우미로서 다음 상황에 맞는 질문 3개를 생성해주세요.
        각 질문은 한 줄로, 번호 없이 작성해주세요.
        질문은 구체적이고 학습에 도움이 되어야 합니다.
        
        """
        
        if let keyword = keyword, !keyword.isEmpty {
            prompt += "키워드: \(keyword)\n"
        }
        
        if !context.isEmpty {
            prompt += "학습 내용: \(context.prefix(200))\n"
        }
        
        prompt += """
        
        형식:
        이 개념을 실생활에서 어떻게 활용할 수 있나요?
        이 내용의 핵심 포인트는 무엇인가요?
        관련된 다른 개념과의 차이점은 무엇인가요?
        """
        
        return prompt
    }
    
    /// 응답에서 질문 파싱
    private func parseSuggestedQuestions(_ response: String) -> [String] {
        let lines = response.components(separatedBy: .newlines)
        let questions = lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.contains("?") }
            .prefix(3)
        
        return Array(questions)
    }
    
    /// 기본 추천질문 (API 실패 시)
    private func getDefaultSuggestions(keyword: String?) -> [String] {
        if let keyword = keyword {
            return [
                "\(keyword)에 대해 더 자세히 설명해주세요.",
                "\(keyword)의 실제 활용 사례는 무엇인가요?",
                "\(keyword)와 관련된 중요한 개념은 무엇인가요?"
            ]
        } else {
            return [
                "이 내용의 핵심 포인트는 무엇인가요?",
                "실생활에서 어떻게 활용할 수 있나요?",
                "더 깊이 이해하려면 무엇을 공부해야 하나요?"
            ]
        }
    }
    
    /// 추천질문 선택 및 자동 전송
    func selectSuggestion(_ question: String) {
        currentMessage = question
        showingSuggestions = false
        logger.info("추천질문 선택 및 자동 전송: \(question.prefix(50))...")
        
        // 잠시 후 자동으로 전송
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.sendMessage()
        }
    }
    
    /// 추천질문 시트 닫기
    func closeSuggestions() {
        showingSuggestions = false
    }
}

