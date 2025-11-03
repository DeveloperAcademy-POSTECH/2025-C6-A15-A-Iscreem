//
//  NoteFormattingUtils.swift
//  learningTool
//
//  Created by 이혜빈 on 11/2/25.
//

import Foundation

// MARK: - Note Formatting Utilities
struct NoteFormattingUtils {
    
    // MARK: - Sorting
    static func sortNotes(_ input: [Note], by option: HeaderSortOption) -> [Note] {
        func progressValue(_ note: Note) -> Double {
            let m = Mirror(reflecting: note)
            if let p = m.children.first(where: { $0.label == "progress" || $0.label == "percentage" })?.value as? Double {
                return p <= 1.0 ? (p * 100.0) : p
            }
            if let pInt = m.children.first(where: { $0.label == "progressPercent" })?.value as? Int {
                return Double(pInt)
            }
            return 0.0
        }
        
        switch option {
        case .alphabeticalAsc:
            return input.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
        case .alphabeticalDesc:
            return input.sorted { $0.title.localizedCompare($1.title) == .orderedDescending }
        case .recentlyOpenedAsc:
            return input.sorted { $0.lastRead < $1.lastRead }
        case .recentlyOpenedDesc:
            return input.sorted { $0.lastRead > $1.lastRead }
        case .progressAsc:
            return input.sorted { progressValue($0) < progressValue($1) }
        case .progressDesc:
            return input.sorted { progressValue($0) > progressValue($1) }
        }
    }
    
    // MARK: - Duration Text
    static func durationText(for note: Note) -> String {
        let m = Mirror(reflecting: note)
        
        if let secs = m.children.first(where: { $0.label == "duration" || $0.label == "length" })?.value as? TimeInterval {
            let mm = Int(secs) / 60
            let ss = Int(secs) % 60
            return String(format: "%d:%02d", mm, ss)
        }
        if let s = m.children.first(where: { $0.label == "durationText" || $0.label == "lengthText" })?.value as? String, !s.isEmpty {
            return s
        }
        return "—"
    }
    
    // MARK: - Progress Text
    static func progressText(for note: Note) -> String {
        let m = Mirror(reflecting: note)
        
        if let p = m.children.first(where: { $0.label == "progress" || $0.label == "percentage" })?.value as? Double {
            let v = p <= 1.0 ? (p * 100.0) : p
            return String(format: "%.0f%%", v)
        }
        if let pInt = m.children.first(where: { $0.label == "progressPercent" })?.value as? Int {
            return "\(pInt)%"
        }
        return "—"
    }
    
    // MARK: - Last Read Text
    static func lastReadText(for note: Note) -> String {
        relativeDate(note.lastRead)
    }
    
    // MARK: - Relative Date
    static func relativeDate(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f.localizedString(for: date, relativeTo: Date())
    }
    
    // MARK: - Thumbnail URL
    /// Try to resolve a thumbnail URL for a note:
    /// 1) If the model has `thumbnailURL`/`thumbnailUrl` (String), use it directly.
    /// 2) Else, try to find a YouTube-like link property (`youtubeURL`, `videoURL`, `url`, `link`, ...),
    ///    then generate `https://img.youtube.com/vi/<id>/hqdefault.jpg` using `YouTubeThumbnail.thumbnailURL(from:)`.
    static func thumbnailURL(for note: Note) -> URL? {
        let mirror = Mirror(reflecting: note)
        var thumbString: String?
        var linkString: String?
        var youtubeId: String?
        
        for child in mirror.children {
            guard let label = child.label else { continue }
            
            // 직접 썸네일 URL을 저장하는 경우
            if thumbString == nil,
               (label == "thumbnailURL" || label == "thumbnailUrl"),
               let s = child.value as? String, !s.isEmpty {
                thumbString = s
            }
            
            // 임의의 문자열 필드에 유튜브 링크가 들어있는 경우 (heuristics)
            if linkString == nil,
               let s = child.value as? String,
               s.lowercased().contains("youtu") {
                linkString = s
            }
            
            // 영상 id만 저장하는 경우
            if youtubeId == nil,
               ["youtubeID","youtubeId","videoID","videoId"].contains(label),
               let s = child.value as? String, !s.isEmpty {
                youtubeId = s
            }
        }
        
        if let t = thumbString, let u = URL(string: t) { return u }
        if let id = youtubeId, let u = URL(string: "https://img.youtube.com/vi/\(id)/hqdefault.jpg") { return u }
        if let l = linkString, let u = YouTubeThumbnail.thumbnailURL(from: l) { return u }
        return nil
    }
}

// MARK: - YouTube Thumbnail Helper
struct YouTubeThumbnail {
    /// Extract YouTube video ID from various URL formats and return thumbnail URL
    static func thumbnailURL(from urlString: String) -> URL? {
        guard let videoId = extractVideoId(from: urlString) else { return nil }
        return URL(string: "https://img.youtube.com/vi/\(videoId)/hqdefault.jpg")
    }
    
    private static func extractVideoId(from urlString: String) -> String? {
        // Handle various YouTube URL formats
        let patterns = [
            "(?:youtube\\.com/watch\\?v=|youtu\\.be/)([^&\\s]+)",
            "youtube\\.com/embed/([^&\\s]+)",
            "youtube\\.com/v/([^&\\s]+)"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let nsString = urlString as NSString
                let results = regex.matches(in: urlString, options: [], range: NSRange(location: 0, length: nsString.length))
                
                if let match = results.first, match.numberOfRanges > 1 {
                    let range = match.range(at: 1)
                    return nsString.substring(with: range)
                }
            }
        }
        return nil
    }
}
