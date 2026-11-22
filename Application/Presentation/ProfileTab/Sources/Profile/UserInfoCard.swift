//
//  UserInfoCard.swift
//  ProfileTab
//
//  Created by opfic on 9/24/26.
//

import SwiftUI
import PresentationShared

struct UserInfoCard: View {
    @Environment(\.isiOSAppOnMac) private var isiOSAppOnMac
    @Bindable var store: StoreOf<ProfileFeature>
    @FocusState private var focused: Bool
    let isSelected: Bool

    var body: some View {
        let spacing = isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 16
        let avatarSize = 52 * AdaptiveSize.boardScale
        let shape = RoundedRectangle(cornerRadius: CornerRadius.control)

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Group {
                    if let data = store.avatarImageData?.data,
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "person")
                            .font(.system(size: 22 * AdaptiveSize.boardScale))
                            .foregroundStyle(Color.secondaryLabel)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.tertiaryBackground)
                    }
                }
                .frame(width: avatarSize, height: avatarSize)
                .clipShape(.circle)
                .transaction { $0.animation = nil }

                VStack(alignment: .leading, spacing: 2) {
                    Text(store.name)
                        .font(.adaptive(.title3))
                        .bold()
                    Text(store.email)
                        .font(.adaptive(.footnote))
                        .foregroundStyle(Color.secondaryLabel)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, isiOSAppOnMac ? 14 * AdaptiveSize.boardScale : 18)

            HStack {
                // 테두리 있는 입력칸, 오른쪽 끝 표정 아이콘
                HStack(spacing: 8) {
                    TextField(
                        text: $store.statusMessage
                    ) {
                        Text("profile_status_placeholder", bundle: PresentationResources.bundle)
                            .foregroundStyle(Color.secondaryLabel)
                    }
                    .foregroundStyle(Color.label)
                    .tint(Color.label)
                    .focused($focused)
                    .disabled(!store.isNetworkConnected)

                    if !store.statusMessage.isEmpty,
                       store.showDoneButton {
                        Button {
                            store.send(.tapResetStatusMessageButton)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.label)
                        }
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }

                    // 다크에서 채워지는 face.smiling 대신 캔버스와 같은 선 아이콘
                    SmileyShape()
                        .stroke(Color.secondaryLabel, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                        .frame(width: 18 * AdaptiveSize.boardScale, height: 18 * AdaptiveSize.boardScale)
                }
                .font(.adaptive(isiOSAppOnMac ? .body : .subheadline))
                .padding(.horizontal, 12)
                .frame(height: isiOSAppOnMac ? 32 * AdaptiveSize.boardScale : 44)
                .background(Color.tertiaryBackground, in: shape)
                .overlay { shape.strokeBorder(Color.secondarySeparator) }

                if store.showDoneButton {
                    Button {
                        focused = false
                        store.send(.willUpdateStatusMessage)
                    } label: {
                        Text("profile_done", bundle: PresentationResources.bundle)
                    }
                    .tint(Color.label)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .opacity(store.isNetworkConnected ? 1 : 0.7)
            .padding(.vertical, isiOSAppOnMac ? 4 * AdaptiveSize.boardScale : 8)
        }
        .padding(.horizontal, spacing)
        .onChange(of: isSelected, initial: true) { _, isSelected in
            if !isSelected {
                focused = false
            }
        }
        .onChange(of: focused) { _, focused in
            store.send(.updateStatusTextFieldFocus(focused), animation: .default)
        }
    }
}

// 24 크기 보드 좌표의 원·눈·입 선 아이콘
private struct SmileyShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24
        var path = Path()
        path.addEllipse(in: CGRect(x: 3, y: 3, width: 18, height: 18))
        path.move(to: CGPoint(x: 8.5, y: 14.5))
        path.addQuadCurve(to: CGPoint(x: 15.5, y: 14.5), control: CGPoint(x: 12, y: 18.5))
        path.move(to: CGPoint(x: 9, y: 9.5))
        path.addLine(to: CGPoint(x: 9, y: 10))
        path.move(to: CGPoint(x: 15, y: 9.5))
        path.addLine(to: CGPoint(x: 15, y: 10))
        return path.applying(CGAffineTransform(scaleX: scale, y: scale).translatedBy(x: rect.minX / scale, y: rect.minY / scale))
    }
}
