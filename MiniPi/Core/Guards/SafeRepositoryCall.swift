//
//  safeRepositoryCall.swift
//  IosDevelopersGuide
//
//  Created by [Your Name]
//  Copyright © 2026. All rights reserved.
//

import Foundation

func safeRepositoryCall<T>(
    call: @escaping () async throws -> T,
    onNetworkError: ((NetworkException) async -> Result<T>)? = nil,
    onServerError: ((ServerException) async -> Result<T>)? = nil,
    onDatabaseError: ((DatabaseException) async -> Result<T>)? = nil,
    onDecodingError: ((DecodingException) async -> Result<T>)? = nil
) async -> Result<T> {
    do {
        let result = try await call()
        return .success(result)
        
    } catch let networkException as NetworkException {
        if let fallback = onNetworkError {
            return await fallback(networkException)
        } else {
            return .failure(ExceptionMapper.mapExceptionToFailure(networkException))
        }
        
    } catch let serverException as ServerException {
        if let fallback = onServerError {
            return await fallback(serverException)
        } else {
            return .failure(ExceptionMapper.mapExceptionToFailure(serverException))
        }
        
    } catch let databaseException as DatabaseException {
        if let fallback = onDatabaseError {
            return await fallback(databaseException)
        } else {
            return .failure(ExceptionMapper.mapExceptionToFailure(databaseException))
        }
        
    } catch let decodingException as DecodingException {
        if let fallback = onDecodingError {
            return await fallback(decodingException)
        } else {
            return .failure(ExceptionMapper.mapExceptionToFailure(decodingException))
        }
        
    } catch let appException as AppException {
        return .failure(ExceptionMapper.mapExceptionToFailure(appException))
        
    } catch {
        let unknownException = ServerException("Unexpected error", cause: error)
        return .failure(ExceptionMapper.mapExceptionToFailure(unknownException))
    }
}

extension Result {
    static func capturing<T>(
        from call: @escaping () async throws -> T
    ) async -> Result<T> where T == T {
        return await safeRepositoryCall(call: call)
    }
}
