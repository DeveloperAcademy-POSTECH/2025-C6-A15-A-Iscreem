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
    
    // ✅ Helper: 스크린샷 캡쳐 (비디오 영역만) - JavaScript로 비디오 프레임 직접 캡쳐
    @MainActor
    func captureScreenshot(completion: @escaping (Data?) -> Void) {
        let webView = host.webView
        
        // JavaScript로 video 요소의 현재 프레임을 canvas에 그려서 base64로 가져오기
        let js = """
        (function() {
            try {
                var video = document.querySelector('video');
                if (!video || video.readyState < 2) {
                    // video가 없거나 준비되지 않음
                    return JSON.stringify({ error: 'Video not ready' });
                }
                
                // canvas 생성
                var canvas = document.createElement('canvas');
                canvas.width = video.videoWidth || video.clientWidth;
                canvas.height = video.videoHeight || video.clientHeight;
                
                // videoWidth/videoHeight가 0이면 실제 표시 크기 사용
                if (canvas.width === 0 || canvas.height === 0) {
                    var rect = video.getBoundingClientRect();
                    canvas.width = rect.width;
                    canvas.height = rect.height;
                }
                
                var ctx = canvas.getContext('2d');
                
                // video의 현재 프레임을 canvas에 그리기
                ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
                
                // canvas를 JPEG base64로 변환 (품질 0.9)
                var dataURL = canvas.toDataURL('image/jpeg', 0.9);
                
                // base64 데이터만 추출 (data:image/jpeg;base64, 제거)
                var base64Data = dataURL.split(',')[1];
                
                return JSON.stringify({
                    success: true,
                    data: base64Data,
                    width: canvas.width,
                    height: canvas.height
                });
            } catch(e) {
                return JSON.stringify({
                    error: e.message || 'Unknown error'
                });
            }
        })();
        """
        
        webView.evaluateJavaScript(js) { result, error in
            if let error = error {
                print("JavaScript 캡쳐 실패: \(error.localizedDescription)")
                // JavaScript 실패 시 iOS 레벨 캡쳐로 폴백
                self.captureWithIOSMethod(webView: webView, completion: completion)
                return
            }
            
            guard let jsonString = result as? String,
                  let data = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("JSON 파싱 실패")
                self.captureWithIOSMethod(webView: webView, completion: completion)
                return
            }
            
            // 에러가 있으면 iOS 레벨 캡쳐로 폴백
            if let errorMsg = json["error"] as? String {
                print("JavaScript 에러: \(errorMsg)")
                self.captureWithIOSMethod(webView: webView, completion: completion)
                return
            }
            
            // 성공한 경우 base64 데이터를 디코딩
            if let success = json["success"] as? Bool, success,
               let base64Data = json["data"] as? String,
               let imageData = Data(base64Encoded: base64Data) {
                completion(imageData)
            } else {
                print("base64 디코딩 실패")
                self.captureWithIOSMethod(webView: webView, completion: completion)
            }
        }
    }
    
    // iOS 레벨 캡쳐 (폴백)
    @MainActor
    private func captureWithIOSMethod(webView: WKWebView, completion: @escaping (Data?) -> Void) {
        // JavaScript로 비디오 영역 좌표 가져오기
        let js = """
        (function() {
            try {
                var video = document.querySelector('video');
                if (!video) {
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
                    return JSON.stringify({
                        x: 0, y: 0,
                        width: window.innerWidth || document.documentElement.clientWidth,
                        height: window.innerHeight || document.documentElement.clientHeight
                    });
                }
                
                var rect = video.getBoundingClientRect();
                return JSON.stringify({
                    x: Math.max(0, rect.left),
                    y: Math.max(0, rect.top),
                    width: Math.min(rect.width, window.innerWidth || document.documentElement.clientWidth),
                    height: Math.min(rect.height, window.innerHeight || document.documentElement.clientHeight)
                });
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
            var captureRect = webView.bounds
            if let jsonString = result as? String,
               let data = jsonString.data(using: .utf8),
               let rect = try? JSONDecoder().decode(VideoRect.self, from: data) {
                let viewportWidth = webView.bounds.width
                let viewportHeight = webView.bounds.height
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
    
    // 비디오 영역만 캡쳐 (iOS 레벨 렌더링 사용)
    @MainActor
    private func captureArea(webView: WKWebView, rect: CGRect, completion: @escaping (Data?) -> Void) {
        // iOS 레벨에서 전체 웹뷰를 먼저 캡쳐한 후, rect 영역만 크롭
        let scale = UIScreen.main.scale
        let webViewSize = webView.bounds.size
        let targetSize = CGSize(width: webViewSize.width * scale, height: webViewSize.height * scale)
        
        // 그래픽 컨텍스트 생성 (전체 웹뷰 크기)
        UIGraphicsBeginImageContextWithOptions(targetSize, true, scale)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else {
            completion(nil)
            return
        }
        
        // 배경을 검은색으로 채우기
        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(origin: .zero, size: targetSize))
        
        // drawHierarchy를 사용하여 실제 화면에 렌더링된 내용 캡쳐
        // afterScreenUpdates를 true로 설정하여 최신 렌더링 내용 캡쳐
        let success = webView.drawHierarchy(in: webView.bounds, afterScreenUpdates: true)
        
        if !success {
            // drawHierarchy 실패 시 layer 렌더링 시도
            webView.layer.render(in: context)
        }
        
        // 전체 이미지 가져오기
        guard let fullImage = UIGraphicsGetImageFromCurrentImageContext() else {
            completion(nil)
            return
        }
        
        // rect 영역만 크롭 (scale 고려)
        let cropRect = CGRect(
            x: rect.origin.x * scale,
            y: rect.origin.y * scale,
            width: rect.width * scale,
            height: rect.height * scale
        )
        
        guard let cgImage = fullImage.cgImage,
              let croppedCGImage = cgImage.cropping(to: cropRect) else {
            completion(nil)
            return
        }
        
        let croppedImage = UIImage(cgImage: croppedCGImage, scale: scale, orientation: .up)
        
        // 이미지를 16:9 비율로 크롭 (불필요한 여백 제거)
        let finalImage = self.cropTo16to9(image: croppedImage, allowSkip: true)
        
        // UIImage를 불투명 이미지로 변환하여 alpha 채널 경고 방지
        let opaqueImage: UIImage
        if let finalCGImage = finalImage.cgImage {
            let context = CGContext(
                data: nil,
                width: finalCGImage.width,
                height: finalCGImage.height,
                bitsPerComponent: 8,
                bytesPerRow: finalCGImage.width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            )
            context?.draw(finalCGImage, in: CGRect(x: 0, y: 0, width: finalCGImage.width, height: finalCGImage.height))
            if let opaqueCGImage = context?.makeImage() {
                opaqueImage = UIImage(cgImage: opaqueCGImage)
            } else {
                opaqueImage = finalImage
            }
        } else {
            opaqueImage = finalImage
        }
        
        // UIImage를 JPEG 데이터로 변환 (alpha 채널 없음)
        if let jpegData = opaqueImage.jpegData(compressionQuality: 0.8) {
            completion(jpegData)
        } else {
            completion(nil)
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

