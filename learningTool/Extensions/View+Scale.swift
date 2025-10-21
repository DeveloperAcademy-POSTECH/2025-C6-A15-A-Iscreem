//
//  View+Scale.swift
//  learningtool
//
//  Created by Mumin on 10/21/25.
//

import SwiftUI

// 화면 크기에 따른 스케일 팩터를 제공하는 Environment Key
private struct ScaleFactorKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.0
}

extension EnvironmentValues {
    var scaleFactor: CGFloat {
        get { self[ScaleFactorKey.self] }
        set { self[ScaleFactorKey.self] = newValue }
    }
}

extension View {
    func scaleFactorEnvironment(_ factor: CGFloat) -> some View {
        environment(\.scaleFactor, factor)
    }
}

// 스케일 계산 유틸리티
struct ScaleCalculator {
    // 기준 화면 크기 (11인치 iPad Pro landscape 기준)
    // 11인치 iPad Pro: 1194 x 834 points (landscape)
    static let referenceWidth: CGFloat = 1194
    static let referenceHeight: CGFloat = 834
    
    static func calculateScaleFactor(for size: CGSize) -> CGFloat {
        // 가로 모드 기준으로 너비를 사용하여 scale factor 계산
        let widthScale = size.width / referenceWidth
        let heightScale = size.height / referenceHeight
        
        // 더 작은 값을 사용하여 화면에 맞게 조정
        return min(widthScale, heightScale)
    }
    
    static func scaled(_ value: CGFloat, with factor: CGFloat) -> CGFloat {
        return value * factor
    }
}

