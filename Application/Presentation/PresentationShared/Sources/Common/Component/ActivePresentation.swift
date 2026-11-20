//
//  ActivePresentation.swift
//  PresentationShared
//
//  Created by opfic on 9/9/26.
//

import SwiftUI

public extension EnvironmentValues {
    var isTabContentActive: Bool {
        get { self[TabContentActiveKey.self] }
        set { self[TabContentActiveKey.self] = newValue }
    }

    private struct TabContentActiveKey: EnvironmentKey {
        static let defaultValue = true
    }
}

public extension Binding where Value == Bool {
    func activePresentation(when isActive: Bool) -> Binding {
        Binding(
            get: { isActive && wrappedValue },
            set: { isPresented in
                if isActive || !isPresented {
                    wrappedValue = isPresented
                }
            }
        )
    }
}

public extension Binding where Value == Bool {
    // 칸에 그리는 동안은 띄우지 않고, 늦게 닫히며 보내는 닫힘이 칸에 그린 화면을 지우지 않음
    func hiddenInPane(_ isInPane: Bool) -> Binding {
        Binding(
            get: { !isInPane && wrappedValue },
            set: { isPresented in
                if !isInPane {
                    wrappedValue = isPresented
                }
            }
        )
    }
}

public extension Binding {
    func hiddenInPane<Wrapped>(_ isInPane: Bool) -> Binding<Wrapped?>
    where Value == Wrapped? {
        hiddenInPane { isInPane }
    }

    // 칸에 그리는지를 읽거나 쓸 때마다 다시 판단해, 그린 뒤에 바뀐 상태로 늦게 들어온 닫힘을 거름
    func hiddenInPane<Wrapped>(_ isInPane: @escaping () -> Bool) -> Binding<Wrapped?>
    where Value == Wrapped? {
        Binding<Wrapped?>(
            get: { isInPane() ? nil : wrappedValue },
            set: { value in
                if !isInPane() {
                    wrappedValue = value
                }
            }
        )
    }

    func activePresentation<Wrapped>(when isActive: Bool) -> Binding<Wrapped?>
    where Value == Wrapped? {
        Binding<Wrapped?>(
            get: { isActive ? wrappedValue : nil },
            set: { value in
                switch value {
                case .some:
                    if isActive {
                        wrappedValue = value
                    }
                case .none:
                    wrappedValue = nil
                }
            }
        )
    }
}
