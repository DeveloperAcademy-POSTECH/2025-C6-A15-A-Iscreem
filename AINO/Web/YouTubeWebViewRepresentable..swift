//
//  YouTubeWebViewRepresentable..swift
//  learningTool
//
//  Created by coulson on 10/20/25.
//

import SwiftUI
import WebKit
import UIKit

struct YouTubeWebViewRepresentable: UIViewRepresentable {
    let host: YouTubeWebViewHost

    init(captionAnalyzer: CaptionAnalyzer, onPause: ((TimeInterval) -> Void)? = nil) {
        let h = YouTubeWebViewHost(captionAnalyzer: captionAnalyzer)
        h.onPause = onPause
        self.host = h
    }

    func makeUIView(context: Context) -> WKWebView {
        host.webView
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // no-op
    }

    // Helper: 외부에서 로드 트리거
    @MainActor
    func load(_ urlString: String) {
        host.load(urlString: urlString)
    }
    
    // Helper: 노트와 함께 로드(요약 캐시 재활용 + 세션 바인딩)
    @MainActor
    func load(_ urlString: String, for note: Note) {
        // ✅ 먼저 로드(내부에서 reset 즉시 실행)
        host.load(urlString: urlString)
        // ✅ 그 다음 노트 바인딩(캐시 복원)
        host.bind(note: note)
    }
    
    // ✅ Helper: 현재 재생 시간 질의
    @MainActor
    func getCurrentTime(completion: @escaping (Double?) -> Void) {
        host.getCurrentTime(completion: completion)
    }
    
    // ✅ Helper: 즉시 일시정지
    @MainActor
    func pause() {
        host.pause()
    }
    
    // ✅ Helper: 즉시 정지(언로드)
    @MainActor
    func stop() {
        host.stop()
    }
    
    // ✅ Helper: 이어보기 시킹
    @MainActor
    func seek(to seconds: Double, autoPlay: Bool = true) {
        host.seek(to: seconds, autoPlay: autoPlay)
    }
    
    // ✅ Helper: 스크린샷 캡쳐 (비디오 영역만)
    @MainActor
    func captureScreenshot(completion: @escaping (Data?) -> Void) {
        let webView = host.webView
        
        // JavaScript로 video 요소 또는 플레이어 컨테이너의 위치와 크기 가져오기
        let js = """
        (function() {
            try {
                // 먼저 video 요소를 찾기
                var video = document.querySelector('video');
                if (!video) {
                    // video가 없으면 플레이어 컨테이너 찾기
                    var player = document.querySelector('#player, #player-container, .html5-video-player, ytd-player');
                    if (player) {
                        var rect = player.getBoundingClientRect();
                        return JSON.stringify({
                            x: Math.max(0, rect.left),
                            y: Math.max(0, rect.top),
                            width: Math.min(rect.width, window.innerWidth || document.documentElement.clientWidth),
                            height: Math.min(rect.height, window.innerHeight || document.documentElement.clientHeight)
                        });
                    }
                    // 아무것도 없으면 전체 영역 반환
                    return JSON.stringify({
                        x: 0, y: 0,
                        width: window.innerWidth || document.documentElement.clientWidth,
                        height: window.innerHeight || document.documentElement.clientHeight
                    });
                }
                
                // video 요소의 실제 표시 영역 가져오기
                var rect = video.getBoundingClientRect();
                // video의 부모 컨테이너도 확인 (더 정확한 영역)
                var parent = video.parentElement;
                var parentRect = parent ? parent.getBoundingClientRect() : null;
                
                // video가 실제로 보이는 영역만 사용
                var visibleRect = {
                    x: Math.max(0, rect.left),
                    y: Math.max(0, rect.top),
                    width: Math.min(rect.width, window.innerWidth || document.documentElement.clientWidth),
                    height: Math.min(rect.height, window.innerHeight || document.documentElement.clientHeight)
                };
                
                // 부모 컨테이너가 있고 더 작으면 부모 영역 사용
                if (parentRect && parentRect.width > 0 && parentRect.height > 0) {
                    var parentVisible = {
                        x: Math.max(0, parentRect.left),
                        y: Math.max(0, parentRect.top),
                        width: Math.min(parentRect.width, window.innerWidth || document.documentElement.clientWidth),
                        height: Math.min(parentRect.height, window.innerHeight || document.documentElement.clientHeight)
                    };
                    // video 영역과 부모 영역 중 더 작은 것을 사용 (실제 플레이어 영역)
                    if (parentVisible.width <= visibleRect.width && parentVisible.height <= visibleRect.height) {
                        visibleRect = parentVisible;
                    }
                }
                
                return JSON.stringify(visibleRect);
            } catch(e) {
                return JSON.stringify({
                    x: 0, y: 0,
                    width: window.innerWidth || document.documentElement.clientWidth,
                    height: window.innerHeight || document.documentElement.clientHeight
                });
            }
        })();
        """
        
        webView.evaluateJavaScript(js) { result, error in
            if let error = error {
                print("스크린샷 영역 계산 실패: \(error.localizedDescription)")
                // 오류 시 전체 영역 캡쳐 후 크롭
                self.captureFullArea(webView: webView, completion: completion)
                return
            }
            
            // JavaScript 결과 파싱
            var captureRect = webView.bounds
            if let jsonString = result as? String,
               let data = jsonString.data(using: .utf8),
               let rect = try? JSONDecoder().decode(VideoRect.self, from: data) {
                // JavaScript 좌표는 뷰포트 기준이므로, 웹뷰의 contentScaleFactor를 고려
                let contentScale = webView.contentScaleFactor
                let viewportWidth = webView.bounds.width
                let viewportHeight = webView.bounds.height
                
                // JavaScript에서 반환한 좌표가 뷰포트 기준이므로 직접 사용
                // 단, 웹뷰 bounds를 넘지 않도록 제한
                captureRect = CGRect(
                    x: max(0, min(rect.x, viewportWidth)),
                    y: max(0, min(rect.y, viewportHeight)),
                    width: min(rect.width, viewportWidth - max(0, rect.x)),
                    height: min(rect.height, viewportHeight - max(0, rect.y))
                )
            }
            
            self.captureArea(webView: webView, rect: captureRect, completion: completion)
        }
    }
    
    // 비디오 영역만 캡쳐
    @MainActor
    private func captureArea(webView: WKWebView, rect: CGRect, completion: @escaping (Data?) -> Void) {
        let config = WKSnapshotConfiguration()
        config.rect = rect
        config.snapshotWidth = NSNumber(value: Int(rect.width))
        
        webView.takeSnapshot(with: config) { image, error in
            if let error = error {
                print("스크린샷 캡쳐 실패: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let image = image else {
                completion(nil)
                return
            }
            
            // 이미지를 16:9 비율로 크롭 (불필요한 여백 제거)
            // 단, 이미 비디오 영역만 캡쳐된 경우 크롭을 건너뛸 수 있음
            let croppedImage = self.cropTo16to9(image: image, allowSkip: true)
            
            // UIImage를 불투명 이미지로 변환하여 alpha 채널 경고 방지
            let opaqueImage: UIImage
            if let cgImage = croppedImage.cgImage {
                let context = CGContext(
                    data: nil,
                    width: cgImage.width,
                    height: cgImage.height,
                    bitsPerComponent: 8,
                    bytesPerRow: cgImage.width * 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
                )
                context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
                if let opaqueCGImage = context?.makeImage() {
                    opaqueImage = UIImage(cgImage: opaqueCGImage)
                } else {
                    opaqueImage = croppedImage
                }
            } else {
                opaqueImage = croppedImage
            }
            
            // UIImage를 JPEG 데이터로 변환 (alpha 채널 없음)
            if let jpegData = opaqueImage.jpegData(compressionQuality: 0.8) {
                completion(jpegData)
            } else {
                completion(nil)
            }
        }
    }
    
    // 전체 영역 캡쳐 (폴백)
    @MainActor
    private func captureFullArea(webView: WKWebView, completion: @escaping (Data?) -> Void) {
        captureArea(webView: webView, rect: webView.bounds, completion: completion)
    }
    
    // 이미지를 16:9 비율로 크롭 (중앙 기준)
    private func cropTo16to9(image: UIImage, allowSkip: Bool = false) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        
        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)
        let targetAspectRatio: CGFloat = 16.0 / 9.0
        let imageAspectRatio = imageWidth / imageHeight
        
        // 이미 비율이 거의 16:9에 가까우면 크롭 건너뛰기 (allowSkip이 true인 경우)
        if allowSkip {
            let aspectRatioDiff = abs(imageAspectRatio - targetAspectRatio) / targetAspectRatio
            if aspectRatioDiff < 0.05 { // 5% 이내 차이면 건너뛰기
                return image
            }
        }
        
        var cropRect: CGRect
        
        if imageAspectRatio > targetAspectRatio {
            // 이미지가 더 넓음 → 높이 기준으로 크롭
            let targetHeight = imageHeight
            let targetWidth = targetHeight * targetAspectRatio
            let x = (imageWidth - targetWidth) / 2.0
            cropRect = CGRect(x: x, y: 0, width: targetWidth, height: targetHeight)
        } else {
            // 이미지가 더 높음 → 너비 기준으로 크롭
            let targetWidth = imageWidth
            let targetHeight = targetWidth / targetAspectRatio
            let y = (imageHeight - targetHeight) / 2.0
            cropRect = CGRect(x: 0, y: y, width: targetWidth, height: targetHeight)
        }
        
        // 정수 좌표로 변환
        cropRect = CGRect(
            x: floor(cropRect.origin.x),
            y: floor(cropRect.origin.y),
            width: floor(cropRect.width),
            height: floor(cropRect.height)
        )
        
        // 크롭 영역이 이미지 범위를 벗어나지 않도록 제한
        cropRect = cropRect.intersection(CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))
        
        // 크롭 영역이 너무 작으면 원본 반환
        if cropRect.width < imageWidth * 0.5 || cropRect.height < imageHeight * 0.5 {
            return image
        }
        
        guard let croppedCGImage = cgImage.cropping(to: cropRect) else {
            return image
        }
        
        return UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
    }
}

// JavaScript에서 반환하는 비디오 영역 정보
private struct VideoRect: Codable {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
}

