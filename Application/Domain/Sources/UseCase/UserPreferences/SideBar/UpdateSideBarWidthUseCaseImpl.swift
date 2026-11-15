//
//  UpdateSideBarWidthUseCaseImpl.swift
//  Domain
//
//  Created by opfic on 11/15/26.
//

public final class UpdateSideBarWidthUseCaseImpl: UpdateSideBarWidthUseCase {
    private let repository: UserPreferencesRepository

    init(_ repository: UserPreferencesRepository) {
        self.repository = repository
    }

    public func execute(_ width: Double) {
        repository.setSideBarWidth(width)
    }
}
