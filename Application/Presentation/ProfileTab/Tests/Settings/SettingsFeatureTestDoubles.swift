//
//  SettingsFeatureTestDoubles.swift
//  ProfileTabTests
//
//  Created by opfic on 6/12/26.
//

import Combine
import Core
import Domain

@MainActor
func waitUntil(
    timeout: Duration = .seconds(1),
    pollInterval: Duration = .milliseconds(20),
    _ condition: @escaping () -> Bool
) async {
    let continuousClock = ContinuousClock()
    let deadline = continuousClock.now + timeout

    while !condition() && continuousClock.now < deadline {
        try? await Task.sleep(for: pollInterval)
    }
}

final class ObserveNetworkConnectivityUseCaseSpy: ObserveNetworkConnectivityUseCase {
    let currentValueSubject = CurrentValueSubject<Bool, Never>(true)

    func observe() -> AnyPublisher<Bool, Never> {
        currentValueSubject.eraseToAnyPublisher()
    }
}

final class DeleteAuthUseCaseSpy: DeleteAuthUseCase {
    var error: Error?
    private(set) var executeCallCount = 0

    func execute() async throws {
        executeCallCount += 1

        if let error {
            throw error
        }
    }
}

final class SignOutUseCaseSpy: SignOutUseCase {
    var error: Error?
    var shouldSuspend = false
    private(set) var executeCallCount = 0
    private var continuation: CheckedContinuation<Void, Never>?
    private var shouldResume = false

    func execute() async throws {
        executeCallCount += 1

        if shouldSuspend {
            await withCheckedContinuation { continuation in
                if shouldResume {
                    shouldResume = false
                    continuation.resume()
                } else {
                    self.continuation = continuation
                }
            }
        }

        if let error {
            throw error
        }
    }

    func resume() {
        guard let continuation else {
            shouldResume = true
            return
        }

        self.continuation = nil
        continuation.resume()
    }
}

final class ObserveSystemThemeUseCaseSpy: ObserveSystemThemeUseCase {
    let subject = PassthroughSubject<SystemTheme, Never>()

    func observe() -> AnyPublisher<SystemTheme, Never> {
        subject.eraseToAnyPublisher()
    }
}

final class UpdateSystemThemeUseCaseSpy: UpdateSystemThemeUseCase {
    private(set) var themes = [SystemTheme]()

    func execute(_ theme: SystemTheme) {
        themes.append(theme)
    }
}
