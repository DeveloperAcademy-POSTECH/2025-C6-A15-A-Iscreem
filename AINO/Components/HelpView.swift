//
//  HelpView.swift
//  learningtool
//
//  Created by Mumin on 10/27/25.
//

import SwiftUI

struct HelpView: View {
    var onClose: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localizationManager: LocalizationManager

    // 카드가 내용만큼만 보이도록 기본은 스크롤 비활성화
    var allowsScrolling: Bool = false
    // 스크롤을 쓰고 싶다면 최대 높이를 지정하면 그 안에서만 스크롤됩니다.
    var maxContentHeight: CGFloat? = nil
    var maxContentWidth: CGFloat? = nil

    // 본문 하단 패딩(요청: 더 넉넉하게)
    private let contentBottomPadding: CGFloat = 32
    
    // Apple Intelligence 링크가 포함된 AttributedString
    private var attributedString: AttributedString {
        let prefixText = LocalizedText(korean: "⚠️ Apple Intelligence 지원 기기확인은 ", english: "⚠️ Check Apple Intelligence supported devices at ").text
        var attributedString = AttributedString(prefixText)
        attributedString.foregroundColor = UIColor(Color.text2)
        
        let urlString = localizationManager.currentLanguage == "english" ? 
            "https://www.apple.com/apple-intelligence/" : 
            "https://www.apple.com/kr/apple-intelligence/"
        var linkString = AttributedString(urlString)
        linkString.link = URL(string: urlString)
        linkString.foregroundColor = UIColor.blue
        
        attributedString.append(linkString)
        
        let suffixText = LocalizedText(korean: " 참조 바랍니다.", english: "").text
        var suffix = AttributedString(suffixText)
        suffix.foregroundColor = UIColor(Color.text2)
        attributedString.append(suffix)
        
        return attributedString
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack(spacing: 8) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.text1)
                
                Text(LocalizedText(korean: "도움말", english: "Help").text)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.text1)
                
                Spacer()
                
                Button(action: {
                    if let onClose { onClose() } else { dismiss() }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.text2)
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 20)
            .padding(.bottom, 12)
            
            Divider()
                .background(Color.borderColor)
                .padding(.horizontal, 32)
            
            // 내용
            Group {
                if allowsScrolling || maxContentHeight != nil {
                    ScrollView {
                        content
                            .padding(.horizontal, 32)
                            .padding(.top, 20)
                            .padding(.bottom, contentBottomPadding)
                    }
                    .frame(maxHeight: maxContentHeight)
                } else {
                    // 스크롤 없이 내용만큼만 카드가 커지도록
                    content
                        .padding(.horizontal, 32)
                        .padding(.top, 20)
                        .padding(.bottom, contentBottomPadding)
                }
            }
        }
        // 카드가 부모를 가득 채우지 않도록 max .infinity 프레임 제거
        .background(Color.background1)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.borderColor, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
        // 가로 길이에 상한을 주고 싶다면 지정
        .frame(maxWidth: maxContentWidth)
    }

    // 분리된 콘텐츠 뷰(본문)
    private var content: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Q1
            VStack(alignment: .leading, spacing: 5) {
                Text(LocalizedText(korean: "1. 노트는 무엇이고, 어떻게 활용하나요?", english: "1. What are notes and how do I use them?").text)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.text1)
                
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(LocalizedText(korean: "우측 하단의 ", english: "Tap the ").text)
                        .foregroundStyle(Color.text2)
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.secondColor)
                    Text(LocalizedText(korean: " 버튼을 누르면, 노트를 추가할 수 있어요! 노트는 여러분이 수강하시는 Youtube 강의", english: " button at the bottom right to add notes! You can create notes from your YouTube lecture").text)
                        .foregroundStyle(Color.text2)
                }
                .font(.system(size: 14))
                
                Text(LocalizedText(korean: "링크를 통해 만들 수 있답니다!", english: "links!").text)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.text2)
                
                Text(LocalizedText(
                    korean: "또는 Youtube 영상 공유시 \"더보기\"를 누르면, AINO앱 아이콘을 통해 노트를 바로 생성하실 수도 있습니다.",
                    english: "Alternatively, when sharing a YouTube video, tap \"More\" and you can create a note directly via the AINO app icon."
                ).text)
                .font(.system(size: 14))
                .foregroundStyle(Color.text2)
                
                Text(LocalizedText(korean: "AINO는 학습자 여러분들이 노트 생성과 동시에, 강의 속의 핵심 키워드가 되는 단어들과 더불어 구간별 요약 정보를 불러와서 학습에 도움이 되기 위해 뒤에서 열심히 작업을 진행합니다!", english: "AINO works hard behind the scenes to help your learning by extracting key keywords and section summaries from lectures as soon as you create notes!").text)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.text2)
            }
            
            // Q2
            VStack(alignment: .leading, spacing: 5) {
                Text(LocalizedText(korean: "2. 노트에선 어디까지 할 수 있어요?", english: "2. What can I do with notes?").text)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.text1)
                
                VStack(alignment: .leading, spacing: 5) {
                    Text(LocalizedText(korean: "노트는 크게 네 가지 영역으로 구분되어 있답니다", english: "Notes are divided into four main areas").text)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.text2)
                        .padding(.top, 14)
                    
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(alignment: .top, spacing: 0) {
                            Text("1. ")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.text2)
                            Text(LocalizedText(korean: "강의 시청 영역 : 학습자 여러분이 입력한 Youtube 링크의 강의를 바로 볼 수 있는 공간이에요!", english: "Video Viewing Area: Watch your YouTube lectures directly in this space!").text)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.text2)
                        }
                        
                        HStack(alignment: .top, spacing: 0) {
                            Text("2. ")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.text2)
                            Text(LocalizedText(korean: "요약 영역 : 내가 듣고있는 구간 뿐 아니라, 강의 속에서 내가 잘 이해가 가지 않았던 부분의 요약을 골라서 확인해 보세요! AINO는 구간별 요약 정보 제공을 통해, 학습자 여러분이 원하는 영역만을 쉽고 빠르게 요약본에 다가갈 수 있도록 도와줍니다! (iOS 18.* 이상, Apple Intelligence 연결 후)", english: "Summary Area: Check summaries not only of the current section but also parts you didn't understand well! AINO helps you quickly access summaries of specific areas through section-by-section summary information! (iOS 18.* or later, after Apple Intelligence connection)").text)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.text2)
                        }
                        
                        HStack(alignment: .top, spacing: 0) {
                            Text(attributedString)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.text2)
                        }
                        
                        HStack(alignment: .top, spacing: 0) {
                            Text("3. ")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.text2)
                            Text(LocalizedText(korean: "키워드 영역 : AINO가 노트 생성 시 처음 추출한 해당 강의의 중요한 단어들이에요! 혹시 모르는 단어가 있다면 가볍게 Apple Pencil을 가까이 가져다 올려 보세요! 우측 채팅창에서 AI가 바로 학습을 도와줄거에요! (Apple Pencil Pro만 해당, Apple Pencil은 터치 필요.)", english: "Keywords Area: Important words extracted from the lecture when AINO creates notes! If there's a word you don't know, gently bring your Apple Pencil close to it! AI will help you learn right away in the chat window on the right! (Apple Pencil Pro only, Apple Pencil requires touch.)").text)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.text2)
                        }
                        
                        HStack(alignment: .top, spacing: 0) {
                            Text("4. ")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.text2)
                            Text(LocalizedText(korean: "채팅 영역 : 무엇이든 물어보세요! AINO에 탑재된 AI가 학습자 여러분의 학습을 도와주는 비서가 되어 줄거에요!", english: "Chat Area: Ask anything! AINO's built-in AI will be your learning assistant!").text)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.text2)
                        }
                    }
                }
            }
        }
    }
}

#Preview(traits: .landscapeLeft) {
    GeometryReader { geometry in
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            // 프리뷰에서는 카드 크기를 보기 좋게 상한만 지정
            HelpView(allowsScrolling: false, maxContentHeight: nil, maxContentWidth: min(680, geometry.size.width * 0.85))
                .padding()
        }
    }
}
