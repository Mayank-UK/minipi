//
//  ResultType.swift
//  IosDevelopersGuide
//
//  Created by [Your Name]
//  Copyright © 2026. All rights reserved.
//

import Foundation

enum Result<T> {
    case success(T)
    case failure(Failure)
    
    var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }
    
    var isFailure: Bool {
        !isSuccess
    }
    
    var successValue: T? {
        if case .success(let value) = self {
            return value
        }
        return nil
    }
    
    var failureValue: Failure? {
        if case .failure(let failure) = self {
            return failure
        }
        return nil
    }
    
    func map<U>(_ transform: (T) -> U) -> Result<U> {
        switch self {
        case .success(let value):
            return .success(transform(value))
        case .failure(let failure):
            return .failure(failure)
        }
    }
    
    func flatMap<U>(_ transform: (T) -> Result<U>) -> Result<U> {
        switch self {
        case .success(let value):
            return transform(value)
        case .failure(let failure):
            return .failure(failure)
        }
    }
    
    func recover(with recover: (Failure) -> Result<T>) -> Result<T> {
        switch self {
        case .success:
            return self
        case .failure(let failure):
            return recover(failure)
        }
    }
    
    func get() throws -> T {
        switch self {
        case .success(let value):
            return value
        case .failure(let failure):
            throw failure
        }
    }
    
    func or(_ defaultValue: T) -> T {
        switch self {
        case .success(let value):
            return value
        case .failure:
            return defaultValue
        }
    }
    
    @discardableResult
    func onSuccess(_ onSuccess: (T) -> Void) -> Result<T> {
        if case .success(let value) = self {
            onSuccess(value)
        }
        return self
    }
    
    @discardableResult
    func onFailure(_ onFailure: (Failure) -> Void) -> Result<T> {
        if case .failure(let failure) = self {
            onFailure(failure)
        }
        return self
    }
}

extension Result: Equatable where T: Equatable {
    static func == (lhs: Result<T>, rhs: Result<T>) -> Bool {
        switch (lhs, rhs) {
        case (.success(let lhsValue), .success(let rhsValue)):
            return lhsValue == rhsValue
        case (.failure(let lhsFailure), .failure(let rhsFailure)):
            return lhsFailure.isEqual(to: rhsFailure)
        default:
            return false
        }
    }
}

@available(iOS 13.0, *)
extension Result: Sendable where T: Sendable {
}

extension Result: CustomStringConvertible {
    var description: String {
        switch self {
        case .success(let value):
            return "Success(\(value))"
        case .failure(let failure):
            return "Failure(\(failure))"
        }
    }
}
