//
//  ShowErrorView.swift
//  IosDevelopersGuide
//
//  Created by [Your Name]
//  Copyright © 2026. All rights reserved.
//

import SwiftUI

/// A full-screen error view that displays user-friendly error messages with retry functionality.
/// This is designed for critical errors that block the UI and require user action to proceed.
///
/// ## Usage Example
/// ```swift
/// switch result {
/// case .success(let posts):
///     PostsListView(posts: posts)
/// case .failure(let failure):
///     ShowErrorView(
///         failure: failure,
///         onRetry: { viewModel.fetchPosts() }
///     )
/// }
/// ```
///
/// ## Design Philosophy
/// - **User-Friendly**: Shows clear, actionable error messages
/// - **Severity-Aware**: Icons and styling adapt to error severity
/// - **Action-Oriented**: Provides retry functionality for recovery
/// - **Professional Design**: Consistent with iOS design patterns
struct ErrorView: View {
    
    // MARK: - Properties
    
    let failure: Failure
    let onRetry: () -> Void
    
    // MARK: - Computed Properties
    
    private var iconName: String {
        failure.severity.iconName
    }
    
    private var iconColor: Color {
        switch failure.severity {
        case .info:
            return .blue
        case .warning:
            return .orange
        case .critical:
            return .red
        }
    }
    
    private var title: String {
        switch failure.severity {
        case .info:
            return "Information"
        case .warning:
            return "Warning"
        case .critical:
            return "Error"
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Error Icon
            Image(systemName: iconName)
                .font(.system(size: 64))
                .foregroundColor(iconColor)
                .accessibilityLabel("Error icon")
            
            // Error Title
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
            
            // Error Message
            Text(failure.message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)
            
            // Additional Information (Development Mode)
            #if DEBUG
            if let technicalDetails = failure.technicalDetails {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Technical Details:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    Text(technicalDetails)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal, 32)
            }
            #endif
            
            Spacer()
            
            // Retry Button
            Button(action: onRetry) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(iconColor)
                .cornerRadius(12)
            }
            .padding(.horizontal, 32)
            .accessibilityLabel("Retry button")
            .accessibilityHint("Attempts the operation again")
            
            Spacer()
        }
        .background(Color(.systemGroupedBackground))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Error view")
    }
}

// MARK: - Preview

#Preview("Network Error") {
    ErrorView(
        failure: NetworkFailure.timeout(),
        onRetry: { print("Retry tapped") }
    )
}

#Preview("Server Error") {
    ErrorView(
        failure: ServerFailure.internalServerError(),
        onRetry: { print("Retry tapped") }
    )
}

#Preview("Cache Error") {
    ErrorView(
        failure: CacheFailure.notFound(),
        onRetry: { print("Retry tapped") }
    )
}
