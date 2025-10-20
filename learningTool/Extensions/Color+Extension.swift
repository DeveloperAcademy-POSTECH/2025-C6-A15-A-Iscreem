//
//  Color+Extension.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI

extension Color {
    /// Primary Color
    static let primaryColor = Color(hex: "3A506B")
    
    /// Second Color
    static let secondColor = Color(hex: "5BC0BE")
    
    /// Accent Color
    static let accentColor = Color(hex: "F4A261")
    
    /// Background Colors
    static let background1 = Color(hex: "F7F8FA")
    static let background2 = Color(hex: "E9ECEF")
    static let background3 = Color(hex: "1E1E1E")
    
    /// Text Colors
    static let text1 = Color(hex: "1A1A1A")
    static let text2 = Color(hex: "555555")
    static let text3 = Color(hex: "9CA3AF")
    
    /// Status Colors
    static let successColor = Color(hex: "4CAF50")
    static let errorColor = Color(hex: "E57373")
    static let borderColor = Color(hex: "D0D4D8")
    
    init(hex: String) {
        let hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanHex = hexString.hasPrefix("#") ?
            String(hexString.dropFirst()) : hexString
        let scanner = Scanner(string: cleanHex)
        
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        
        let red = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let green = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgbValue & 0x0000FF) / 255.0
        
        self.init(red: red, green: green, blue: blue)
    }
}