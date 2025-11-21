//
//  Font+Extension.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI

extension Font {
    /// Title Text: SF Pro Display Semibold, 32pt
    static let titleText = Font.system(size: 32, weight: .semibold, design: .default)
    
    /// Subtitle Text: SF Pro Display Medium, 24pt
    static let subtitleText = Font.system(size: 24, weight: .medium, design: .default)
    
    /// Body Text: SF Pro Text Medium, 18pt
    static let bodyText = Font.system(size: 18, weight: .medium, design: .default)
    
    /// Body Text Semibold: SF Pro Text Semibold, 18pt
    static let bodyTextSemibold = Font.system(size: 18, weight: .semibold, design: .default)
    
    /// Caption Text: SF Pro Text Medium, 14pt
    static let captionText = Font.system(size: 14, weight: .medium, design: .default)
    
    /// Button Text: SF Pro Display, 16pt
    static let buttonText = Font.system(size: 16, weight: .regular, design: .default)
    
    /// Chatting Text: SF Pro Text Regular, 16pt
    static let chattingText = Font.system(size: 16, weight: .regular, design: .default)
}
