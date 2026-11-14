//
//  CornerRadius.swift
//  PresentationShared
//
//  Created by opfic on 11/14/26.
//

import Foundation

// 칸, 목록 행, 상세 본문은 반경 없이 구분선으로 나눔
// 칩, 스위치, 숫자 배지는 Capsule 사용
public enum CornerRadius {
    // 작은 배지
    public static let badge: CGFloat = 4
    // 선택 조각 안쪽
    public static let segment: CGFloat = 6
    // 버튼, 입력칸, 사이드바 항목
    public static let control: CGFloat = 8
    // 알림창, 대화상자, 팝오버
    public static let dialog: CGFloat = 10
    // 메뉴
    // Mac은 Orca 데스크톱, iPhone·Duo·iPad는 Orca 모바일 기준
    public static let menu: CGFloat = ProcessInfo.processInfo.isiOSAppOnMac ? 10 : 14
    // 설정 묶음, 요약 카드
    // Mac은 Orca 데스크톱, iPhone·Duo·iPad는 Orca 모바일 기준
    public static let group: CGFloat = ProcessInfo.processInfo.isiOSAppOnMac ? 14 : 16
}
