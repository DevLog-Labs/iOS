//
//  Color+Assets.swift
//  PresentationShared
//
//  Created by opfic on 9/11/26.
//

import SwiftUI

public extension Color {
    static let accent = Color("AccentColor", bundle: PresentationResources.bundle)
    static let appBackground = Color("AppBackground", bundle: PresentationResources.bundle)
    static let border = Color(
        ProcessInfo.processInfo.isiOSAppOnMac ? "BorderMac" : "Border",
        bundle: PresentationResources.bundle
    )
    static let borderSubtle = Color("BorderSubtle", bundle: PresentationResources.bundle)
    static let controlBackground = Color("ControlBackground", bundle: PresentationResources.bundle)
    static let onControlBackground = Color("OnControlBackground", bundle: PresentationResources.bundle)
    static let danger = Color("Danger", bundle: PresentationResources.bundle)
    static let info = Color("Info", bundle: PresentationResources.bundle)
    static let onPrimaryContainer = Color("OnPrimaryContainer", bundle: PresentationResources.bundle)
    static let primaryContainer = Color("PrimaryContainer", bundle: PresentationResources.bundle)
    static let success = Color("Success", bundle: PresentationResources.bundle)
    static let surface = Color("Surface", bundle: PresentationResources.bundle)
    static let surfaceSecondary = Color("SurfaceSecondary", bundle: PresentationResources.bundle)
    static let textPrimary = Color(
        ProcessInfo.processInfo.isiOSAppOnMac ? "TextPrimaryMac" : "TextPrimary",
        bundle: PresentationResources.bundle
    )
    static let textSecondary = Color("TextSecondary", bundle: PresentationResources.bundle)
    static let textTertiary = Color("TextTertiary", bundle: PresentationResources.bundle)
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
    static let switchTrackOff = Color("SwitchTrackOff", bundle: PresentationResources.bundle)
    static let sheetGrabber = Color("SheetGrabber", bundle: PresentationResources.bundle)
    static let scrim = Color("Scrim", bundle: PresentationResources.bundle)
}
