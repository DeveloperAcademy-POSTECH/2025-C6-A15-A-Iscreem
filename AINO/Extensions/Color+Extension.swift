//
//  Color+Extension.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI

extension Color {
    // MARK: - Brand Colors (고정)
    static let primaryColor = Color(hex: "3A506B")
    static let secondColor  = Color(hex: "5BC0BE")
    static let accentColor  = Color(hex: "F4A261")
    static let successColor = Color(hex: "4CAF50")
    static let errorColor   = Color(hex: "E57373")
    static let HoverColor   = Color(hex: "F4A261")

    // MARK: - Dynamic Backgrounds
    // 라이트: 기존 값 유지 / 다크: 어두운 톤으로 전환
    static let background1: Color = Color(dynamicLight: UIColor(hex: "F7F8FA"),
                                          dark: UIColor(hex: "121314")) // 메인 배경
    static let background2: Color = Color(dynamicLight: UIColor(hex: "E9ECEF"),
                                          dark: UIColor(hex: "1C1E21")) // 카드/보조 배경
    static let background3: Color = Color(dynamicLight: UIColor(hex: "1E1E1E"),
                                          dark: UIColor(hex: "0D0E10")) // 미디어/딥 배경

    // MARK: - Dynamic Text
    // 다크에서 가독성을 위해 흰색/밝은 회색 계열로 전환
    static let text1: Color = Color(dynamicLight: UIColor(hex: "1A1A1A"),
                                    dark: .white) // 주요 본문/제목
    static let text2: Color = Color(dynamicLight: UIColor(hex: "555555"),
                                    dark: UIColor(white: 0.85, alpha: 1.0)) // 보조 텍스트
    static let text3: Color = Color(dynamicLight: UIColor(hex: "9CA3AF"),
                                    dark: UIColor(white: 0.70, alpha: 1.0)) // 캡션/힌트

    // MARK: - Dynamic Border
    static let borderColor: Color = Color(dynamicLight: UIColor(hex: "D0D4D8"),
                                          dark: UIColor(white: 1.0, alpha: 0.18))
}

// MARK: - Hex helpers + Dynamic providers

extension UIColor {
    convenience init(hex: String) {
        let hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanHex = hexString.hasPrefix("#") ? String(hexString.dropFirst()) : hexString
        var rgb: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&rgb)
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}

extension Color {
    // 기존 hex 이니셜라이저(고정 컬러가 필요할 때 사용)
    init(hex: String) {
        self = Color(UIColor(hex: hex))
    }

    // iOS의 trait에 따라 라이트/다크 동적으로 바뀌는 컬러
    init(dynamicLight light: UIColor, dark: UIColor) {
        self = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? dark : light
        })
    }
}
