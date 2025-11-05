import SwiftUI

enum BubbleType {
    case question
    case answer
}

struct ChatBubbleView: View {
    let text: String
    let type: BubbleType
    
    var body: some View {
        Text(text)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: 200, alignment: .leading)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var backgroundColor: Color {
        switch type {
        case .question:
            return .accentColor
        case .answer:
            return .background1
        }
    }
    
    private var borderColor: Color {
        return .accentColor
    }
}

#Preview(traits: .landscapeLeft) {
    VStack(spacing: 16) {
        // 질문 말풍선
        ChatBubbleView(text: "이것은 질문입니다", type: .question)
        
        // 답변 말풍선
        ChatBubbleView(text: "이것은 답변입니다", type: .answer)
        
        // 긴 텍스트 예시
        ChatBubbleView(text: "이것은 매우 긴 질문입니다. 텍스트가 길어지면 자동으로 줄바꿈이 됩니다.", type: .question)
        
        ChatBubbleView(text: "이것은 매우 긴 답변입니다. 텍스트가 길어지면 자동으로 줄바꿈이 되고, 세로로 무한대로 늘어날 수 있습니다. 가로는 최대 200까지만 늘어납니다.", type: .answer)
    }
    .padding()
}


