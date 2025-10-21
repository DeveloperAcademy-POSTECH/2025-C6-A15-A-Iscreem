//
//  HTTPSummarizer.swift
//  learningTool
//
//  Created by coulson on 10/20/25.
//

import Foundation

/// Example HTTPSummarizer you can wire to your own backend.
/// Expects POST { "texts": [ ... ], "instruction": "..." } -> { "summaries": [ ... ] } or { "summary": "..." }
struct HTTPSummarizer: Summarizer {
    let endpoint: URL
    func summarizeChunk(text: String, instruction: String) async throws -> String {
        let req = try await Self.postJSON(url: endpoint, payload: ["texts": [text], "instruction": instruction])
        if let arr = req["summaries"] as? [String], let first = arr.first { return first }
        if let one = req["summary"] as? String { return one }
        throw NSError(domain: "Summarizer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
    }
    func mergeSummaries(_ pieces: [String]) async throws -> String {
        let req = try await Self.postJSON(url: endpoint, payload: ["texts": pieces, "instruction": "위 요약들을 통합해 8문장 이내 핵심 요약을 만들어줘. 중복 제거, 결론 강조."])
        if let one = req["summary"] as? String { return one }
        if let arr = req["summaries"] as? [String] { return arr.joined(separator: "\n\n") }
        throw NSError(domain: "Summarizer", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
    }
    private static func postJSON(url: URL, payload: [String: Any]) async throws -> [String: Any] {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // 큰 payload 직렬화가 메인 스레드를 점유하지 않도록 보장
        let bodyData: Data = try await Task.detached(priority: .utility) {
            try JSONSerialization.data(withJSONObject: payload, options: [])
        }.value
        req.httpBody = bodyData
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw NSError(domain: "Summarizer", code: -3, userInfo: [NSLocalizedDescriptionKey: "HTTP error"])
        }
        let obj = try JSONSerialization.jsonObject(with: data, options: [])
        return obj as? [String: Any] ?? [:]
    }
}
