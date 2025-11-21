//
//  Font+Extension.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI

extension Font {
    /// Title Text: SF Pro Display Semibold, 28pt
    static let titleText = Font.system(size: 28, weight: .semibold, design: .default)
    
    /// Subtitle Text: SF Pro Display Medium, 22pt
    static let subtitleText = Font.system(size: 22, weight: .medium, design: .default)
    
    /// Body Text: SF Pro Text Medium, 16pt
    static let bodyText = Font.system(size: 16, weight: .medium, design: .default)
    
    /// Body Text Semibold: SF Pro Text Semibold, 16pt
    static let bodyTextSemibold = Font.system(size: 16, weight: .semibold, design: .default)
    
    /// Caption Text: SF Pro Text Medium, 13pt
    static let captionText = Font.system(size: 13, weight: .medium, design: .default)
    
    /// Button Text: SF Pro Display, 15pt
    static let buttonText = Font.system(size: 15, weight: .regular, design: .default)
    
    /// Chatting Text: SF Pro Text Regular, 12pt
    static let chattingText = Font.system(size: 12, weight: .regular, design: .default)
}
