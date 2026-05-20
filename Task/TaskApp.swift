import SwiftUI
import SwiftData

@main
struct TaskApp: App {
    @StateObject private var settings = SettingsViewModel()
    private let container = SwiftDataManager.makeModelContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
                .environmentObject(settings)
                .preferredColorScheme(settings.theme.colorScheme)
                .tint(settings.accent.color)
                .environment(\.locale, settings.language.locale)
                .dynamicTypeSize(settings.textSize.dynamicType)
                .id("\(settings.language.rawValue)")
        }
    }
}
