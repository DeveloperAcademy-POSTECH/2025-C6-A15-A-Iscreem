// DestructiveConfirmAlertView.swift
import SwiftUI

struct DestructiveConfirmAlertView: View {
    let title: String
    let message: String
    let confirmTitle: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.errorColor)
                .padding(.top, 18)
                .padding(.horizontal, 20)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Color.text2)
                .multilineTextAlignment(.center)
                .padding(.top, 10)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            Divider()
            HStack(spacing: 0) {
                Button {
                    onCancel()
                } label: {
                    Text("취소")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                Divider()
                Button {
                    onConfirm()
                } label: {
                    Text(confirmTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.errorColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.borderColor, lineWidth: 1))
    }
}
