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
                    if isEnabled && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onSend()
                        focus = false
                    }
                }

            Button(action: {
                guard isEnabled else { return }
                onTapLightbulb()
            }) {
                Image(systemName: isGenerating ? "arrow.triangle.2.circlepath" : "lightbulb.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        isEnabled ? Color.orange : Color.text3.opacity(0.5)
                    )
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)

            Button(action: {
                guard isEnabled, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                onSend()
                focus = false
            }) {
                Image(systemName: isSending ? "stop.circle.fill" : "paperplane.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        isEnabled && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty 
                        ? Color.secondColor 
                        : Color.text3.opacity(0.5)
                    )
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("질문 입력 바")
    }
}

