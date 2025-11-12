//
//  AppleFMSummarizer.swift
//  learningTool
//
//  Created by coulson on 10/20/25.
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, *)
final class AppleFMSummarizer: Summarizer {
    private let model: SystemLanguageModel

    init() throws {
        self.model = SystemLanguageModel.default
    }

    private func newSession() throws -> LanguageModelSession {
        // 새 세션을 매 호출마다 생성하여 대화 히스토리가 누적되지 않도록 함
        return LanguageModelSession(model: model)
    }

    func summarizeChunk(text: String, instruction: String) async throws -> String {
        let prompt = """
        지시:
        \(instruction)

        ---
        \(text)
        """
        do {
            let session = try newSession()
            let res = try await session.respond(to: prompt)
            return res.content
        } catch {
            // 일부 환경에서 컨텍스트 윈도 초과 오류가 보고되는 경우, 축약 재시도
            let ns = error as NSError
            if ns.localizedDescription.localizedCaseInsensitiveContains("context window") {
                let compact = String(text.prefix(1200))
                let fallbackPrompt = """
                지시:
                \(instruction)

                ---
                \(compact)
                """
                let session = try newSession()
                let res = try await session.respond(to: fallbackPrompt)
                return res.content
            }
            throw error
        }
    }

    func mergeSummaries(_ pieces: [String]) async throws -> String {
        // 통합 요약도 새 세션 사용
        let joined = pieces.joined(separator: "\n\n• ")
        let prompt = """
        다음 요약 조각들을 중복 없이 6문장 이내 한국어 통합 요약으로 만들어줘:

        • \(joined)
        """
        let session = try newSession()
        let res = try await session.respond(to: prompt)
        return res.content
    }
}
#endif
