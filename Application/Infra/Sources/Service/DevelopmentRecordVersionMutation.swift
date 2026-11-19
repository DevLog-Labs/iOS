//
//  DevelopmentRecordVersionMutation.swift
//  Infra
//
//  Created by opfic on 8/28/26.
//

import FirebaseFirestore
import Data

extension DevelopmentRecordServiceImpl {
    static func makeConfirmationMutation(
        recordData: [String: Any],
        request: DevelopmentRecordConfirmationRequest
    ) -> DevelopmentRecordVersionMutation? {
        let mapper = DevelopmentRecordDocumentMapper()
        guard let record = mapper.map(goalId: "goal", documentId: "record", data: recordData),
              let draft = record.draft,
              draft.revisionId == request.draftRevisionId else {
            return nil
        }

        switch (request.kind, record.currentVersion) {
        case ("initial", nil):
            guard request.sourceVersionId == nil, draft.baseVersionId == nil else { return nil }
            return .init(
                number: 1,
                title: draft.title,
                markdownContent: draft.markdownContent,
                kind: "initial",
                sourceVersionId: nil
            )
        case let ("correction", .some(currentVersion)):
            guard request.sourceVersionId == currentVersion.id,
                  draft.baseVersionId == currentVersion.id else {
                return nil
            }
            return .init(
                number: currentVersion.number + 1,
                title: draft.title,
                markdownContent: draft.markdownContent,
                kind: "correction",
                sourceVersionId: currentVersion.id
            )
        default:
            return nil
        }
    }

    static func makeRestoreMutation(
        recordId: String,
        recordData: [String: Any],
        sourceVersionId: String,
        sourceData: [String: Any]
    ) -> DevelopmentRecordVersionMutation? {
        let mapper = DevelopmentRecordDocumentMapper()
        guard let record = mapper.map(goalId: "goal", documentId: recordId, data: recordData),
              let currentVersion = record.currentVersion,
              record.draft == nil,
              let source = mapper.mapVersion(
                  recordId: recordId,
                  documentId: sourceVersionId,
                  data: sourceData
              ),
              source.number < currentVersion.number else {
            return nil
        }
        return .init(
            number: currentVersion.number + 1,
            title: source.title,
            markdownContent: source.markdownContent,
            kind: "rollback",
            sourceVersionId: sourceVersionId
        )
    }

    static func makeDraftData(_ request: DevelopmentRecordDraftRequest) -> [String: Any] {
        var data: [String: Any] = [
            DevelopmentRecordDraftFieldKey.title.rawValue: request.title,
            DevelopmentRecordDraftFieldKey.markdownContent.rawValue: request.markdownContent,
            DevelopmentRecordDraftFieldKey.updatedAt.rawValue: FieldValue.serverTimestamp()
        ]
        if let baseVersionId = request.baseVersionId {
            data[DevelopmentRecordDraftFieldKey.baseVersionId.rawValue] = baseVersionId
        }
        if let revisionId = request.revisionId {
            data[DevelopmentRecordDraftFieldKey.revisionId.rawValue] = revisionId
        }
        return data
    }

    static func makeDraftData(
        recordData: [String: Any],
        request: DevelopmentRecordDraftRequest
    ) -> [String: Any]? {
        let draftData = recordData[DevelopmentRecordFieldKey.draft.rawValue] as? [String: Any]
        guard
            (recordData[DevelopmentRecordFieldKey.currentVersionId.rawValue] as? String) ==
                request.baseVersionId,
            (draftData?[DevelopmentRecordDraftFieldKey.revisionId.rawValue] as? String) ==
                request.expectedRevisionId else {
            return nil
        }
        return makeDraftData(request)
    }
}

struct DevelopmentRecordVersionMutation {
    let number: Int
    let title: String
    let markdownContent: String
    let kind: String
    let sourceVersionId: String?

    func documentData() -> [String: Any] {
        var data: [String: Any] = [
            DevelopmentRecordVersionFieldKey.versionNumber.rawValue: number,
            DevelopmentRecordVersionFieldKey.title.rawValue: title,
            DevelopmentRecordVersionFieldKey.markdownContent.rawValue: markdownContent,
            DevelopmentRecordVersionFieldKey.changeKind.rawValue: kind,
            DevelopmentRecordVersionFieldKey.confirmedAt.rawValue: FieldValue.serverTimestamp()
        ]
        if let sourceVersionId {
            data[DevelopmentRecordVersionFieldKey.sourceVersionId.rawValue] = sourceVersionId
        }
        return data
    }
}
