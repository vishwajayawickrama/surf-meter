import SwiftUI
import AppKit

@main
struct SurfMeterApp: App {
    @NSApplicationDelegateAdaptor(SurfMeterDelegate.self) private var delegate
    @StateObject private var model: AppModel
    init() {
        if CommandLine.arguments.contains("--configure-chrome") {
            SetupCommand.run(arguments: Array(CommandLine.arguments.dropFirst()))
        }
        if CommandLine.arguments.contains("--verify-model") { AuditSupport.verifyModel(); exit(0) }
        let demo = CommandLine.arguments.contains("--desktop-audit") || CommandLine.arguments.contains("--render-audit-previews") || CommandLine.arguments.contains("--ui-audit") || CommandLine.arguments.contains("--verify-appearance") || CommandLine.arguments.contains("--demo") || CommandLine.arguments.contains("--render-previews")
        let model = AppModel(demo: demo)
        if model.instanceBlocked {
            FileHandle.standardError.write(Data("SurfMeter is already running for this activity store.\n".utf8))
            exit(75)
        }
        _model = StateObject(wrappedValue: model)
        DesktopController.shared.configure(model: model)
        if CommandLine.arguments.contains("--desktop-audit") {
            DesktopController.shared.show(model: model)
            NSApp.run()
            exit(0)
        }
        if CommandLine.arguments.contains("--ui-audit") { AuditSupport.showWindow(model: model) }
        if CommandLine.arguments.contains("--verify-appearance") { PreviewExport.verifyAppearance(model: model); exit(0) }
        if let index = CommandLine.arguments.firstIndex(of: "--render-audit-previews"), CommandLine.arguments.indices.contains(index + 1) {
            PreviewExport.renderAudit(model: model, directory: URL(fileURLWithPath: CommandLine.arguments[index + 1])); exit(0)
        }
        if let index = CommandLine.arguments.firstIndex(of: "--render-previews"), CommandLine.arguments.indices.contains(index + 1) {
            PreviewExport.render(model: model, directory: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
            exit(0)
        }
    }
    var body: some Scene {
        MenuBarExtra {
            DashboardView(model: model)
                .modifier(SurfAppearance(mode: model.preferences.appearance))
        } label: {
            Label(model.menuLabel, systemImage: model.preferences.paused ? "pause.circle" : "water.waves")
                .accessibilityLabel("SurfMeter, today \(model.menuLabel)")
        }
        .menuBarExtraStyle(.window)
    }
}
