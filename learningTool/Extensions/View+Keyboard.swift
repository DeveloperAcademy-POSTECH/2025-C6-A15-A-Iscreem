//
//  View+Keyboard.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI

import Combine

/// Adds bottom padding equal to the keyboard height minus the bottom safe area.
private struct KeyboardAdaptive: ViewModifier {
    let base: CGFloat
    @State private var keyboardHeight: CGFloat = 0
    @State private var bottomSafeArea: CGFloat = 0

    func body(content: Content) -> some View {
        content
            // base(기본 하단 여백) + 키보드 높이 - 하단 세이프에어리어
            .padding(.bottom, base + max(0, keyboardHeight - bottomSafeArea))
            .background(
                GeometryReader { proxy in
                    Color.clear.onAppear { bottomSafeArea = proxy.safeAreaInsets.bottom }
                }
            )
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { note in
                guard
                    let ui = note.userInfo,
                    let end = (ui[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
                else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    keyboardHeight = end.height
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
                guard
                    let ui = note.userInfo,
                    let end = (ui[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
                else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    keyboardHeight = end.height
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.easeInOut(duration: 0.25)) {
                    keyboardHeight = 0
                }
            }
    }
}

public extension View {
    /// 키보드가 화면을 덮도록 설정 (화면 밀림 방지)
    func keyboardOverlay() -> some View {
        self.ignoresSafeArea(.keyboard, edges: .bottom)
    }
    
    /// 키보드 높이만큼 하단 패딩을 자동으로 추가 (base: 추가 하단 패딩)
        func keyboardAdaptivePadding(_ base: CGFloat = 0) -> some View {
            self.modifier(KeyboardAdaptive(base: base))
        }
    }

    // MARK: - Shift whole view with keyboard (for centered modals)
    private struct KeyboardShift: ViewModifier {
        let extra: CGFloat
        @State private var keyboardHeight: CGFloat = 0
        @State private var bottomSafeArea: CGFloat = 0
        @State private var viewRect: CGRect = .zero
        @State private var screenHeight: CGFloat = UIScreen.main.bounds.height

        func body(content: Content) -> some View {
            content
                // Move the card only as much as needed so its bottom stays `extra` pts above the keyboard.
                .offset(y: -computedShift())
                .background(
                    GeometryReader { proxy in
                        let rect = proxy.frame(in: .global)
                        Color.clear
                            .onAppear {
                                bottomSafeArea = proxy.safeAreaInsets.bottom
                                screenHeight = UIScreen.main.bounds.height
                                viewRect = rect
                            }
                            .onChange(of: rect) { _, newValue in
                                viewRect = newValue
                            }
                    }
                )
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { note in
                    guard
                        let ui = note.userInfo,
                        let end = (ui[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
                    else { return }
                    withAnimation(.easeInOut(duration: 0.25)) { keyboardHeight = end.height }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
                    guard
                        let ui = note.userInfo,
                        let end = (ui[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
                    else { return }
                    withAnimation(.easeInOut(duration: 0.25)) { keyboardHeight = end.height }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                    withAnimation(.easeInOut(duration: 0.25)) { keyboardHeight = 0 }
                }
        }

        private func computedShift() -> CGFloat {
            // No keyboard → no shift
            if keyboardHeight <= 0 { return 0 }
            // Keyboard top in global coords
            let keyboardTop = screenHeight - keyboardHeight
            // Desired bottom of the view = `extra` pts above the keyboard
            let desiredBottom = keyboardTop - extra
            // If the view's bottom is below the desired bottom, move up by the overlap
            let overlap = viewRect.maxY - desiredBottom
            return max(0, overlap)
        }
    }

    public extension View {
        /// Centered modal/dialog 전체를 키보드 높이만큼 위로 이동
        func keyboardShift(_ extra: CGFloat = 0) -> some View {
            self.modifier(KeyboardShift(extra: extra))
        }
    }
