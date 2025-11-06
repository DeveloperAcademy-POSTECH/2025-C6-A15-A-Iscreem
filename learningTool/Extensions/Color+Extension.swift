//
//  Color+Extension.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI

extension Color {
    /// Primary Color
    static let primaryColor = Color(#colorLiteral(red: 0.227451, green: 0.313725, blue: 0.419608, alpha: 1.0))
    
    /// Second Color
    static let secondColor = Color(#colorLiteral(red: 0.356863, green: 0.752941, blue: 0.745098, alpha: 1.0))
    
    /// Accent Color
    static let accentColor = Color(#colorLiteral(red: 0.956863, green: 0.635294, blue: 0.380392, alpha: 1.0))
    
    /// Background Colors
    static let background1 = Color(#colorLiteral(red: 0.968627, green: 0.972549, blue: 0.980392, alpha: 1.0))
    static let background2 = Color(#colorLiteral(red: 0.913725, green: 0.925490, blue: 0.937254, alpha: 1.0))
    static let background3 = Color(#colorLiteral(red: 0.117647, green: 0.117647, blue: 0.117647, alpha: 1.0))
    
    /// Text Colors
    static let text1 = Color(#colorLiteral(red: 0.101961, green: 0.101961, blue: 0.101961, alpha: 1.0))
    static let text2 = Color(#colorLiteral(red: 0.333333, green: 0.333333, blue: 0.333333, alpha: 1.0))
    static let text3 = Color(#colorLiteral(red: 0.611765, green: 0.639216, blue: 0.686275, alpha: 1.0))
    
    /// Status Colors
    static let successColor = Color(#colorLiteral(red: 0.298039, green: 0.686275, blue: 0.313725, alpha: 1.0))
    static let errorColor = Color(#colorLiteral(red: 0.898039, green: 0.450980, blue: 0.450980, alpha: 1.0))
    static let borderColor = Color(#colorLiteral(red: 0.815686, green: 0.831373, blue: 0.847059, alpha: 1.0))
    static let HoverColor = Color(#colorLiteral(red: 0.956863, green: 0.635294, blue: 0.380392, alpha: 1.0))
    
    // Leave the hex initializer for backward compatibility
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
