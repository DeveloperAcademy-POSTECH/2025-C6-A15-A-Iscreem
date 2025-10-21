//
//  SummaryView.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI

struct SummaryView: View {
    @ObservedObject var viewModel: StudyViewModel
    
    /// 샘플 요약 데이터
    private let summaries = [
        Summary(
            id: 1,
            title: "#3. OSI 7 계층",
            items: [
                "데이터 통신에는 OSI 7계층이 존재.",
                "7계층 : 응용, 표현, 세션, 트랜스포트, 네트워크, 데이터링크, 물리",
                "각 계층을 분리 배제로 연결.",
                "각 계층을 연결하는 물리 매체는 이외에 같음.",
            ],
            progress: "3 / 8"
        ),
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            /// 헤더
            Text("AI가 구간별 요약을 제공합니다.")
                .font(.system(size: 15))
                .foregroundStyle(Color.text2)
                .padding(16)
            
            Divider()
                .background(Color.borderColor)
            
            /// 요약 리스트
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(summaries) { summary in
                        SummaryCard(summary: summary)
                    }
                }
                .padding(16)
            }
        }
        .background(Color.background1)
        .onAppear {
            updateSummaryContext()
        }
    }
    
    /// 요약 컨텍스트 업데이트
    private func updateSummaryContext() {
        let context = summaries.map { summary in
            "\(summary.title)\n" + summary.items.joined(separator: "\n")
        }.joined(separator: "\n\n")
        viewModel.summaryContext = context
        print("📋 [SummaryView] 컨텍스트 업데이트됨 - 길이: \(context.count)자")
        print("📋 [SummaryView] 컨텍스트 내용:\n\(context)")
    }
}

struct Summary: Identifiable, Equatable {
    let id: Int
    let title: String
    let items: [String]
    let progress: String
}

struct SummaryCard: View {
    let summary: Summary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(summary.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.text1)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.text3)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(
                    Array(summary.items.enumerated()),
                    id: \.offset
                ) { index, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundStyle(Color.text3)
                        Text(item)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.text2)
                    }
                }
            }
            
            HStack {
                Spacer()
                Text(summary.progress)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.text3)
            }
        }
        .padding(16)
        .background(Color.background2)
        .cornerRadius(12)
    }
}

#Preview(traits: .landscapeLeft) {
    SummaryView(viewModel: StudyViewModel())
}