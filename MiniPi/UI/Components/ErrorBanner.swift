//
//  ErrorBanner.swift
//  IosDevelopersGuide
//
//  Created by [Your Name]
//  Copyright © 2026. All rights reserved.
//

import SwiftUI

/// A non-blocking banner that displays warnings and info messages at the top of the screen.
/// This is designed for non-critical errors that don't block user interaction.
///
/// ## Usage Example
/// ```swift
/// var body: some View {
///     ZStack {
///         // Your main content
///         ContentView()
///
///         // Error banner overlay
///         if let failure = viewModel.failure {
///             ErrorBanner(
///                 failure: failure,
///                 onDismiss: { viewModel.clearError() }
///             )
///             .padding(.top, 50) // Account for safe area
///         }
///     }
/// }
/// ```
///
/// ## Design Philosophy
/// - **Non-Blocking**: User can still interact with the app
/// - **Self-Dismissing**: Can auto-dismiss after a timeout
/// - **Swipe to Dismiss**: User can swipe away or tap to dismiss
/// - **Severity-Based Styling**: Colors adapt to error severity
struct ErrorBanner: View {
    
    // MARK: - Properties
    
    let failure: Failure
    let onDismiss: () -> Void
    var autoDismiss: Bool = true
    var dismissAfter: Double = 5.0
    
    @State private var isVisible = false
    @State private var dragOffset: CGFloat = 0
    
    // MARK: - Computed Properties
    
    private var backgroundColor: Color {
        switch failure.severity {
        case .info:
            return .blue.opacity(0.9)
        case .warning:
            return .orange.opacity(0.9)
        case .critical:
            return .red.opacity(0.9)
        }
    }
    
    private var iconName: String {
        switch failure.severity {
        case .info:
            return "info.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .critical:
            return "xmark.circle.fill"
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack {
            if isVisible {
                HStack(spacing: 12) {
                    // Icon
                    Image(systemName: iconName)
                        .foregroundColor(.white)
                        .font(.title3)
                    
                    // Message
                    Text(failure.message)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    Spacer(minLength: 8)
                    
                    // Dismiss Button
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.8))
                            .font(.title3)
                    }
                    .accessibilityLabel("Dismiss")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(backgroundColor)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                .padding(.horizontal, 16)
                .offset(x: dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.width < 0 {
                                dragOffset = value.translation.width
                            }
                        }
                        .onEnded { value in
                            if value.translation.width < -50 {
                                dismiss()
                            } else {
                                dragOffset = 0
                            }
                        }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isVisible = true
            }
            
            if autoDismiss {
                DispatchQueue.main.asyncAfter(deadline: .now() + dismissAfter) {
                    if isVisible {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Methods
    
    private func dismiss() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isVisible = false
            dragOffset = 0
        }
        
        // Call onDismiss after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

// MARK: - Preview

#Preview("Warning Banner") {
    ZStack {
        Color.gray.opacity(0.1)
            .ignoresSafeArea()
        
        ErrorBanner(
            failure: NetworkFailure.timeout(),
            onDismiss: { print("Dismissed") }
        )
        .padding(.top, 50)
    }
}

#Preview("Info Banner") {
    ZStack {
        Color.gray.opacity(0.1)
            .ignoresSafeArea()
        
        ErrorBanner(
            failure: CacheFailure.writeFailed(),
            onDismiss: { print("Dismissed") }
        )
        .padding(.top, 50)
    }
}
