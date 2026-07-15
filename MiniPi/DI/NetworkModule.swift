import FactoryKit

extension Container {
    var failureInjection: Factory<FailureInjectionInterceptor> {
        Factory(self) {
            FailureInjectionInterceptor(scenario: AppConfiguration.shared.apiScenario)
        }
        .scope(.singleton)
    }

    var httpClient: Factory<HTTPClient> {
        Factory(self) {
            var interceptors: [Interceptor] = [
                AuthTokenInterceptor(provider: StubAuthTokenProvider()),
                RetryInterceptor(maxRetries: 2, baseDelay: .milliseconds(300)),
            ]

            if AppConfiguration.shared.environment == .development {
                interceptors.insert(self.failureInjection(), at: 1)
            }

            return HTTPClient(interceptors: interceptors)
        }
        .scope(.singleton)
    }

    var connectivity: Factory<ConnectivityService> {
        Factory(self) {
            ConnectivityService()
        }
        .scope(.singleton)
    }
    
    // USE_FAKE_API variable inside config files to switch between FakeApiService and ApiService, keep the wiring here
    var apiService: Factory<any APIServiceProtocol> {
        Factory(self) {
            let config = AppConfiguration.shared
            if config.useFakeAPI {
                return FakeApiService(
                    scenario: config.apiScenario
                ) as any APIServiceProtocol
            } else {
                return APIService(client: self.httpClient()) as any APIServiceProtocol
            }
        }
        .scope(.singleton)
    }
}
