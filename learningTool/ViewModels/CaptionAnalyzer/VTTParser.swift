//
//  VTTParser.swift
//  learningTool
//
//  Created by 이혜빈 on 11/4/25.
//

import Foundation
#if os(iOS)
import UIKit
#endif

/// VTT/JSON3/TimedText XML 자막 파싱 유틸리티
enum VTTParser {
    
    static func fetchFromBaseUrl(_ baseUrl: String) async throws -> [CaptionAnalyzer.VTTCue] {
        #if os(iOS)
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        if isPhone {
            // iPhone: 새로운(오늘 추가된) 정규화/보정 로직
            //  - HTML 엔티티(&amp;) 정리
            //  - //로 시작하면 https: 접두
            //  - /api…, api/timedtext… 상대 경로 → https://www.youtube.com 붙이기
            let normalized = normalizeBaseUrl(baseUrl)
            print("fetchFromBaseUrl: normalized=\(normalized)")
            
            guard normalized.lowercased().hasPrefix("http") else {
                throw NSError(domain: "VTT", code: -11, userInfo: [NSLocalizedDescriptionKey: "잘못된 자막 URL"])
            }
            
            // 1) 그대로 시도
            if let url = URL(string: normalized) {
                if let cues = try? await _downloadAndParse(url: url) { return cues }
            }
            
            // 2) fmt 강제 변경 시도 (존재하면 교체, 없으면 추가)
            func withParam(_ key: String, _ val: String) -> URL? {
                guard var c = URLComponents(string: normalized) else { return nil }
                var items = c.queryItems ?? []
                if let idx = items.firstIndex(where: { $0.name == key }) {
                    items[idx] = .init(name: key, value: val)
                } else {
                    items.append(.init(name: key, value: val))
                }
                c.queryItems = items
                return c.url
            }
            
            print("fetchFromBaseUrl: trying fmt=vtt")
            if let u1 = withParam("fmt", "vtt"), let cues = try? await _downloadAndParse(url: u1) { return cues }
            
            print("fetchFromBaseUrl: trying fmt=json3")
            if let u2 = withParam("fmt", "json3"), let cues = try? await _downloadAndParse(url: u2) { return cues }
            
            print("fetchFromBaseUrl: trying fmt=srv3")
            if let u3 = withParam("fmt", "srv3"), let cues = try? await _downloadAndParse(url: u3) { return cues }
            
            throw NSError(domain: "VTT", code: -9, userInfo: [NSLocalizedDescriptionKey: "서명된 자막 URL에서 데이터를 가져오지 못했습니다."])
        } else {
            // iPad: 이전(기존에 잘 동작하던) 로직 유지
            print("fetchFromBaseUrl: trying raw baseUrl=\(baseUrl)")
            
            guard baseUrl.lowercased().hasPrefix("http") else {
                throw NSError(domain: "VTT", code: -11, userInfo: [NSLocalizedDescriptionKey: "잘못된 자막 URL"])
            }
            
            // 1) 그대로 시도
            if let url = URL(string: baseUrl) {
                if let cues = try? await _downloadAndParse(url: url) { return cues }
            }
            
            // 2) fmt 강제 변경 시도 (기존 방식: 없으면 추가, 있으면 교체)
            func withParam(_ key: String, _ val: String) -> URL? {
                guard var c = URLComponents(string: baseUrl) else { return nil }
                var items = c.queryItems ?? []
                if !items.contains(where: { $0.name == key }) {
                    items.append(.init(name: key, value: val))
                } else {
                    items = items.map { $0.name == key ? .init(name: key, value: val) : $0 }
                }
                c.queryItems = items
                return c.url
            }
            
            print("fetchFromBaseUrl: trying fmt=vtt")
            if let u1 = withParam("fmt", "vtt"), let cues = try? await _downloadAndParse(url: u1) { return cues }
            
            print("fetchFromBaseUrl: trying fmt=json3")
            if let u2 = withParam("fmt", "json3"), let cues = try? await _downloadAndParse(url: u2) { return cues }
            
            print("fetchFromBaseUrl: trying fmt=srv3")
            if let u3 = withParam("fmt", "srv3"), let cues = try? await _downloadAndParse(url: u3) { return cues }
            
            throw NSError(domain: "VTT", code: -9, userInfo: [NSLocalizedDescriptionKey: "서명된 자막 URL에서 데이터를 가져오지 못했습니다."])
        }
        #else
        // 기타 플랫폼: iPad(이전) 로직과 동일하게 동작
        print("fetchFromBaseUrl: trying raw baseUrl=\(baseUrl)")
        
        guard baseUrl.lowercased().hasPrefix("http") else {
            throw NSError(domain: "VTT", code: -11, userInfo: [NSLocalizedDescriptionKey: "잘못된 자막 URL"])
        }
        
        if let url = URL(string: baseUrl) {
            if let cues = try? await _downloadAndParse(url: url) { return cues }
        }
        
        func withParam(_ key: String, _ val: String) -> URL? {
            guard var c = URLComponents(string: baseUrl) else { return nil }
            var items = c.queryItems ?? []
            if !items.contains(where: { $0.name == key }) {
                items.append(.init(name: key, value: val))
            } else {
                items = items.map { $0.name == key ? .init(name: key, value: val) : $0 }
            }
            c.queryItems = items
            return c.url
        }
        
        print("fetchFromBaseUrl: trying fmt=vtt")
        if let u1 = withParam("fmt", "vtt"), let cues = try? await _downloadAndParse(url: u1) { return cues }
        
        print("fetchFromBaseUrl: trying fmt=json3")
        if let u2 = withParam("fmt", "json3"), let cues = try? await _downloadAndParse(url: u2) { return cues }
        
        print("fetchFromBaseUrl: trying fmt=srv3")
        if let u3 = withParam("fmt", "srv3"), let cues = try? await _downloadAndParse(url: u3) { return cues }
        
        throw NSError(domain: "VTT", code: -9, userInfo: [NSLocalizedDescriptionKey: "서명된 자막 URL에서 데이터를 가져오지 못했습니다."])
        #endif
    }
    
    /// YouTube captionTracks.baseUrl 정규화
    /// - "&amp;" → "&"
    /// - 따옴표/공백 제거
    /// - //로 시작 → https: 접두
    /// - /api… 또는 api/timedtext… → https://www.youtube.com 접두
    private static func normalizeBaseUrl(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // 따옴표 래핑 제거
        if (s.hasPrefix("\"") && s.hasSuffix("\"")) || (s.hasPrefix("'") && s.hasSuffix("'")) {
            s = String(s.dropFirst().dropLast())
        }
        // HTML 엔티티 치환
        s = s.replacingOccurrences(of: "&amp;", with: "&")
        
        // 프로토콜 상대 → https:
        if s.hasPrefix("//") {
            s = "https:" + s
        }
        
        // 경로 상대 → www.youtube.com 붙이기
        if s.hasPrefix("/api/") || s.hasPrefix("/timedtext") {
            s = "https://www.youtube.com" + s
        } else if s.lowercased().hasPrefix("api/") || s.lowercased().hasPrefix("timedtext") {
            s = "https://www.youtube.com/" + s
        }
        return s
    }
    
    private static func _downloadAndParse(url: URL) async throws -> [CaptionAnalyzer.VTTCue] {
        let (data, _) = try await URLSession.shared.data(from: url)
        print("_downloadAndParse: url=\(url.absoluteString)")
        
        if let text = String(data: data, encoding: .utf8) {
            if text.contains("WEBVTT") {
                print("_downloadAndParse: detected WEBVTT")
                return parseWebVTT(text)
            }
            
            var raw = text
            if raw.hasPrefix(")]}'") {
                if let nl = raw.firstIndex(of: "\n") { raw = String(raw[raw.index(after: nl)...]) }
            }
            if let jd = raw.data(using: .utf8),
               let cues = try? _parseJSON3(jd) {
                print("_downloadAndParse: detected JSON3/SRV3")
                return cues
            }
        }
        
        if let cues = _parseTimedTextXML(data) {
            print("_downloadAndParse: detected TimedText XML")
            return cues
        }
        
        throw NSError(domain: "VTT", code: -10,
                      userInfo: [NSLocalizedDescriptionKey: "알 수 없는 자막 포맷입니다."])
    }
    
    static func parseWebVTT(_ vtt: String) -> [CaptionAnalyzer.VTTCue] {
        var lines = vtt.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n").components(separatedBy: "\n")
        if let first = lines.first, first.uppercased().contains("WEBVTT") {
            lines.removeFirst()
        }
        
        var cues: [CaptionAnalyzer.VTTCue] = []
        var i = 0
        
        func parseTime(_ s: String) -> Double? {
            let ss = s.trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: ",", with: ".")
            let parts = ss.split(separator: ":").map(String.init)
            guard parts.count >= 2 else { return nil }
            let h: Double
            let m: Double
            let secStr: String
            if parts.count == 3 {
                h = Double(parts[0]) ?? 0
                m = Double(parts[1]) ?? 0
                secStr = parts[2]
            } else {
                h = 0
                m = Double(parts[0]) ?? 0
                secStr = parts[1]
            }
            let secParts = secStr.split(whereSeparator: { $0 == "." || $0 == "," }).map(String.init)
            let sVal = Double(secParts.first ?? "0") ?? 0
            let fracStr = secParts.count > 1 ? secParts[1] : "0"
            let frac = Double("0." + fracStr) ?? 0
            return h * 3600 + m * 60 + sVal + frac
        }
        
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.isEmpty { i += 1; continue }
            
            var tline = line
            if !tline.contains("-->"), i + 1 < lines.count, lines[i + 1].contains("-->") {
                i += 1
                tline = lines[i]
            }
            if tline.contains("-->") {
                let comps = tline.components(separatedBy: "-->")
                if comps.count == 2, let start = parseTime(comps[0].trimmingCharacters(in: .whitespaces)),
                   let end = parseTime(comps[1].split(separator: " ").first.map(String.init) ?? "") {
                    i += 1
                    var textLines: [String] = []
                    while i < lines.count {
                        let l = lines[i]
                        if l.trimmingCharacters(in: .whitespaces).isEmpty { break }
                        textLines.append(l)
                        i += 1
                    }
                    let text = textLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    cues.append(CaptionAnalyzer.VTTCue(start: start, end: end, text: text))
                }
            }
            i += 1
        }
        return cues
    }
    
    private static func _parseJSON3(_ data: Data) throws -> [CaptionAnalyzer.VTTCue] {
        struct JSON3: Decodable {
            struct Seg: Decodable { let utf8: String? }
            struct Event: Decodable {
                let tStartMs: Int?
                let dDurationMs: Int?
                let segs: [Seg]?
            }
            let events: [Event]?
        }
        let json = try JSONDecoder().decode(JSON3.self, from: data)
        var cues: [CaptionAnalyzer.VTTCue] = []
        for ev in json.events ?? [] {
            let start = Double(ev.tStartMs ?? 0) / 1000.0
            let dur = Double(ev.dDurationMs ?? 0) / 1000.0
            let end = start + (dur > 0 ? dur : 2.0)
            let text = (ev.segs ?? []).compactMap { $0.utf8 }.joined().trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { cues.append(CaptionAnalyzer.VTTCue(start: start, end: end, text: text)) }
        }
        return cues
    }
    
    private final class TimedTextXMLParser: NSObject, XMLParserDelegate {
        var cues: [CaptionAnalyzer.VTTCue] = []
        private var currText: String = ""
        private var currStart: Double = 0
        private var currDur: Double = 0
        
        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
            if elementName == "text" {
                currText = ""
                currStart = Double(attributeDict["start"] ?? "0") ?? 0
                currDur = Double(attributeDict["dur"] ?? "0") ?? 0
            }
        }
        
        func parser(_ parser: XMLParser, foundCharacters string: String) {
            currText += string
        }
        
        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            if elementName == "text" {
                let end = currStart + (currDur > 0 ? currDur : 2.0)
                let text = currText.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    cues.append(CaptionAnalyzer.VTTCue(start: currStart, end: end, text: text))
                }
            }
        }
    }
    
    private static func _parseTimedTextXML(_ data: Data) -> [CaptionAnalyzer.VTTCue]? {
        let p = TimedTextXMLParser()
        let parser = XMLParser(data: data)
        parser.delegate = p
        guard parser.parse(), !p.cues.isEmpty else { return nil }
        return p.cues
    }
}
