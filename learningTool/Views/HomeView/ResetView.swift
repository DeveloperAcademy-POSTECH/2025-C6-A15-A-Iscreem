//
//  ResetView.swift
//  learningtool
//
//  Created by Mumin on 10/28/25.
//

import SwiftUI
import SwiftData

struct ResetView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var notes: [Note]
    @Query private var folders: [Folder]
    
    @State private var confirmationText: String = ""
    
    let onClose: () -> Void
    
    private let requiredText = "초기화를 진행 하겠습니까."
    
    var body: some View {
        VStack(spacing: 0) {
            // 제목 영역
            VStack(alignment: .leading, spacing: 16) {
                Text("모든 노트가 초기화 됩니다!")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.text1)
                
                Text("이 작업은 실행 이후 복구할 수 없습니다.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color.text1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            Spacer()
            Spacer()
            
            // 입력창 영역
            VStack(alignment: .leading, spacing: 0) {
                Text(requiredText)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.text1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                    .background(Color.borderColor)
                    .padding(.vertical, 12)
                
                TextField("위 문장을 입력하세요.", text: $confirmationText)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.text1)
                    .background(Color.clear)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.gray.opacity(0.15))
            .cornerRadius(24)
            .padding(.horizontal, 20)
            
            Spacer()
            Spacer()
            
            // 버튼 영역
            HStack(spacing: 12) {
                Button(action: { onClose() }) {
                    Text("취소")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.text1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(20)
                }
                
                Button(action: { resetAllData() }) {
                    Text("초기화")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.errorColor)
                        .cornerRadius(20)
                }
                .disabled(!isConfirmationValid)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .frame(width: 300, height: 327)
        .background(Color.background1)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.borderColor, lineWidth: 1)
        )
    }
    
    private var isConfirmationValid: Bool {
        confirmationText == requiredText
    }
    
    private func resetAllData() {
        // 모든 노트 삭제
        for note in notes {
            modelContext.delete(note)
        }
        
        // 모든 폴더 삭제
        for folder in folders {
            modelContext.delete(folder)
        }
        
        // 변경사항 저장
        try? modelContext.save()
        
        // 닫기
        onClose()
    }
}

#Preview(traits: .landscapeLeft) {
    ResetView(onClose: { print("Close") })
        .padding()
}

