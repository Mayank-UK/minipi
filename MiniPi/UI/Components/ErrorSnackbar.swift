//
//  ErrorSnackbar.swift
//  IosDevelopersGuide
//
//  Created by [Your Name]
//  Copyright © 2026. All rights reserved.
//

import SwiftUI

/// A subtle notification that appears briefly at the bottom of the screen.
/// This is designed for info-level errors that don't require immediate attention.
///
/// ## Usage Example
/// ```swift
/// var body: some View {
///     VStack {
///         // Your main content
///         ContentView()
///
///         // Error snackbar at bottom
///         if let failure = viewModel.failure {
///             ErrorSnackbar(
///                 failure: failure,
///                 onDismiss: { viewModel.clearError() }
///             )
///         }
///     }
/// }
/// ```
///
/// ## Design Philosophy
/// - **Minimal Intrusion**: Small, subtle notification at bottom
/// - **Auto-Dismiss**: Short display time (3 seconds default)
/// - **Info-Focused**: Best for non-critical informational messages
/// - **Tap to Dismiss**: Easy to dismiss if desired
struct ErrorSnackbar: View {
    
    // MARK: - Properties
    
    let failure: Failure
    let onDismiss: () -> Void
    var dismissAfter: Double = 3.0
    
    @State private var isVisible = false
    @State private var workItem: DispatchWorkItem?
    
    // MARK: - Computed Properties
    
    private var backgroundColor: Color {
        switch failure.severity {
        case .info:
            return .blue
        case .warning:
            return .orange
        case .critical:
            return .red
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack {
            Spacer()
            
            if isVisible {
                HStack(spacing: 12) {
                    // Message
                    Text(failure.message)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    Spacer(minLength: 8)
                    
                    // Dismiss indicator
                    Image(systemName: "xmark")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.caption)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(backgroundColor)
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                .padding(.horizontal, 16)
                .padding(.bottom, 20) // Above safe area
                .onTapGesture {
                    dismiss()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            show()
        }
        .onDisappear {
            workItem?.cancel()
        }
        .onChange(of: failure.message) { _ in
            // Reset animation when failure changes
            isVisible = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                show()
            }
        }
    }
    
    // MARK: - Methods
    
    private func show() {
        // Cancel any existing dismiss timer
        workItem?.cancel()
        
        // Show with animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isVisible = true
        }
        
        // Auto-dismiss after specified time
        let newWorkItem = DispatchWorkItem {
            dismiss()
        }
        workItem = newWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + dismissAfter, execute: newWorkItem)
    }
    
    private func dismiss() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isVisible = false
        }
        
        // Call onDismiss after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

// MARK: - View Modifier for Easy Integration

extension View {
    
    /// Presents an error snackbar when a failure is available
    /// - Parameters:
    ///   - failure: Optional failure to display
    ///   - onDismiss: Callback when snackbar is dismissed
    /// - Returns: A view with error snackbar functionality
    func errorSnackbar(
        failure: Failure?,
        onDismiss: @escaping () -> Void
    ) -> some View {
        self.overlay(
            Group {
                if let failure = failure {
                    ErrorSnackbar(
                        failure: failure,
                        onDismiss: onDismiss
                    )
                }
            }
        )
    }
}

// MARK: - Preview

#Preview("Info Snackbar") {
    ZStack {
        Color.gray.opacity(0.1)
            .ignoresSafeArea()
        
        VStack {
            Text("Main Content Here")
                .font(.title)
            Spacer()
        }
        .errorSnackbar(
            failure: CacheFailure.notFound(),
            onDismiss: { print("Dismissed") }
        )
    }
}

#Preview("Warning Snackbar") {
    ZStack {
        Color.gray.opacity(0.1)
            .ignoresSafeArea()
        
        VStack {
            Text("Main Content Here")
                .font(.title)
            Spacer()
        }
        .errorSnackbar(
            failure: NetworkFailure.timeout(),
            onDismiss: { print("Dismissed") }
        )
    }
}
