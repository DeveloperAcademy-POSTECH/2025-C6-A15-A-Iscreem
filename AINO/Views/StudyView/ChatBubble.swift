//
//  ChatBubble.swift
//  learningTool
//
//  Created by coulson on 10/30/25.
//  QuestionView에서 사용하던 말풍선 UI를 분리
//  리퀴드글라스 디자인 적용

import SwiftUI
import UIKit
import Photos

struct ChatBubble: View {
    let message: ChatMessage
    @State private var showCopyConfirmation = false
    @State private var showSaveConfirmation = false
    @State private var saveConfirmationMessage = ""
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.isUser {
                Spacer(minLength: 0)
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
                    // 이미지가 있으면 표시
                    if let imageData = message.imageData, let uiImage = UIImage(data: imageData) {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: 200, maxHeight: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.borderColor, lineWidth: 1)
                                )
                            
                            // 다운로드 버튼
                            Button(action: {
                                saveImageToPhotos(uiImage)
                            }) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.white)
                                    .background(
                                        Circle()
                                            .fill(Color.black.opacity(0.5))
                                    )
                                    .padding(8)
                            }
                        }
                    }
                    
                    // 텍스트 메시지
                    if !message.text.isEmpty {
                        // AI 답변일 때는 마크다운을 제거한 일반 텍스트로 표시, 사용자 메시지는 그대로 표시
                        let displayText = message.isUser ? message.text : stripMarkdown(message.text)
                        
                        Text(displayText)
                            .font(.system(size: 14))
                            .foregroundStyle(message.isUser ? .white : Color.text1)
                            .multilineTextAlignment(message.isUser ? .trailing : .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(nil)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                message.isUser
                                ? Color.accentColor
                                : Color.background1
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.accentColor, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .frame(maxWidth: 600, alignment: message.isUser ? .trailing : .leading)
                            .onLongPressGesture {
                                // 복사할 때는 원본 마크다운 텍스트 유지
                                copyTextToClipboard(message.text)
                            }
                    }
                }
                
                Text(timeString(from: message.timestamp))
                    .font(.system(size: 11))
                    .foregroundStyle(Color.text3)
                    .padding(.horizontal, 4)
            }
            
            if !message.isUser {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
        .overlay(
            Group {
                if showCopyConfirmation {
                    Text("복사되었습니다")
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .transition(.opacity.combined(with: .scale))
                } else if showSaveConfirmation {
                    Text(saveConfirmationMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: showCopyConfirmation)
            .animation(.easeInOut(duration: 0.2), value: showSaveConfirmation)
        )
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: date)
    }
    
    /// 마크다운 문법을 제거하여 일반 텍스트로 변환
    private func stripMarkdown(_ text: String) -> String {
        var result = text
        
        // 코드 블록 제거 (```code```)
        result = result.replacingOccurrences(
            of: #"```[\s\S]*?```"#,
            with: "",
            options: .regularExpression
        )
        
        // 인라인 코드 제거 (`code`)
        result = result.replacingOccurrences(
            of: #"`([^`]+)`"#,
            with: "$1",
            options: .regularExpression
        )
        
        // 링크 제거 ([text](url)) -> text
        result = result.replacingOccurrences(
            of: #"\[([^\]]+)\]\([^\)]+\)"#,
            with: "$1",
            options: .regularExpression
        )
        
        // 이미지 제거 (![alt](url))
        result = result.replacingOccurrences(
            of: #"!\[([^\]]*)\]\([^\)]+\)"#,
            with: "$1",
            options: .regularExpression
        )
        
        // 볼드 제거 (**text** 또는 __text__)
        result = result.replacingOccurrences(
            of: #"\*\*([^\*]+)\*\*"#,
            with: "$1",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"__([^_]+)__"#,
            with: "$1",
            options: .regularExpression
        )
        
        // 이탤릭 제거 (*text* 또는 _text_)
        result = result.replacingOccurrences(
            of: #"(?<!\*)\*([^\*]+)\*(?!\*)"#,
            with: "$1",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"(?<!_)_([^_]+)_(?!_)"#,
            with: "$1",
            options: .regularExpression
        )
        
        // 취소선 제거 (~~text~~)
        result = result.replacingOccurrences(
            of: #"~~([^~]+)~~"#,
            with: "$1",
            options: .regularExpression
        )
        
        // 헤딩 제거 (# Heading) - (?m) 플래그로 각 라인에 매칭
        result = result.replacingOccurrences(
            of: #"(?m)^#{1,6}\s+(.+)$"#,
            with: "$1",
            options: .regularExpression
        )
        
        // 리스트 마커 제거 (-, *, +, 숫자.)
        result = result.replacingOccurrences(
            of: #"(?m)^[\s]*[-*+]\s+(.+)$"#,
            with: "$1",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"(?m)^[\s]*\d+\.\s+(.+)$"#,
            with: "$1",
            options: .regularExpression
        )
        
        // 인용구 제거 (> text)
        result = result.replacingOccurrences(
            of: #"(?m)^>\s+(.+)$"#,
            with: "$1",
            options: .regularExpression
        )
        
        // 수평선 제거 (---, ***, ___)
        result = result.replacingOccurrences(
            of: #"(?m)^[-*_]{3,}$"#,
            with: "",
            options: .regularExpression
        )
        
        // 불필요한 공백 정리
        result = result.replacingOccurrences(
            of: #"\n{3,}"#,
            with: "\n\n",
            options: .regularExpression
        )
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return result
    }
    
    private func copyTextToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        showCopyConfirmation = true
        
        // 2초 후 확인 메시지 숨기기
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            showCopyConfirmation = false
        }
    }
    
    private func saveImageToPhotos(_ image: UIImage) {
        // Photos 프레임워크를 사용한 이미지 저장
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                let generator = UINotificationFeedbackGenerator()
                
                guard status == .authorized || status == .limited else {
                    // 권한 거부
                    generator.notificationOccurred(.error)
                    saveConfirmationMessage = "저장 실패: 사진 라이브러리 접근 권한이 필요합니다"
                    showSaveConfirmation = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        showSaveConfirmation = false
                    }
                    return
                }
                
                // 이미지 저장
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }) { success, error in
                    DispatchQueue.main.async {
                        if success {
                            generator.notificationOccurred(.success)
                            saveConfirmationMessage = "사진 앨범에 저장되었습니다"
                        } else {
                            generator.notificationOccurred(.error)
                            saveConfirmationMessage = "저장 실패: \(error?.localizedDescription ?? "알 수 없는 오류")"
                        }
                        
                        showSaveConfirmation = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            showSaveConfirmation = false
                        }
                    }
                }
            }
        }
    }
}
