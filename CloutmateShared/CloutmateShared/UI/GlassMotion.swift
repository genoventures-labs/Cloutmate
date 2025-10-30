//
//  GlassMotion.swift
//  Cloutmate
//
//  Glassmorphic Harmony UI - Motion & Animation Constants
//

import SwiftUI

// MARK: - Animation Timing Constants
enum GlassMotion {
    
    // MARK: - Durations
    enum Duration {
        static let tabSwitch: Double = 0.25
        static let modalOpen: Double = 0.3
        static let buttonPress: Double = 0.15
        static let refreshLoad: Double = 0.6
        static let ripple: Double = 0.3
        static let auroraPulse: Double = 3.0
        static let shimmer: Double = 1.5
    }
    
    // MARK: - Easing Curves
    enum Easing {
        static let tabSwitch = SwiftUI.Animation.cubicBezier(0.4, 0, 0.2, 1, duration: Duration.tabSwitch)
        static let modalOpen = SwiftUI.Animation.easeOut(duration: Duration.modalOpen)
        static let buttonPress = SwiftUI.Animation.linear(duration: Duration.buttonPress)
        static let refreshLoad = SwiftUI.Animation.easeInOut(duration: Duration.refreshLoad)
        static let spring = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)
    }
    
    // MARK: - Transform Values
    enum Transform {
        static let hoverScale: CGFloat = 1.015
        static let pressScale: CGFloat = 0.98
        static let tabSlide: CGFloat = 25
        static let modalInitialScale: CGFloat = 0.96
        static let modalFinalScale: CGFloat = 1.0
    }
    
    // MARK: - Shimmer Values
    enum Shimmer {
        static let gradientShift: CGFloat = 10 // degrees
        static let duration: Double = 1.5
    }
    
    // MARK: - Parallax Multipliers
    enum Parallax {
        static let background: CGFloat = 0.8
        static let content: CGFloat = 1.0
        static let overlay: CGFloat = 1.2
    }
    
    // MARK: - Bloom Effects
    enum Bloom {
        static let hoverIncrease: CGFloat = 0.20 // +20%
        static let focusGlow: CGFloat = 0.40 // 40% white
    }
    
    // MARK: - Animation Helpers
    struct AnimationHelpers {
        /// Creates a tab switch animation (fade + slide)
        static func tabSwitch() -> SwiftUI.Animation {
            Easing.tabSwitch
        }
        
        /// Creates a modal open animation (scale + fade)
        static func modalOpen() -> SwiftUI.Animation {
            Easing.modalOpen
        }
        
        /// Creates a button press animation (ripple + scale)
        static func buttonPress() -> SwiftUI.Animation {
            Easing.buttonPress
        }
        
        /// Creates a refresh/load animation
        static func refresh() -> SwiftUI.Animation {
            Easing.refreshLoad
        }
    }
}

// MARK: - Custom Animation Helper
extension Animation {
    static func cubicBezier(_ p1x: Double, _ p1y: Double, _ p2x: Double, _ p2y: Double, duration: Double) -> Animation {
        // SwiftUI doesn't have native cubic bezier, so we approximate with easeInOut
        return .easeInOut(duration: duration)
    }
}

// MARK: - Hover Effect View Modifier
struct HoverEffect: ViewModifier {
    @State private var isHovered = false
    
    let scaleEffect: CGFloat
    let animation: SwiftUI.Animation
    
    init(scale: CGFloat = GlassMotion.Transform.hoverScale, animation: SwiftUI.Animation = GlassMotion.Easing.spring) {
        self.scaleEffect = scale
        self.animation = animation
    }
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? scaleEffect : 1.0)
            .animation(animation, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

extension View {
    func glassHoverEffect(scale: CGFloat = GlassMotion.Transform.hoverScale) -> some View {
        modifier(HoverEffect(scale: scale))
    }
}

// MARK: - Float Lift Effect
struct FloatLiftEffect: ViewModifier {
    @State private var isHovered = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? GlassMotion.Transform.hoverScale : 1.0)
            .shadow(color: .black.opacity(isHovered ? 0.15 : 0.05), 
                   radius: isHovered ? 12 : 4, 
                   y: isHovered ? 8 : 2)
            .animation(GlassMotion.Easing.spring, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

extension View {
    func floatLift() -> some View {
        modifier(FloatLiftEffect())
    }
}

// MARK: - Ripple Effect Modifier
struct RippleEffect: ViewModifier {
    @State private var rippleScale: CGFloat = 0
    @State private var rippleOpacity: Double = 0
    
    let color: Color
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Circle()
                    .fill(color.opacity(0.3))
                    .scaleEffect(rippleScale)
                    .opacity(rippleOpacity)
            )
            .onTapGesture {
                withAnimation(GlassMotion.Easing.buttonPress) {
                    rippleScale = 2.0
                    rippleOpacity = 0.0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + GlassMotion.Duration.buttonPress) {
                    rippleScale = 0
                    rippleOpacity = 0
                }
            }
    }
}

extension View {
    func ripple(color: Color = .blue) -> some View {
        modifier(RippleEffect(color: color))
    }
}

// MARK: - Shimmer Effect
struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0),
                        Color.white.opacity(0.3),
                        Color.white.opacity(0)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .blendMode(.overlay)
            )
            .onAppear {
                withAnimation(Animation.linear(duration: GlassMotion.Duration.shimmer)
                    .repeatForever(autoreverses: false)) {
                    phase = 400
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerEffect())
    }
}

// MARK: - Auroral Pulse
struct AuroralPulse: ViewModifier {
    @State private var pulsePhase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .opacity(0.7 + 0.3 * Darwin.cos(pulsePhase))
            .onAppear {
                withAnimation(Animation.linear(duration: GlassMotion.Duration.auroraPulse)
                    .repeatForever(autoreverses: false)) {
                    pulsePhase = .pi * 2
                }
            }
    }
}

extension View {
    func auroralPulse() -> some View {
        modifier(AuroralPulse())
    }
}
