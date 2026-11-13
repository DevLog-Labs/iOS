//
//  DevelopmentRecord.swift
//  Domain
//
//  Created by opfic on 8/27/26.
//

import Foundation

public struct DevelopmentRecord: Hashable {
    public struct Draft: Hashable {
        public let title: String
        public let markdownContent: String
        public let baseVersionId: String?
        public let revisionId: String?
        public let updatedAt: Date

        public init(
            title: String,
            markdownContent: String,
            baseVersionId: String?,
            revisionId: String? = nil,
            updatedAt: Date
        ) throws {
            guard title.containsMeaningfulCharacter else {
                throw DomainLayerError.invalidDevelopmentRecordTitle
            }
            guard baseVersionId?.containsMeaningfulCharacter != false else {
                throw DomainLayerError.invalidDevelopmentRecordVersion
            }
            guard revisionId?.containsMeaningfulCharacter != false else {
                throw DomainLayerError.invalidDevelopmentRecordVersion
            }

            self.title = title
            self.markdownContent = markdownContent
            self.baseVersionId = baseVersionId
            self.revisionId = revisionId
            self.updatedAt = updatedAt
        }
    }

    public struct Confirmation: Hashable {
        public let versionId: String
        public let kind: Version.Kind
        public let sourceVersionId: String?
        public let draftRevisionId: String?

        public init(
            versionId: String,
            kind: Version.Kind,
            sourceVersionId: String?,
            draftRevisionId: String?
        ) {
            self.versionId = versionId
            self.kind = kind
            self.sourceVersionId = sourceVersionId
            self.draftRevisionId = draftRevisionId
        }
    }

    public struct CurrentVersion: Hashable {
        public let id: String
        public let number: Int

        public init(id: String, number: Int) throws {
            guard id.containsMeaningfulCharacter, 0 < number else {
                throw DomainLayerError.invalidDevelopmentRecordCurrentVersion
            }

            self.id = id
            self.number = number
        }
    }

    public struct Version: Hashable {
        public enum Kind: Hashable {
            case initial
            case correction
            case rollback
        }

        public let id: String
        public let recordId: String
        public let number: Int
        public let title: String
        public let markdownContent: String
        public let kind: Kind
        public let sourceVersionId: String?
        public let confirmedAt: Date

        public init(
            id: String,
            recordId: String,
            number: Int,
            title: String,
            markdownContent: String,
            kind: Kind,
            sourceVersionId: String?,
            confirmedAt: Date
        ) throws {
            guard id.containsMeaningfulCharacter,
                  recordId.containsMeaningfulCharacter,
                  title.containsMeaningfulCharacter,
                  0 < number else {
                throw DomainLayerError.invalidDevelopmentRecordVersion
            }

            switch kind {
            case .initial:
                guard number == 1, sourceVersionId == nil else {
                    throw DomainLayerError.invalidDevelopmentRecordVersion
                }
            case .correction, .rollback:
                guard 1 < number,
                      let sourceVersionId,
                      sourceVersionId.containsMeaningfulCharacter,
                      sourceVersionId != id else {
                    throw DomainLayerError.invalidDevelopmentRecordVersion
                }
            }

            self.id = id
            self.recordId = recordId
            self.number = number
            self.title = title
            self.markdownContent = markdownContent
            self.kind = kind
            self.sourceVersionId = sourceVersionId
            self.confirmedAt = confirmedAt
        }
    }

    public let id: String
    public let goalId: String
    public let currentVersion: CurrentVersion?
    public let draft: Draft?
    public let createdAt: Date

    public init(
        id: String,
        goalId: String,
        currentVersion: CurrentVersion?,
        draft: Draft?,
        createdAt: Date
    ) throws {
        guard id.containsMeaningfulCharacter, goalId.containsMeaningfulCharacter else {
            throw DomainLayerError.invalidData(context: "developmentRecord")
        }
        guard currentVersion != nil || draft != nil else {
            throw DomainLayerError.invalidDevelopmentRecordCurrentVersion
        }

        if let currentVersion, let draft {
            guard draft.baseVersionId == currentVersion.id else {
                throw DomainLayerError.invalidDevelopmentRecordCurrentVersion
            }
        } else if currentVersion == nil {
            guard draft?.baseVersionId == nil else {
                throw DomainLayerError.invalidDevelopmentRecordCurrentVersion
            }
        }

        self.id = id
        self.goalId = goalId
        self.currentVersion = currentVersion
        self.draft = draft
        self.createdAt = createdAt
    }
}

private extension String {
    var containsMeaningfulCharacter: Bool {
        !trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
