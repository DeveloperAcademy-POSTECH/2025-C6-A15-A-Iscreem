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
    
    var body: some View {
        VStack(spacing: 0) {
            /// 헤더
            HStack(spacing: 8) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.text1)
                
                Text("도움말")
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
            
            /// 내용
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    /// Q1
                    VStack(alignment: .leading, spacing: 5) {
                        Text("#1. 노트는 무엇이고, 어떻게 활용 하나요?")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Color.text1)
                        
                        HStack(alignment: .top, spacing: 4) {
                            Text("A1.")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.text2)
                            
                            HStack(alignment: .firstTextBaseline, spacing: 0) {
                                Text("우측 하단의 ")
                                    .foregroundStyle(Color.text2)
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(Color.secondColor)
                                Text(" 버튼을 누르면, 노트를 추가할 수 있어요! 노트는 여러분이 수강하시는 Youtube 강의")
                                    .foregroundStyle(Color.text2)
                            }
                            .font(.system(size: 14))
                        }
                        
                        Text("링크를 통해 만들 수 있답니다!")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.text2)
                        
                        Text("SWAI는 학습자 여러분들이 노트 생성과 동시에, 강의 속의 핵심 키워드가 되는 단어들과 더불어 구간별 요약 정보를 불러와서 학습에 도움이 되기 위해 뒤에서 열심히 작업을 진행합니다!")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.text2)
                    }
                    
                    /// Q2
                    VStack(alignment: .leading, spacing: 5) {
                        Text("#2. 노트에선 어디까지 할 수 있어요?")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Color.text1)
                        
                        HStack(alignment: .top, spacing: 4) {
                            Text("A2.")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.text2)
                            
                            Text("#1에서 생성 했던 노트를 터치 하여 강의실로 입장해 보세요!")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.text2)
                        }
                        
                        VStack(alignment: .leading, spacing: 5) {
                            Text("강의실은 크게 네 가지 영역으로 구분 되어 있답니다")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.text2)
                                .padding(.top, 14)
                            
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(alignment: .top, spacing: 0) {
                                    Text("1. ")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.text2)
                                    Text("강의 시청 영역 : 학습자 여러분이 입력한 Youtube 링크의 강의를 바로 볼 수 있는 공간이에요!")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.text2)
                                }
                                
                                HStack(alignment: .top, spacing: 0) {
                                    Text("2. ")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.text2)
                                    Text("요약 영역 : 내가 듣고있는 구간 뿐 아니라, 강의 속에서 내가 잘 이해가 가지 않았던 부분의 요약을 골라서 확인해 보세요! SWAI는 구간별 요약 정보 제공을 통해, 학습자 여러분이 원하는 영역만을 쉽고 빠르게 요약본에 다가갈 수 있도록 도와줍니다!")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.text2)
                                }
                                
                                HStack(alignment: .top, spacing: 0) {
                                    Text("3. ")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.text2)
                                    Text("키워드 영역 : SWAI가 노트 생성 시 처음 추출한 해당 강의의 중요한 단어들이에요! 혹시 모르는 단어가 있다면 가볍게 Apple Pencil을 가까이 가져다 올려 보세요! 우측 채팅창에서 AI가 바로 학습을 도와줄거에요! (Apple Pencil Pro만 해당, Apple Pencil은 터치 필요.)")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.text2)
                                }
                                
                                HStack(alignment: .top, spacing: 0) {
                                    Text("4. ")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.text2)
                                    Text("채팅 영역 : 무엇이든 물어보세요! SWAI에 탑재된 {$model_name}이 학습자 여러분의 학습을 도와 주는 비서가 되어 줄거에요!")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.text2)
                                }
                            }
                        }
                    }
                    
                    /// Q3
                    VStack(alignment: .leading, spacing: 5) {
                        Text("#3. 노트/폴더를 지우고 싶어요!")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Color.text1)
                        
                        HStack(alignment: .top, spacing: 4) {
                            Text("A3.")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.text2)
                            
                            HStack(alignment: .top, spacing: 4) {
                                Text("우측 상단의")
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.text1)
                                Text("버튼을 누르면 노트/폴더를 편집할 수 있어요!")
                            }
                            .font(.system(size: 14))
                            .foregroundStyle(Color.text2)
                        }
                        
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(alignment: .top, spacing: 4) {
                                Text("혹시 전체 삭제를 원하신다면, 좌측 하단의")
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.text2)
                                Text("설정 페이지에서, 초기화를 진행할 수 있답니다!")
                            }
                            .font(.system(size: 14))
                            .foregroundStyle(Color.text2)
                            .padding(.top, 14)
                            
                            Text("다만, 초기화 작업은 한 번 진행이 이루어진 이후에는, 복구할 수 없으니, 신중 하게 선택해 주세요!")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.text2)
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 20)
                .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.background1)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.borderColor, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
}

#Preview(traits: .landscapeLeft) {
    GeometryReader { geometry in
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            HelpView()
                .frame(
                    width: min(680, geometry.size.width * 0.85),
                    height: min(620, geometry.size.height * 0.75)
                )
        }
    }
}
