//
//  QuestionInputBar.swift
//  learningTool
//
//  Created by coulson on 10/30/25.
//

import SwiftUI

struct QuestionInputBar: View {
    @Binding var text: String
    @Binding var includeScreenshot: Bool
    var isEnabled: Bool
    var isSending: Bool
    var isGenerating: Bool
    @FocusState.Binding var focus: Bool
    var placeholder: String
    var onTapLightbulb: () -> Void
    var onSend: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // 메뉴 버튼
            Menu {
                Toggle("영상 캡쳐 포함", isOn: $includeScreenshot)
            } label: {
                Image(systemName: includeScreenshot ? "checkmark.circle.fill" : "ellipsis.circle")
                    .font(.system(size: 18))
                    .foregroundStyle(includeScreenshot ? Color.secondColor : Color.text3)
                    .frame(width: 40, height: 40)
                    .background(
                        includeScreenshot ? Color.secondColor.opacity(0.15) : Color.background2
                    )
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            
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

