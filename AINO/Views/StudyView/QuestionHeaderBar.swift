//
//  QuestionHeaderBar.swift
//  learningTool
//
//  Created by coulson on 10/30/25.
//

import SwiftUI

struct QuestionHeaderBar: View {
    let messageCount: Int
    let onClear: () -> Void
    @EnvironmentObject private var localizationManager: LocalizationManager

    var body: some View {
        HStack {
            Text(LocalizedText(korean: "AI에게 무엇이든 물어보세요!", english: "Ask AI anything!").text)
                .font(.bodyText)
                .foregroundStyle(Color.text2)

            Spacer()

            if messageCount > 2 {
                Button(action: onClear) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.errorColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.clear)
    }
}
