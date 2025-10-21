//
//  SummaryView.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI

/// SwiftData 연계를 염두에 둔 요약 레코드 모델(메모리 상 구성)
/// 나중에 SwiftData를 붙일 때 @Model 로 전환하고, 저장/로드 파이프만 연결하면 됩니다.
struct Summary: Identifiable, Hashable {
    let id: UUID            // 챕터 UUID에 매핑
    let title: String       // 챕터 목차형 제목(한 문장)
    let items: [String]     // 4줄 요약 (한 문장씩)
    let progress: String    // "N / 총개수"
}

struct SummaryView: View {
    let scaleFactor: CGFloat
    
    @State private var currentPage: Int = 0
    
    // MARK: - 하드코딩된 샘플 데이터
    private let sampleSummaries: [Summary] = [
        Summary(
            id: UUID(),
            title: "네트워크 기본 개념과 OSI 7계층 모델 소개",
            items: [
                "네트워크는 컴퓨터와 장치들이 서로 연결되어 데이터를 주고받는 시스템입니다",
                "OSI 7계층 모델은 네트워크 통신의 표준 프레임워크로 각 계층이 특정 역할을 수행합니다",
                "물리 계층부터 응용 계층까지 각각의 계층은 독립적으로 동작하며 상호 연동됩니다",
                "계층화 구조를 통해 네트워크 문제를 효율적으로 진단하고 해결할 수 있습니다"
            ],
            progress: "1 / 8"
        ),
        Summary(
            id: UUID(),
            title: "데이터 링크 계층과 MAC 주소의 역할",
            items: [
                "데이터 링크 계층은 인접한 노드 간의 신뢰성 있는 데이터 전송을 담당합니다",
                "MAC 주소는 네트워크 인터페이스 카드에 할당된 고유한 물리적 주소입니다",
                "프레임 단위로 데이터를 전송하며 오류 검출 및 수정 기능을 제공합니다",
                "스위치가 이 계층에서 동작하며 MAC 주소를 기반으로 프레임을 전달합니다"
            ],
            progress: "2 / 8"
        ),
        Summary(
            id: UUID(),
            title: "OSI 7 계층",
            items: [
                "데이터 통신에는 OSI 7계층이 존재.",
                "7계층 : 응용, 표현, 세션, 트랜스포트, 네트워크, 데이터링크, 물리",
                "각 계층은 물리 매체로 연결됨.",
                "각 계층을 연결하는 물리 매체는 아래와 같음.",
                "네트워크, 데이터링크, 물리 요소"
            ],
            progress: "3 / 8"
        ),
        Summary(
            id: UUID(),
            title: "네트워크 계층과 IP 프로토콜의 이해",
            items: [
                "네트워크 계층은 패킷의 라우팅과 전달 경로를 결정하는 역할을 합니다",
                "IP 주소는 논리적 주소로 네트워크에서 장치를 식별하는 데 사용됩니다",
                "라우터가 이 계층에서 동작하며 최적의 경로를 찾아 패킷을 전달합니다",
                "IPv4와 IPv6가 있으며 주소 고갈 문제를 해결하기 위해 IPv6로 전환 중입니다"
            ],
            progress: "4 / 8"
        ),
        Summary(
            id: UUID(),
            title: "전송 계층의 TCP와 UDP 프로토콜 비교",
            items: [
                "전송 계층은 종단 간 신뢰성 있는 데이터 전송을 보장합니다",
                "TCP는 연결 지향적이며 신뢰성 있는 데이터 전송을 제공합니다",
                "UDP는 비연결형 프로토콜로 빠른 전송이 필요한 경우 사용됩니다",
                "포트 번호를 사용하여 여러 응용 프로그램이 동시에 네트워크를 사용할 수 있습니다"
            ],
            progress: "5 / 8"
        ),
        Summary(
            id: UUID(),
            title: "응용 계층의 다양한 프로토콜과 서비스",
            items: [
                "응용 계층은 사용자와 가장 가까운 계층으로 다양한 네트워크 서비스를 제공합니다",
                "HTTP는 웹 브라우징에 사용되며 요청-응답 방식으로 동작합니다",
                "FTP는 파일 전송에, SMTP는 이메일 전송에 사용되는 프로토콜입니다",
                "DNS는 도메인 이름을 IP 주소로 변환하는 중요한 서비스입니다"
            ],
            progress: "6 / 8"
        ),
        Summary(
            id: UUID(),
            title: "네트워크 보안과 암호화 기술",
            items: [
                "네트워크 보안은 데이터의 기밀성, 무결성, 가용성을 보장합니다",
                "SSL/TLS는 암호화된 통신 채널을 제공하여 데이터를 보호합니다",
                "방화벽은 네트워크 트래픽을 모니터링하고 제어하는 보안 장치입니다",
                "VPN은 공용 네트워크를 통해 안전한 사설 네트워크 연결을 제공합니다"
            ],
            progress: "7 / 8"
        ),
        Summary(
            id: UUID(),
            title: "클라우드 컴퓨팅과 네트워크 가상화",
            items: [
                "클라우드 컴퓨팅은 인터넷을 통해 컴퓨팅 리소스를 제공하는 서비스입니다",
                "네트워크 가상화는 물리적 네트워크를 논리적으로 분할하여 효율성을 높입니다",
                "SDN은 소프트웨어를 통해 네트워크를 중앙에서 제어하는 기술입니다",
                "엣지 컴퓨팅은 데이터를 가까운 곳에서 처리하여 지연 시간을 줄입니다"
            ],
            progress: "8 / 8"
        )
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 헤더
            HStack {
                VStack(alignment: .leading, spacing: ScaleCalculator.scaled(4, with: scaleFactor)) {
                    Text("AI가 구간별 요약을 제공합니다.")
                        .font(.system(size: ScaleCalculator.scaled(15, with: scaleFactor)))
                        .foregroundStyle(Color.text2)
                    
                    Rectangle()
                        .fill(Color.text2)
                        .frame(height: 1)
                }
                .fixedSize()
                
                Spacer()
            }
            .padding(.horizontal, ScaleCalculator.scaled(16, with: scaleFactor))
            .padding(.top, ScaleCalculator.scaled(16, with: scaleFactor))
            .padding(.bottom, ScaleCalculator.scaled(12, with: scaleFactor))

            // 요약 콘텐츠 영역 (302 x 204)
            ZStack {
                // 흰색 배경
                RoundedRectangle(cornerRadius: ScaleCalculator.scaled(12, with: scaleFactor))
                    .fill(.white)
                    .frame(
                        width: ScaleCalculator.scaled(302, with: scaleFactor),
                        height: ScaleCalculator.scaled(204, with: scaleFactor)
                    )
                
                // 메인 콘텐츠
                ScrollView {
                    VStack(alignment: .leading, spacing: ScaleCalculator.scaled(8, with: scaleFactor)) {
                        // 제목
                        Text("#\(currentPage + 1). \(sampleSummaries[currentPage].title)")
                            .font(.system(size: ScaleCalculator.scaled(14, with: scaleFactor), weight: .semibold))
                            .foregroundStyle(Color.text1)
                            .lineLimit(2)
                            .padding(.bottom, ScaleCalculator.scaled(2, with: scaleFactor))
                        
                        // 불릿 포인트들
                        VStack(alignment: .leading, spacing: ScaleCalculator.scaled(6, with: scaleFactor)) {
                            ForEach(Array(sampleSummaries[currentPage].items.enumerated()), id: \.offset) { _, line in
                                HStack(alignment: .top, spacing: ScaleCalculator.scaled(6, with: scaleFactor)) {
                                    Text("•")
                                        .font(.system(size: ScaleCalculator.scaled(12, with: scaleFactor)))
                                        .foregroundStyle(Color.text3)
                                    Text(line)
                                        .font(.system(size: ScaleCalculator.scaled(12, with: scaleFactor)))
                                        .foregroundStyle(Color.text2)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    .padding(ScaleCalculator.scaled(10, with: scaleFactor))
                }
                .frame(
                    width: ScaleCalculator.scaled(302, with: scaleFactor),
                    height: ScaleCalculator.scaled(204, with: scaleFactor)
                )
                
                // 좌측 화살표
                HStack {
                    Button(action: {
                        withAnimation {
                            if currentPage > 0 {
                                currentPage -= 1
                            }
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: ScaleCalculator.scaled(18, with: scaleFactor)))
                            .foregroundStyle(currentPage > 0 ? Color.text2 : Color.text3.opacity(0.3))
                            .padding(ScaleCalculator.scaled(8, with: scaleFactor))
                    }
                    .buttonStyle(.plain)
                    .disabled(currentPage == 0)
                    
                    Spacer()
                    
                    // 우측 화살표
                    Button(action: {
                        withAnimation {
                            if currentPage < sampleSummaries.count - 1 {
                                currentPage += 1
                            }
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: ScaleCalculator.scaled(18, with: scaleFactor)))
                            .foregroundStyle(currentPage < sampleSummaries.count - 1 ? Color.text2 : Color.text3.opacity(0.3))
                            .padding(ScaleCalculator.scaled(8, with: scaleFactor))
                    }
                    .buttonStyle(.plain)
                    .disabled(currentPage == sampleSummaries.count - 1)
                }
                .frame(width: ScaleCalculator.scaled(302, with: scaleFactor))
                
                // 우하단 페이지 인디케이터
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(sampleSummaries[currentPage].progress)
                            .font(.system(size: ScaleCalculator.scaled(13, with: scaleFactor)))
                            .padding(.horizontal, ScaleCalculator.scaled(10, with: scaleFactor))
                            .padding(.vertical, ScaleCalculator.scaled(6, with: scaleFactor))
                            .background(Color.background2.opacity(0.9))
                            .cornerRadius(ScaleCalculator.scaled(8, with: scaleFactor))
                            .foregroundStyle(Color.text3)
                            .padding(ScaleCalculator.scaled(8, with: scaleFactor))
                    }
                }
                .frame(
                    width: ScaleCalculator.scaled(302, with: scaleFactor),
                    height: ScaleCalculator.scaled(204, with: scaleFactor)
                )
            }
            .frame(
                width: ScaleCalculator.scaled(302, with: scaleFactor),
                height: ScaleCalculator.scaled(204, with: scaleFactor)
            )
            .padding(.horizontal, ScaleCalculator.scaled(16, with: scaleFactor))
            .padding(.bottom, ScaleCalculator.scaled(16, with: scaleFactor))
        }
        .frame(
            width: ScaleCalculator.scaled(334, with: scaleFactor),
            height: ScaleCalculator.scaled(268, with: scaleFactor)
        )
        .background(Color.background2)
        .cornerRadius(ScaleCalculator.scaled(12, with: scaleFactor))
    }
}

#Preview(traits: .landscapeLeft) {
    SummaryView(scaleFactor: 1.0)
}
