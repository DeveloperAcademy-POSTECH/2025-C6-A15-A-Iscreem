//
//  QuestionInputBar.swift
//  learningTool
//
//  Created by coulson on 10/30/25.
//

import SwiftUI

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
                    // ⛔️ 외부 API 호출 트리거 차단
                    /* if isEnabled {
                        onSend()
                        focus = false
                    } */
                }

            Button(action: {
                // ⛔️ 추천 질문(전구) 동작 차단
                /* guard isEnabled else { return }
                onTapLightbulb() */
            }) {
                Image(systemName: isGenerating ? "arrow.triangle.2.circlepath" : "lightbulb.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.text3.opacity(0.5))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(true)

            Button(action: {
                // ⛔️ 전송 버튼 동작 차단
                /* guard isEnabled, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                onSend()
                focus = false */
            }) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.text3.opacity(0.5))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("질문 입력 바")
    }
}

