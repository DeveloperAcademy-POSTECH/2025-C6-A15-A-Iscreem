//
//  CaptionAnalyzerKeywords.swift
//  learningTool
//
//  Created by coulson on 10/20/25.
//

import Foundation

extension CaptionAnalyzer {

    // MARK: - 불용어 제거
    private func preprocess(_ text: String) -> [String] {
        let stopwords = ["을","를","이","가","과","와","에","의","하다","습니다","그리고","특히","등","같은","에서","으로","한","수"]
        let words = text
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !stopwords.contains($0) }
        return words
    }

    // MARK: - 전체 요약 기반 키워드 추출
    func extractKeywords(topN: Int = 10) -> [String] {
        let words = preprocess(finalSummary)
        guard !words.isEmpty else { return [] }

        // 단어 빈도 계산
        var freq: [String: Int] = [:]
        for word in words { freq[word, default: 0] += 1 }

        // 상위 N개 단어 추출
        let sorted = freq.sorted { $0.value > $1.value }
        let keywords = sorted.prefix(topN).map { $0.key }
        return keywords
    }
}
