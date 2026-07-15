//
//  UseCaseModule.swift
//  IosDevelopersGuide
//
//  Mirrors the Android use-case `@Provides` entries (unscoped by default):
//  a fresh use-case instance per resolve, each backed by the repository module.
//

import FactoryKit

extension Container {
    var fetchPostsUseCase: Factory<FetchPostsUseCase> {
        /// Unscoped — a new instance per injection, like Hilt's default `@Provides`.
        Factory(self) {
            FetchPostsUseCase(repository: self.postRepository())
        }
    }
}
