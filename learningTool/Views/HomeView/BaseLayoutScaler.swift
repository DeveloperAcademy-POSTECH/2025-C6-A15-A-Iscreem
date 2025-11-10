// BaseLayoutScaler.swift
import SwiftUI

/// A tiny helper to scale layout metrics from a base design size to the current container size.
public struct BaseLayoutScaler {
    private let proxy: GeometryProxy
    private let base: CGSize
    
    /// Create a scaler using a GeometryProxy and a base design size (e.g., 1366x1024).
    public init(proxy: GeometryProxy, base: CGSize) {
        self.proxy = proxy
        self.base = base
    }
    
    /// Scale a horizontal value based on width ratio (currentWidth / baseWidth).
    public func w(_ value: CGFloat) -> CGFloat {
        guard base.width > 0 else { return value }
        return value * (proxy.size.width / base.width)
    }
    
    /// Scale a vertical value based on height ratio (currentHeight / baseHeight).
    public func h(_ value: CGFloat) -> CGFloat {
        guard base.height > 0 else { return value }
        return value * (proxy.size.height / base.height)
    }
    
    /// Scale uniformly using the smaller of width/height scale factors.
    public func uni(_ value: CGFloat) -> CGFloat {
        let sx = base.width > 0 ? (proxy.size.width / base.width) : 1
        let sy = base.height > 0 ? (proxy.size.height / base.height) : 1
        return value * min(sx, sy)
    }
    
    /// Compute a sidebar width using a ratio of the current container width.
    /// Example: ratio = 256 / (256 + 762) for an iPad landscape baseline.
    public func sidebarWidth(ratio: CGFloat) -> CGFloat {
        max(0, proxy.size.width * ratio)
    }
}

/// Convenience factory for HomeView.LayoutMetrics computed from a BaseLayoutScaler.
extension BaseLayoutScaler {
    func homeViewMetrics() -> HomeView.LayoutMetrics {
        HomeView.LayoutMetrics(
            searchMinWidth: w(220),
            searchMaxWidth: w(320),
            searchHeight: h(36),
            sortButtonSize: uni(36),
            toggleWidth: w(116),
            toggleHeight: h(36),
            addButtonLegacyDiameter: uni(60),
            addButtonLegacyIcon: uni(30),
            addButtonModernSide: uni(44),
            overlayPadding: uni(32),
            menuButtonSide: uni(32)
        )
    }
}

