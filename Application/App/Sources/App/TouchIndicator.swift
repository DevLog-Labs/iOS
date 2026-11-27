//
//  TouchIndicator.swift
//  DevLog
//
//  Created by opfic on 11/27/26.
//

#if DEBUG
import ObjectiveC
import UIKit

// 녹화 영상에 터치 위치를 남기는 Debug 빌드 전용 표시
// 실행 인자 `-showsTouches YES`로 켬
enum TouchIndicator {
    @MainActor fileprivate static var dots: [ObjectIdentifier: UIView] = [:]

    static func install() {
        guard UserDefaults.standard.bool(forKey: "showsTouches"),
              let original = class_getInstanceMethod(UIWindow.self, #selector(UIWindow.sendEvent(_:))),
              let replacement = class_getInstanceMethod(
                UIWindow.self,
                #selector(UIWindow.touchIndicatorSendEvent(_:))
              ) else { return }

        method_exchangeImplementations(original, replacement)
    }
}

private extension UIWindow {
    // 구현을 맞바꾼 뒤라 이 호출이 원래 sendEvent 실행
    @objc func touchIndicatorSendEvent(_ event: UIEvent) {
        touchIndicatorSendEvent(event)
        guard event.type == .touches, let touches = event.allTouches else { return }

        for touch in touches {
            let key = ObjectIdentifier(touch)
            let point = touch.location(in: self)

            switch touch.phase {
            case .began:
                let dot = UIView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
                dot.isUserInteractionEnabled = false
                dot.layer.cornerRadius = 22
                dot.backgroundColor = UIColor.systemGray.withAlphaComponent(0.45)
                dot.layer.borderColor = UIColor.white.withAlphaComponent(0.9).cgColor
                dot.layer.borderWidth = 2
                dot.layer.zPosition = 10_000
                dot.center = point
                addSubview(dot)
                TouchIndicator.dots[key] = dot
            case .moved, .stationary:
                if let dot = TouchIndicator.dots[key] {
                    bringSubviewToFront(dot)
                    dot.center = point
                }
            case .ended, .cancelled:
                if let dot = TouchIndicator.dots.removeValue(forKey: key) {
                    dot.center = point
                    UIView.animate(withDuration: 0.35, delay: 0.15) {
                        dot.alpha = 0
                    } completion: { _ in
                        dot.removeFromSuperview()
                    }
                }
            default:
                break
            }
        }
    }
}
#endif
