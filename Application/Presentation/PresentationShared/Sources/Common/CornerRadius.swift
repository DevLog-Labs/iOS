//
//  CornerRadius.swift
//  PresentationShared
//
//  Created by opfic on 11/14/26.
//

import Foundation

// 칸, 목록 행, 상세 본문, 요약·설정 묶음, 스와이프 동작은 반경 없이 구분선으로 나눔
// 스위치, 숫자 배지, 진행 막대만 Capsule 사용
// Mac은 AdaptiveSize.boardScale을 곱해 화면에서 보드 반경으로 표시
public enum CornerRadius {
    // 작은 배지
    public static let badge = 4 * AdaptiveSize.boardScale
    // 분할 버튼 안쪽 조각
    public static let segment = 4 * AdaptiveSize.boardScale
    // 버튼, 칩, 입력칸, 사이드바·메뉴 항목, 아이콘 사각형
    public static let control = 6 * AdaptiveSize.boardScale
    // 알림창, 대화상자, 팝오버, 토스트, 상세 판
    public static let dialog = 12 * AdaptiveSize.boardScale
    // 아래에서 올라오는 시트의 위쪽 모서리
    public static let sheet = 12 * AdaptiveSize.boardScale
    // 메뉴
    public static let menu = 12 * AdaptiveSize.boardScale
    // 여러 줄 입력칸, 묶음 바탕
    public static let group = 12 * AdaptiveSize.boardScale
}
