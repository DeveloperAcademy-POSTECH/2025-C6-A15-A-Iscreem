//
//  FolderDeleteView.swift
//  learningTool
//
//  Created on 2025-10-28.
//

import SwiftUI

struct FolderDeleteView: View {
    @Environment(\.dismiss) var dismiss
    
    var onDelete: () -> Void
    var onCancel: () -> Void
    
    var body: some View {
        GeometryReader { geo in
            // 화면 크기에 따라 카드 폭을 계산
            // - 작은 기기에서는 화면의 90%까지 사용
            // - 큰 기기에서는 최대 360pt로 제한
            let cardWidth = min(360, geo.size.width * 0.9)
            
            ZStack {
                // 반투명 배경
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                // 팝업 카드
                VStack(spacing: 0) {
                    // 제목
                    Text("폴더가 삭제 됩니다!")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.top, 24)
                        .padding(.horizontal, 24)
                    
                    // 설명 텍스트
                    Text("폴더 내에 있는 하위폴더들과, 노트들이 모두 삭제 됩니다. 삭제 이후 최대 7일까지 휴지통에서 복원할 수 있습니다.")
                        .font(.system(size: 13))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                        .padding(.top, 12)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    
                    Divider()
                    
                    // 버튼들
                    VStack(spacing: 0) {
                        // 삭제 버튼
                        Button(action: {
                            onDelete()
                        }) {
                            Text("삭제")
                                .font(.system(size: 17))
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        
                        Divider()
                        
                        // 취소 버튼
                        Button(action: {
                            onCancel()
                        }) {
                            Text("취소")
                                .font(.system(size: 17))
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                    }
                }
                .frame(width: cardWidth)
                .background(Color.white)
                .cornerRadius(14)
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
                .padding(.horizontal, 16) // 극단적으로 좁은 화면 대비
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview(traits: .landscapeLeft) {
    FolderDeleteView(
        onDelete: {
            print("삭제 버튼 클릭")
        },
        onCancel: {
            print("취소 버튼 클릭")
        }
    )
}
