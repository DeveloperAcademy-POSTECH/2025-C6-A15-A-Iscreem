//
//  GeminiAPIService.swift
//  learningtool
//
//  Created by AI Assistant on 10/21/25.
//

import Foundation

class GeminiAPIService {
    static let shared = GeminiAPIService()
    
    private let apiKeyKey = "GeminiAPIKey"
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"
    
    /// API 키 변경 알림
    static let apiKeyDidChangeNotification = Notification.Name("GeminiAPIKeyDidChange")
    
    private init() {}
    
    /// API 키 저장
    func saveAPIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: apiKeyKey)
        NotificationCenter.default.post(name: GeminiAPIService.apiKeyDidChangeNotification, object: nil)
    }
    
    /// API 키 가져오기
    func getAPIKey() -> String? {
        return UserDefaults.standard.string(forKey: apiKeyKey)
    }
    
    /// API 키 삭제
    func deleteAPIKey() {
        UserDefaults.standard.removeObject(forKey: apiKeyKey)
        NotificationCenter.default.post(name: GeminiAPIService.apiKeyDidChangeNotification, object: nil)
    }
    
    /// API 키 설정 여부 확인
    func isAPIKeyConfigured() -> Bool {
        guard let key = getAPIKey() else { return false }
        return !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Gemini API에 메시지 전송
    func sendMessage(_ message: String, conversationHistory: [ChatMessage] = []) async throws -> String {
        guard let apiKey = getAPIKey(), !apiKey.isEmpty else {
            throw GeminiAPIError.noAPIKey
        }
        
        // URL 구성
        guard var urlComponents = URLComponents(string: baseURL) else {
            throw GeminiAPIError.invalidURL
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "key", value: apiKey)
        ]
        
        guard let url = urlComponents.url else {
            throw GeminiAPIError.invalidURL
        }
        
        // 대화 히스토리를 포함한 요청 바디 구성
        var contents: [[String: Any]] = []
        
        // 이전 대화 히스토리 추가 (최근 10개만)
        let recentHistory = conversationHistory.suffix(10)
        for msg in recentHistory {
            contents.append([
                "role": msg.isUser ? "user" : "model",
                "parts": [
                    ["text": msg.text]
                ]
            ])
        }
        
        // 현재 메시지 추가
        contents.append([
            "role": "user",
            "parts": [
                ["text": message]
            ]
        ])
        
        let requestBody: [String: Any] = [
            "contents": contents,
            "generationConfig": [
                "temperature": 0.7,
                "topK": 40,
                "topP": 0.95,
                "maxOutputTokens": 8192,  // 토큰 제한 증가 (Gemini 2.5는 내부 추론에도 토큰 사용)
            ]
        ]
        
        // HTTP 요청 생성
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // API 호출
        print("🌐 [GeminiAPI] URLSession.data 호출 중...")
        let (data, response) = try await URLSession.shared.data(for: request)
        print("🌐 [GeminiAPI] 응답 받음 - 데이터 크기: \(data.count) bytes")
        
        // 응답 처리
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [GeminiAPI] HTTPURLResponse 변환 실패")
            throw GeminiAPIError.invalidResponse
        }
        
        print("🌐 [GeminiAPI] HTTP 상태 코드: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            print("❌ [GeminiAPI] HTTP 에러 - 상태 코드: \(httpResponse.statusCode)")
            // 에러 응답 파싱
            if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorResponse["error"] as? [String: Any],
               let message = error["message"] as? String {
                print("❌ [GeminiAPI] API 에러 메시지: \(message)")
                throw GeminiAPIError.apiError(message)
            }
            // 원시 데이터 출력
            if let rawString = String(data: data, encoding: .utf8) {
                print("❌ [GeminiAPI] 에러 응답 원시 데이터: \(rawString)")
            }
            throw GeminiAPIError.httpError(httpResponse.statusCode)
        }
        
        // 원시 JSON 데이터 출력
        if let rawString = String(data: data, encoding: .utf8) {
            print("📦 [GeminiAPI] 응답 원시 데이터: \(rawString.prefix(500))...")
        }
        
        // 성공 응답 파싱 - 단계별 검증
        print("🔍 [GeminiAPI] JSON 파싱 시작")
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("❌ [GeminiAPI] JSON 직렬화 실패")
            throw GeminiAPIError.parseError
        }
        print("✅ [GeminiAPI] JSON 파싱 성공 - 키: \(json.keys.joined(separator: ", "))")
        
        guard let candidates = json["candidates"] as? [[String: Any]] else {
            print("❌ [GeminiAPI] candidates 추출 실패")
            print("   JSON 구조: \(json)")
            throw GeminiAPIError.parseError
        }
        print("✅ [GeminiAPI] candidates 추출 성공 - 개수: \(candidates.count)")
        
        guard let firstCandidate = candidates.first else {
            print("❌ [GeminiAPI] firstCandidate 없음")
            throw GeminiAPIError.parseError
        }
        print("✅ [GeminiAPI] firstCandidate 추출 성공 - 키: \(firstCandidate.keys.joined(separator: ", "))")
        
        guard let content = firstCandidate["content"] as? [String: Any] else {
            print("❌ [GeminiAPI] content 추출 실패")
            print("   firstCandidate 구조: \(firstCandidate)")
            throw GeminiAPIError.parseError
        }
        print("✅ [GeminiAPI] content 추출 성공 - 키: \(content.keys.joined(separator: ", "))")
        
        // parts가 없는 경우 처리 (MAX_TOKENS 등으로 응답이 잘린 경우)
        guard let parts = content["parts"] as? [[String: Any]] else {
            print("⚠️ [GeminiAPI] parts 없음 - finishReason 확인")
            if let finishReason = firstCandidate["finishReason"] as? String {
                print("⚠️ [GeminiAPI] finishReason: \(finishReason)")
                if finishReason == "MAX_TOKENS" {
                    print("❌ [GeminiAPI] 토큰 제한 초과 - maxOutputTokens를 늘려야 함")
                    throw GeminiAPIError.apiError("토큰 제한 초과: 응답이 너무 짧습니다. maxOutputTokens를 증가시켜주세요.")
                }
            }
            print("   content 구조: \(content)")
            throw GeminiAPIError.parseError
        }
        print("✅ [GeminiAPI] parts 추출 성공 - 개수: \(parts.count)")
        
        guard let firstPart = parts.first else {
            print("❌ [GeminiAPI] firstPart 없음")
            throw GeminiAPIError.parseError
        }
        print("✅ [GeminiAPI] firstPart 추출 성공 - 키: \(firstPart.keys.joined(separator: ", "))")
        
        guard let text = firstPart["text"] as? String else {
            print("❌ [GeminiAPI] text 추출 실패")
            print("   firstPart 구조: \(firstPart)")
            throw GeminiAPIError.parseError
        }
        
        print("✅ [GeminiAPI] 최종 텍스트 추출 성공 - 길이: \(text.count)자")
        print("✅ [GeminiAPI] 텍스트 내용: \(text.prefix(200))...")
        
        return text
    }
}

/// Gemini API 에러 타입
enum GeminiAPIError: LocalizedError {
    case noAPIKey
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    case parseError
    
    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "API 키가 설정되지 않았습니다. 설정에서 API 키를 입력해주세요."
        case .invalidURL:
            return "잘못된 URL입니다."
        case .invalidResponse:
            return "서버 응답이 올바르지 않습니다."
        case .httpError(let code):
            return "HTTP 에러: \(code)"
        case .apiError(let message):
            return "API 에러: \(message)"
        case .parseError:
            return "응답을 파싱하는데 실패했습니다."
        }
    }
}

