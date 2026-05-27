import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum BoardLayoutStyle {
    case mobile
    case mac
}

enum PlatformLayout {
    static var prefersMacInterface: Bool {
        #if targetEnvironment(macCatalyst)
        true
        #elseif os(macOS)
        true
        #elseif canImport(UIKit)
        if UIDevice.current.userInterfaceIdiom == .mac {
            return true
        }
        if ProcessInfo.processInfo.isMacCatalystApp {
            return true
        }
        if ProcessInfo.processInfo.isiOSAppOnMac {
            return true
        }
        return false
        #else
        false
        #endif
    }
}

extension View {
    @ViewBuilder
    func taskMacSheetFrame(width: CGFloat, minHeight: CGFloat? = nil) -> some View {
        if PlatformLayout.prefersMacInterface {
            frame(
                minWidth: width,
                idealWidth: width,
                maxWidth: width,
                minHeight: minHeight,
                idealHeight: minHeight,
                alignment: .center
            )
        } else {
            self
        }
    }

    @ViewBuilder
    func taskSheetPresentation(
        detents: Set<PresentationDetent> = [.fraction(0.6), .large],
        macHeight: CGFloat? = nil
    ) -> some View {
        if PlatformLayout.prefersMacInterface {
            if let macHeight {
                presentationDetents([.height(macHeight)])
                    .presentationDragIndicator(.hidden)
            } else {
                presentationDragIndicator(.hidden)
            }
        } else {
            presentationDetents(detents)
                .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    func taskSheetPresentation(
        selection: Binding<PresentationDetent>,
        detents: Set<PresentationDetent> = [.fraction(0.6), .large],
        macHeight: CGFloat? = nil
    ) -> some View {
        if PlatformLayout.prefersMacInterface {
            if let macHeight {
                presentationDetents([.height(macHeight)])
                    .presentationDragIndicator(.hidden)
            } else {
                presentationDragIndicator(.hidden)
            }
        } else {
            presentationDetents(detents, selection: selection)
                .presentationDragIndicator(.visible)
        }
    }
}
