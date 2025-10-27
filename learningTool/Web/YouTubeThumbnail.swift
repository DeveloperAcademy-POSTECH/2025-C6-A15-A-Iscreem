//
//  YouTubeThumbnail.swift
//  learningTool
//
//  Created by Yulim KIm on 10/26/25.
//


import Foundation

enum YouTubeThumbnail {
    /// YouTube URL에서 동영상 ID 추출 (youtu.be, watch?v=, shorts, live 지원)
    static func videoID(from urlString: String) -> String? {
        guard let url = URL(string: urlString), let host = url.host else { return nil }

        // youtu.be/<id>
        if host.contains("youtu.be") {
            let id = url.lastPathComponent
            return id.isEmpty ? nil : id
        }

        // youtube.com/*
        if host.contains("youtube.com") {
            if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let v = comps.queryItems?.first(where: { $0.name == "v" })?.value, !v.isEmpty {
                return v
            }
            let path = url.path
            // /shorts/<id>
            if path.contains("/shorts/") {
                return path.components(separatedBy: "/shorts/").last?.components(separatedBy: "/").first
            }
            // /live/<id>
            if path.contains("/live/") {
                return path.components(separatedBy: "/live/").last?.components(separatedBy: "/").first
            }
        }

        return nil
    }

    /// 신뢰도 높은 썸네일 URL (hqdefault.jpg) 생성
    static func thumbnailURL(from urlString: String?) -> URL? {
        guard let urlString, let id = videoID(from: urlString) else { return nil }
        return URL(string: "https://img.youtube.com/vi/\(id)/hqdefault.jpg")
    }
}
