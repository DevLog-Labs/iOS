//
//  Color+Assets.swift
//  PresentationShared
//
//  Created by opfic on 9/11/26.
//

import SwiftUI

public extension Color {
    static let accent = Color("AccentColor", bundle: PresentationResources.bundle)
    static let background = Color("Background", bundle: PresentationResources.bundle)
    static let danger = Color("Danger", bundle: PresentationResources.bundle)
    static let fill = Color("Fill", bundle: PresentationResources.bundle)
    static let fillLabel = Color("FillLabel", bundle: PresentationResources.bundle)
    static let info = Color("Info", bundle: PresentationResources.bundle)
    static let label = Color(
        ProcessInfo.processInfo.isiOSAppOnMac ? "LabelMac" : "Label",
        bundle: PresentationResources.bundle
    )
    static let secondaryBackground = Color("SecondaryBackground", bundle: PresentationResources.bundle)
    static let secondaryLabel = Color("SecondaryLabel", bundle: PresentationResources.bundle)
    static let secondarySeparator = Color("SecondarySeparator", bundle: PresentationResources.bundle)
    static let separator = Color(
        ProcessInfo.processInfo.isiOSAppOnMac ? "SeparatorMac" : "Separator",
        bundle: PresentationResources.bundle
    )
    static let success = Color("Success", bundle: PresentationResources.bundle)
    static let tertiaryBackground = Color("TertiaryBackground", bundle: PresentationResources.bundle)
    static let tertiaryLabel = Color("TertiaryLabel", bundle: PresentationResources.bundle)
    static let tintFill = Color("TintFill", bundle: PresentationResources.bundle)
    static let tintLabel = Color("TintLabel", bundle: PresentationResources.bundle)
    static let warning = Color("Warning", bundle: PresentationResources.bundle)
    static let categoryFeature = Color("CategoryFeature", bundle: PresentationResources.bundle)
    static let categoryImprovement = Color("CategoryImprovement", bundle: PresentationResources.bundle)
    static let categoryReview = Color("CategoryReview", bundle: PresentationResources.bundle)
    static let categoryTest = Color("CategoryTest", bundle: PresentationResources.bundle)
    static let categoryDoc = Color("CategoryDoc", bundle: PresentationResources.bundle)
    static let categoryResearch = Color("CategoryResearch", bundle: PresentationResources.bundle)
    static let categoryEtc = Color("CategoryEtc", bundle: PresentationResources.bundle)
    static let heatmapEmpty = Color("HeatmapEmpty", bundle: PresentationResources.bundle)
    static let heatmapLevel1 = Color("HeatmapLevel1", bundle: PresentationResources.bundle)
    static let heatmapLevel2 = Color("HeatmapLevel2", bundle: PresentationResources.bundle)
    static let heatmapBorder = Color("HeatmapBorder", bundle: PresentationResources.bundle)
    static let heatmapFuture = Color("HeatmapFuture", bundle: PresentationResources.bundle)
    static let heatmapFutureBorder = Color("HeatmapFutureBorder", bundle: PresentationResources.bundle)
    static let switchOffFill = Color("SwitchOffFill", bundle: PresentationResources.bundle)
    static let sheetGrabber = Color("SheetGrabber", bundle: PresentationResources.bundle)
    static let dimming = Color("Dimming", bundle: PresentationResources.bundle)
}
