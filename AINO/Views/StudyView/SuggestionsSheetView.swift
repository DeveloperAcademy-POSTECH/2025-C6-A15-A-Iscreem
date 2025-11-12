//
//  SuggestionsSheetView.swift
//  learningTool
//
//  Created by coulson on 10/30/25.
//

import SwiftUI

struct SuggestionsSheetView: View {
    @Binding var isPresented: Bool
    let isLoading: Bool
    let suggestedQuestions: [String]
    let currentMessage: String
    let selectedKeyword: String?
    let onRegenerate: () -> Void
    let onPick: (String) -> Void

    // iPad 레이아웃 기준 해상도 (13인치 가로형 1366x1024)
    private let baseIPadLandscapeSize = CGSize(width: 1366, height: 1024)

    var body: some View {
        ZStack(alignment: .bottom) {
            // Dim 배경
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            GeometryReader { geo in
                let scaler = BaseLayoutScaler(proxy: geo, base: baseIPadLandscapeSize)
                let sheetHeight = scaler.h(220)
                VStack(spacing: 0) {
                    // 헤더
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.orange)
                                Text("AI 추천 질문")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(Color.text1)
                            }

                            let display = currentMessage.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !display.isEmpty {
                                Text("'\(display.prefix(30))\(display.count > 30 ? "..." : "")' 관련 학습 질문")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.text3)
                            } else if let keyword = selectedKeyword {
                                Text("'\(keyword)' 관련 학습 질문")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.text3)
                            }
                        }

                        Spacer()

                        // 새로고침
                        Button(action: onRegenerate) {
                            Image(systemName: isLoading ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.secondColor)
                                .frame(width: 32, height: 32)
                                .background(Color.background2)
                                .clipShape(Circle())
                                .rotationEffect(.degrees(isLoading ? 360 : 0))
                                .animation(isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                                           value: isLoading)
                        }
                        .buttonStyle(.plain)
                        .disabled(isLoading)

                        // 닫기
                        Button(action: { withAnimation(.easeOut(duration: 0.2)) { isPresented = false }}) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.text3)
                                .frame(width: 32, height: 32)
                                .background(Color.background2)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(16)
                    .background(Color.background1)

                    Divider().background(Color.borderColor)

                    // 바디
                    if isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(Color.secondColor)
                                .scaleEffect(1.2)
                            Text("AI가 질문을 생성하고 있습니다...")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.text3)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: sheetHeight)
                        .background(Color.background1)
                    } else if !suggestedQuestions.isEmpty {
                        ScrollView {
                            VStack(spacing: 10) {
                                ForEach(Array(suggestedQuestions.enumerated()), id: \.offset) { index, q in
                                    Button(action: {
                                        withAnimation {
                                            onPick(q)
                                            isPresented = false
                                        }
                                    }) {
                                        HStack(alignment: .top, spacing: 12) {
                                            Text("\(index + 1)")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(.white)
                                                .frame(width: 24, height: 24)
                                                .background(
                                                    LinearGradient(colors: [Color.secondColor, Color.secondColor.opacity(0.7)],
                                                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                                                )
                                                .clipShape(Circle())

                                            Text(q)
                                                .font(.system(size: 14))
                                                .foregroundStyle(Color.text1)
                                                .multilineTextAlignment(.leading)
                                                .frame(maxWidth: .infinity, alignment: .leading)

                                            Image(systemName: "arrow.right.circle.fill")
                                                .font(.system(size: 18))
                                                .foregroundStyle(Color.secondColor.opacity(0.6))
                                        }
                                        .padding(14)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.background2)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(Color.secondColor.opacity(0.2), lineWidth: 1)
                                                )
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(16)
                        }
                        .frame(height: sheetHeight)
                        .background(Color.background1)
                    }
                }
                .background(Color.background1)
                .cornerRadius(16, corners: [.topLeft, .topRight])
                .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: -5)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}
