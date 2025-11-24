//
//  CreateNoteView.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI
import SwiftData

struct CreateNoteView: View {
    @Binding var youtubeLink: String
    @Binding var noteTitle: String
    let isFormValid: Bool
    let onCreate: () -> Void
    @EnvironmentObject private var localizationManager: LocalizationManager
    
    // 디바이스 타입 감지
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    var body: some View {
        GeometryReader { geometry in
            // 카드 너비를 계산해서 카드와 버튼을 동일한 폭 기준으로 정렬
            let cardWidth = min(isIPad ? 663 : geometry.size.width * 0.9, geometry.size.width - 48)
            
            VStack(alignment: .trailing, spacing: 20) {
                // 흰 상자(입력 카드)
                VStack(spacing: 0) {
                    // YouTube 링크
                    TextField("", text: $youtubeLink, prompt: Text(LocalizedText(korean: "YouTube 링크를 입력하세요!", english: "Enter YouTube link!").text)
                        .foregroundColor(Color.text3), axis: .horizontal)
                        .font(.bodyText)
                        .foregroundStyle(Color.text1)
                        .lineLimit(1)
                        .padding(.horizontal, 24)
                        .frame(height: 80)

                    Divider()
                        .background(Color.borderColor)

                    // 제목
                    TextField("", text: $noteTitle, prompt: Text(LocalizedText(korean: "저장할 노트 제목을 입력하세요!", english: "Enter note title to save!").text)
                        .foregroundColor(Color.text3), axis: .horizontal)
                        .font(.bodyText)
                        .foregroundStyle(Color.text1)
                        .lineLimit(1)
                        .padding(.horizontal, 24)
                        .frame(height: 80)
                }
                .frame(width: cardWidth)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.background1)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.borderColor, lineWidth: 1)
                        )
                )
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
                
                // 노트 생성 버튼 (흰 상자 바로 아래, 우측 정렬)
                Group {
                    if #available(iOS 26.0, *) {
                        Button(action: onCreate) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.right")
                                    .font(.bodyTextSemibold)
                                Text(LocalizedText(korean: "노트 생성", english: "Create Note").text)
                                    .font(.bodyTextSemibold)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 28)
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.capsule)
                        .tint(Color.secondColor)
                        .disabled(!isFormValid)
                        .opacity(isFormValid ? 1.0 : 0.5)
                    } else {
                        Button(action: onCreate) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .semibold))
                                Text(LocalizedText(korean: "노트 생성", english: "Create Note").text)
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 12)
                            .background(
                                ZStack {
                                    LinearGradient(
                                        colors: [
                                            Color.secondColor,
                                            Color.secondColor.opacity(0.85)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    Color.white.opacity(0.1)
                                }
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(!isFormValid)
                        .opacity(isFormValid ? 1.0 : 0.5)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}

