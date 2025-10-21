//
//  Summarizer.swift
//  learningTool
//
//  Created by coulson on 10/20/25.
//

import Foundation

// MARK: - Summarizer Protocol

protocol Summarizer {
    /// Summarize a single chunk. `instruction` lets you tailor style/language.
    func summarizeChunk(text: String, instruction: String) async throws -> String
    /// Merge multiple chunk-level summaries into one final summary.
    func mergeSummaries(_ pieces: [String]) async throws -> String
}
