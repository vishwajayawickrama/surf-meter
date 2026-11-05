import SwiftUI
import AppKit

@main
struct SurfMeterApp: App {
    @StateObject private var model: AppModel
    init() {
        if CommandLine.arguments.contains("--configure-chrome") {
            SetupCommand.run(arguments: Array(CommandLine.arguments.dropFirst()))
        }
        let demo = CommandLine.arguments.contains("--demo") || CommandLine.arguments.contains("--render-previews")
        let model = AppModel(demo: demo)
        _model = StateObject(wrappedValue: model)
        if let index = CommandLine.arguments.firstIndex(of: "--render-previews"), CommandLine.arguments.indices.contains(index + 1) {
            PreviewExport.render(model: model, directory: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
            exit(0)
        }
    }
    var body: some Scene {
        MenuBarExtra {
            DashboardView(model: model)
                .preferredColorScheme(model.colorScheme)
        } label: {
            Label(model.menuLabel, systemImage: model.preferences.paused ? "pause.circle" : "water.waves")
                .accessibilityLabel("SurfMeter, today \(model.menuLabel)")
        }
        .menuBarExtraStyle(.window)
    }
}
