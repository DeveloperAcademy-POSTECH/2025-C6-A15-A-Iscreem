// UIEffects.swift
// 공용 글래스/백그라운드 확장 효과 폴백 구현
import SwiftUI

// MARK: - GlassEffectContainer
/// 글래스(유리) 배경을 깔아주는 간단한 컨테이너.
/// HomeView에서 사용한 동일 이름을 폴백 구현합니다.
public struct GlassEffectContainer<Content: View>: View {
    private let spacing: CGFloat
    private let content: () -> Content
    private let cornerRadius: CGFloat

    public init(spacing: CGFloat = 0, cornerRadius: CGFloat = 14, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.cornerRadius = cornerRadius
        self.content = content
    }

    public var body: some View {
        VStack(spacing: spacing) {
            content()
        }
        .padding(0)
        .glassEffect(cornerRadius: cornerRadius)
    }
}

// MARK: - View modifiers (glassEffect, backgroundExtensionEffect)
public extension View {
    /// 반투명 유리 같은 효과를 적용합니다.
    /// - Parameters:
    ///   - cornerRadius: 모서리 라운드
    ///   - insets: 내부 패딩이 필요하면 지정(기본 0)
    func glassEffect(cornerRadius: CGFloat = 14, insets: EdgeInsets = .init()) -> some View {
        modifier(GlassEffectModifier(cornerRadius: cornerRadius, insets: insets))
    }

    /// 배경을 안전영역 바깥까지 확장시키는 효과(폴백).
    /// iOS 15+에서는 .background(.ultraThinMaterial).ignoresSafeArea() 조합을 사용하고,
    /// 그 미만에서는 불투명도 낮은 시스템 배경색으로 대체합니다.
    func backgroundExtensionEffect(color: Color? = nil, edges: Edge.Set = .all) -> some View {
        modifier(BackgroundExtensionEffectModifier(color: color, edges: edges))
    }
}

// MARK: - GlassEffectModifier
private struct GlassEffectModifier: ViewModifier {
    let cornerRadius: CGFloat
    let insets: EdgeInsets

    func body(content: Content) -> some View {
        content
            .padding(insets)
            .background(glassBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
    }

    @ViewBuilder
    private var glassBackground: some View {
        if #available(iOS 15.0, *) {
            // 시스템 머티리얼 사용
            Color.clear
                .background(.ultraThinMaterial)
        } else {
            // 폴백: 반투명 시스템 배경
            Color(UIColor.systemBackground).opacity(0.6)
        }
    }
}

// MARK: - BackgroundExtensionEffectModifier
private struct BackgroundExtensionEffectModifier: ViewModifier {
    let color: Color?
    let edges: Edge.Set

    func body(content: Content) -> some View {
        if #available(iOS 15.0, *) {
            content
                .background(backgroundView)
                .ignoresSafeArea(.container, edges: edges)
        } else {
            content
                .background(backgroundView)
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        if let color {
            color
        } else if #available(iOS 15.0, *) {
            // 기본은 머티리얼
            AnyView(Color.clear.background(.ultraThinMaterial))
        } else {
            AnyView(Color(UIColor.systemBackground).opacity(0.6))
        }
    }
}
