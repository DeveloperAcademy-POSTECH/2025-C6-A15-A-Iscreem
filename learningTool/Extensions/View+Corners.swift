//
//  View+Corners.swift
//  learningTool
//
//  Created by coulson on 10/30/25.
//
//  특정 코너만 둥글게 처리하는 공용 유틸

import SwiftUI
import UIKit

public extension View {
    /// 특정 코너만 둥글게 처리
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

public struct RoundedCorner: Shape {
    public var radius: CGFloat = .infinity
    public var corners: UIRectCorner = .allCorners
    
    public func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
