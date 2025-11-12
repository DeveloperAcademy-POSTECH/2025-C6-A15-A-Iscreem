//
//  QuestionInputBar.swift
//  learningTool
//
//  Created by coulson on 10/30/25.
//

import SwiftUI

// MARK: - QuestionInputBar (입력 영역 컴포넌트)
struct QuestionInputBar: View {
    @Binding var text: String
    var isEnabled: Bool
    var isSending: Bool
    var isGenerating: Bool
    @FocusState.Binding var focus: Bool
    var placeholder: String
    var onTapLightbulb: () -> Void
    var onSend: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // 텍스트 입력
            TextField(placeholder, text: $text, axis: .horizontal)
                .focused($focus)
                .submitLabel(.send)
                .onTapGesture { focus = true }
                .font(.system(size: 15))
                .lineLimit(1)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.background2)
                .cornerRadius(20)
                .disabled(!isEnabled)
                .onSubmit {
                    if isEnabled {
                        onSend()
                        focus = false  // 전송 후 키보드 내리기 (오버레이/포커스 루프 방지)
                    }
                }

            // 추천 질문(전구)
            Button(action: {
                guard isEnabled else { return }
                onTapLightbulb()
            }) {
                Image(systemName: isGenerating ? "arrow.triangle.2.circlepath" : "lightbulb.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        (!isEnabled || isGenerating) ? Color.text3.opacity(0.5) : Color.orange
                    )
                    .clipShape(Circle())
                    .rotationEffect(.degrees(isGenerating ? 360 : 0))
                    .animation(
                        isGenerating
                        ? .linear(duration: 1).repeatForever(autoreverses: false)
                        : .default,
                        value: isGenerating
                    )
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled || isGenerating)

            // 전송(종이비행기)
            Button(action: {
                guard isEnabled, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                onSend()
                focus = false  // 전송 버튼 탭 시에도 키보드 닫기 (재포커싱 루프 차단)
            }) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        (isSending || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !isEnabled)
                        ? Color.text3.opacity(0.5)
                        : Color.secondColor
                    )
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(isSending || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !isEnabled)
        }
        // 이 컴포넌트 자체는 여백/배경을 갖지 않음. 호출부에서 .padding / .background 지정.
        .accessibilityElement(children: .contain)
        .accessibilityLabel("질문 입력 바")
    }
}
