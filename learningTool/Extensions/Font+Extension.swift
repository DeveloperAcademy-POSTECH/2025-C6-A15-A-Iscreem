//
//  Font+Extension.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI

extension Font {
    /// Title Text: SF Pro Display Semibold, 28pt
    static let titleText = Font.custom("SFProDisplay-Semibold", size: 28)
    
    /// Subtitle Text: SF Pro Display Medium, 22pt
    static let subtitleText = Font.custom("SFProDisplay-Medium", size: 22)
    
    /// Body Text: SF Pro Text Medium, 16pt
    static let bodyText = Font.custom("SFProText-Medium", size: 16)
    
    /// Caption Text: SF Pro Text Medium, 13pt
    static let captionText = Font.custom("SFProText-Medium", size: 13)
    
    /// Button Text: SF Pro Display, 15pt
    static let buttonText = Font.custom("SFProDisplay-Regular", size: 15)
    
    /// Chatting Text: SF Pro Text Regular, 12pt
    static let chattingText = Font.custom("SFProText-Regular", size: 12)
}