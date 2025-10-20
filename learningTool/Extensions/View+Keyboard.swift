//
//  View+Keyboard.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI

extension View {
    /// 키보드가 화면을 덮도록 설정 (화면 밀림 방지)
    func keyboardOverlay() -> some View {
        self.ignoresSafeArea(.keyboard, edges: .bottom)
    }
}