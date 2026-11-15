//
//  FetchSideBarWidthUseCaseImpl.swift
//  Domain
//
//  Created by opfic on 11/15/26.
//

public final class FetchSideBarWidthUseCaseImpl: FetchSideBarWidthUseCase {
    private let repository: UserPreferencesRepository

    init(_ repository: UserPreferencesRepository) {
        self.repository = repository
    }

    public func execute() -> Double? {
        repository.sideBarWidth()
    }
}
