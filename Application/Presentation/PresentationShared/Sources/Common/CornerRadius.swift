//
//  CornerRadius.swift
//  PresentationShared
//
//  Created by opfic on 11/14/26.
//

import Foundation

// 칸, 목록 행, 상세 본문은 반경 없이 구분선으로 나눔
// 칩, 스위치, 숫자 배지는 Capsule 사용
// Mac은 AdaptiveSize.boardScale을 곱해 화면에서 보드 반경으로 표시
public enum CornerRadius {
    // 작은 배지
    public static let badge = 4 * AdaptiveSize.boardScale
    // 선택 조각 안쪽
    public static let segment = 6 * AdaptiveSize.boardScale
    // 버튼, 입력칸, 사이드바 항목
    public static let control = 8 * AdaptiveSize.boardScale
    // 알림창, 대화상자, 팝오버
    public static let dialog = 10 * AdaptiveSize.boardScale
    // 아래에서 올라오는 시트의 위쪽 모서리
    public static let sheet = 12 * AdaptiveSize.boardScale
    // 메뉴
    // Mac은 Orca 데스크톱, iPhone·Duo·iPad는 Orca 모바일 기준
    public static let menu = ProcessInfo.processInfo.isiOSAppOnMac ? 10 * AdaptiveSize.boardScale : 14
    // 설정 묶음, 요약 카드
    // Mac은 Orca 데스크톱, iPhone·Duo·iPad는 Orca 모바일 기준
    public static let group = ProcessInfo.processInfo.isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16
}
