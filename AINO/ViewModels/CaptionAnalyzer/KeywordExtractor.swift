//
//  KeywordExtractor.swift
//  learningTool
//
//  Created by 이혜빈 on 11/4/25.
//

import Foundation
import NaturalLanguage
import OSLog

/// 텍스트에서 키워드를 추출하는 엔진
final class KeywordExtractor {
    private let log: Logger
    
    init(logger: Logger) {
        self.log = logger
    }
    
    // MARK: - 챕터별 키워드 추출 (요약 기반)
    /// ✅ 요약된 텍스트를 기반으로 핵심 키워드를 추출합니다
    func extractChapterKeywords(
        from summaryText: String,  // ✅ 원본이 아닌 요약 텍스트 사용
        summarizer: Summarizer?
    ) async -> [String] {
        print("🟦 extractChapterKeywords called, summaryText length=\(summaryText.count)")
        
        var candidateKeywords: [String] = []
        
        if #available(iOS 26.0, *), let summarizer = summarizer {
            do {
                let rawKeywords = try await summarizer.summarizeChunk(
                    text: summaryText,
                    instruction: """
                    요약 텍스트에서 가장 핵심적인 명사 키워드를 **정확히 10개만** 추출하세요.
                    
                    **규칙:**
                    1. 명사만 추출 (동사, 형용사, 조사, 부사 제외)
                    2. 주제의 핵심 개념을 나타내는 전문 용어 우선
                    3. 전문용어, 고유명사, 약어는 원문 그대로 정확히 유지 (예: 컴활, DBMS, Swift, API, SQL)
                    4. 한글 용어 우선, 영어는 기술 용어만 (Swift, API, SQL, JSON, HTTP)
                    5. 정확히 10개만 쉼표로 구분하여 출력 (번호나 불릿 없이)
                    
                    **좋은 예시:**
                    데이터베이스, 테이블, 설계, 정규화, SQL, DBMS, 관계형 모델, 트랜잭션, 인덱스, 쿼리 최적화
                    
                    **제외할 단어:**
                    방법, 기능, 사용, 학습, 내용, 설명, 과정, 단계, 중요, 필요
                    """
                )
                candidateKeywords = rawKeywords
                    .components(separatedBy: CharacterSet(charactersIn: ".,;、/\n\t "))
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            } catch {
                candidateKeywords = summaryText.components(separatedBy: .whitespacesAndNewlines)
            }
        } else {
            candidateKeywords = summaryText.components(separatedBy: .whitespacesAndNewlines)
        }
        
        print("🟦 candidateKeywords count=\(candidateKeywords.count), preview=\(candidateKeywords.prefix(20))")
        
        // ✅ 강화된 전처리: 오타 보정
        let preprocessed = preprocessKeywords(candidateKeywords)
        print("🟧 preprocessed keywords count=\(preprocessed.count), preview=\(preprocessed.prefix(20))")
        
        // 정규식 및 불용어 기반 정제
        let refined = refineKeywords(preprocessed)
        print("🟨 refined keywords count=\(refined.count), preview=\(refined.prefix(20))")
        
        // 중복 제거, 순서 유지
        var seen: Set<String> = []
        let unique = refined.filter { seen.insert($0).inserted }
        
        // ✅ 정확히 10개로 제한
        let finalKeywords = Array(unique.prefix(10))
        
        print("✅ Final keywords (limited to 10): \(finalKeywords)")
        return finalKeywords
    }
    
    // MARK: - 최종 요약 기반 키워드 추출 (빈도 기반)
    func extractKeywords(from text: String, topN: Int = 10) -> [String] {
        let tokens = preprocessForFrequency(text)
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return [] }
        
        var freq: [String: Int] = [:]
        for token in tokens {
            freq[token, default: 0] += 1
        }
        
        let sorted = freq.sorted { $0.value > $1.value }.map { $0.key }
        
        // 포함 관계 필터링
        var filtered: [String] = []
        for word in sorted {
            if !filtered.contains(where: { $0.contains(word) && $0 != word }) {
                filtered.append(word)
            }
        }
        
        return Array(filtered.prefix(topN))
    }
    
    // MARK: - 컨텍스트 기반 키워드 추출 (NLEmbedding 활용)
    @MainActor
    func extractChapterKeywordsContextual(from text: String) async -> [String] {
        guard !text.isEmpty else { return [] }
        
        let cleanedText = preprocessForFrequency(text)
        guard !cleanedText.isEmpty else { return [] }
        
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])
        tagger.string = cleanedText
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]
        var candidateWords: [String: Int] = [:]
        
        tagger.enumerateTags(in: cleanedText.startIndex..<cleanedText.endIndex, unit: .word, scheme: .lexicalClass, options: options) { tag, tokenRange in
            if let tag = tag, tag == .noun {
                let word = String(cleanedText[tokenRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                guard word.count > 1 else { return true }
                candidateWords[word, default: 0] += 1
            }
            return true
        }
        
        tagger.enumerateTags(in: cleanedText.startIndex..<cleanedText.endIndex, unit: .word, scheme: .nameType, options: options) { tag, tokenRange in
            if let tag = tag, tag == .personalName || tag == .placeName || tag == .organizationName {
                let word = String(cleanedText[tokenRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                guard word.count > 1 else { return true }
                candidateWords[word, default: 0] += 2
            }
            return true
        }
        
        guard !candidateWords.isEmpty else { return [] }
        
        var wordScores: [(word: String, score: Double)] = []
        
        if let embedding = NLEmbedding.wordEmbedding(for: .korean) {
            let allWords = cleanedText.components(separatedBy: .whitespacesAndNewlines)
            let textVectors = allWords.compactMap { embedding.vector(for: $0) }
            let textVector: [Double]
            if !textVectors.isEmpty {
                let dim = textVectors.first!.count
                textVector = (0..<dim).map { i in
                    textVectors.map { $0[i] }.reduce(0, +) / Double(textVectors.count)
                }
            } else {
                textVector = []
            }
            
            for (word, freq) in candidateWords {
                if let vec = embedding.vector(for: word), !textVector.isEmpty {
                    let sim = cosineSimilarity(vec1: vec, vec2: textVector)
                    let freqNorm = min(Double(freq) / 5.0, 1.0)
                    let score = sim * 0.7 + freqNorm * 0.3
                    wordScores.append((word, score))
                } else {
                    let freqNorm = min(Double(freq) / 5.0, 1.0)
                    wordScores.append((word, freqNorm * 0.3))
                }
            }
        } else {
            for (word, freq) in candidateWords {
                wordScores.append((word, Double(freq)))
            }
        }
        
        let sorted = wordScores.sorted { $0.score > $1.score || ($0.score == $1.score && $0.word < $1.word) }
        
        var filtered: [String] = []
        for (word, _) in sorted {
            if !filtered.contains(where: { $0.contains(word) && $0 != word }) {
                filtered.append(word)
            }
        }
        
        return Array(filtered.prefix(8))
    }
    
    // MARK: - Private Helpers
    
    /// ✅ 오타 보정 및 유사 단어 통합
    private func preprocessKeywords(_ candidates: [String]) -> [String] {
        // 일반적인 오타 패턴 보정 사전
        let typoCorrections: [String: String] = [
            "코마": "컴활",
            "데타": "데이터",
            "프로그램잉": "프로그래밍",
            "알고리듬": "알고리즘",
            "데이타베이스": "데이터베이스",
            "데이타": "데이터",
            "프레임웍": "프레임워크",
            "어플리케이션": "애플리케이션",
            "엘고리즘": "알고리즘",
            "프로그램밍": "프로그래밍",
            "디비": "DB",
            "에스큐엘": "SQL",
            "디비엠에스": "DBMS",
            "에이피아이": "API",
            "제이슨": "JSON",
            "에이치티티피": "HTTP",
            // 필요시 추가
        ]
        
        return candidates.map { word in
            typoCorrections[word] ?? word
        }
    }
    
    /// ✅ 강화된 키워드 정제: 명사만 남기고 조사·형용사·동사·설명어 제거
    private func refineKeywords(_ candidates: [String]) -> [String] {
        // ✅ 강화된 불용어: 조사, 형용사, 동사, 설명하는 말들
        let stopwords: Set<String> = [
            // 조사
            "이","그","저","것","등","및","의","에","를","을","로","에서","으로","와","과","도","는","은","가","이다",
            "께서","만","부터","까지","마저","조차","밖에","뿐","처럼","같이","대로",
            
            // 접속사
            "그리고","그러나","그러면서","그런데","또는","또","또한","하지만","만약","즉","혹은","때문에","위해",
            
            // 지시어
            "중","각","모든","이런","그런","저런","이러한","저러한","다음","위","아래",
            
            // ✅ 설명하는 일반 명사 (핵심이 아님)
            "방법","기능","사용","학습","내용","설명","이해","개념","의미","정의","특징","종류","형태","과정","단계",
            "결과","영향","효과","목적","원리","구조","시스템","요소","부분","전체","일부","예시","경우","상황",
            "문제","해결","분석","평가","비교","차이","관계","연결","적용","활용","구현","개발","제공","지원",
            "준비","계획","실행","진행","완료","시작","끝","처음","마지막","다음","이전","현재","미래","과거",
            
            // ✅ 형용사 (설명하는 말)
            "중요한","필요한","다양한","여러","주요한","기본적인","핵심적인","일반적인","특별한","구체적인",
            "추상적인","복잡한","간단한","쉬운","어려운","좋은","나쁜","큰","작은","많은","적은","새로운","오래된",
            
            // ✅ 동사형 (하다, 되다 등)
            "하다","되다","있다","없다","이다","아니다","하는","되는","있는","없는","한","된","있고","되고",
            "합니다","있습니다","됩니다","해야","같습니다","있어요","입니다","해요","하며","하면서","하지만",
            
            // 영어 불용어
            "the","and","or","of","to","in","on","for","with","a","an","is","are","was","were","be","been","being",
            "this","that","these","those","it","its","at","by","as","from","but","about","into","over","after","so",
            "method","function","use","usage","learning","content","description","understanding","concept","meaning",
            "definition","feature","type","form","process","step","result","effect","purpose","principle","structure",
            "system","element","part","whole","example","case","situation","problem","solution","analysis",
            "different","various","several","other","many","much","some","any","every","each","good","bad","important",
            
            // 추가 맥락 없는 단어들
            "통해","대한","위한","따른","관련","필요","중요","다양","여러","주요","기본","핵심","일반","특정","전체"
        ]
        
        // ✅ 정규식: 한국어 어미·조사 패턴 강화
        let koreanSuffixPattern = try! NSRegularExpression(
            pattern: "(듯|하는|되는|적인|하며|같은|하는데|에서|으로|에게|한테|에다|보다|라고|라는|이다|이며|이고)$",
            options: []
        )
        
        // 특수문자 및 따옴표 제거
        let quoteCharacters = CharacterSet(charactersIn: "\"'`")
        let unwantedCharacters = CharacterSet.punctuationCharacters.union(.symbols).union(quoteCharacters)
        
        let refined = candidates
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count > 1 } // 1글자 제거
            .filter { word in
                // 불용어 필터 (대소문자 무시)
                !stopwords.contains(word.lowercased())
            }
            .filter { word in
                // 어미·조사 패턴 필터
                let range = NSRange(location: 0, length: word.utf16.count)
                return koreanSuffixPattern.firstMatch(in: word, options: [], range: range) == nil
            }
            .map { $0.trimmingCharacters(in: unwantedCharacters) } // 특수문자 제거
            .filter { !$0.isEmpty && !stopwords.contains($0.lowercased()) } // 재확인
        
        return refined
    }
    
    /// 빈도 기반 전처리
    private func preprocessForFrequency(_ text: String) -> String {
        let stopwords: Set<String> = [
            "이", "그", "저", "것", "등", "및", "의", "에", "를", "을", "로", "에서", "으로", "와", "과", "도", "는", "은", "가", "한", "하다", "되다", "있다"
        ]
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        let filtered = words.filter { !stopwords.contains($0) }
        return filtered.joined(separator: " ")
    }
    
    /// 코사인 유사도 계산
    private func cosineSimilarity(vec1: [Double], vec2: [Double]) -> Double {
        guard vec1.count == vec2.count, !vec1.isEmpty else { return 0 }
        let dot = zip(vec1, vec2).map(*).reduce(0, +)
        let norm1 = sqrt(vec1.map { $0 * $0 }.reduce(0, +))
        let norm2 = sqrt(vec2.map { $0 * $0 }.reduce(0, +))
        guard norm1 > 0, norm2 > 0 else { return 0 }
        return dot / (norm1 * norm2)
    }
}
