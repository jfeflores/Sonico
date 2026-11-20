import AppKit
import SwiftUI

@main
struct SonicoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = HeadphoneModel(demo: CommandLine.arguments.contains("--demo"))

    var body: some Scene {
        Window("Sonico", id: "device") {
            ContentView(model: model)
                .modifier(FinishAppearance(finish: model.snapshot.finish))
                .onAppear { delegate.model = model; model.start() }
        }
        .defaultSize(width: 660, height: 805)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Menu("Licenses & Source") {
                    Button("Notices & Attribution") { openNotice("NOTICE") }
                    Button("Sonico · GNU AGPL v3") { openNotice("LICENSE") }
                    Button("SonyHeadphonesClient · MIT") { openNotice("MIT-SonyHeadphonesClient") }
                    Button("Earlier SonyHeadphonesClient · MIT") { openNotice("MIT-Plutoberth") }
                    Button("fmt License") { openNotice("FMT-LICENSE") }
                    Divider()
                    Link("Source Code", destination: URL(string: "https://github.com/jfeflores/Sonico")!)
                }
            }
            CommandGroup(after: .toolbar) {
                Button("My Device") { model.page = .device }.keyboardShortcut("1")
                Button("Equalizer") { model.page = .equalizer }.keyboardShortcut("2")
                Button("Show Headphone Settings") { model.page = .settings }.keyboardShortcut("3")
                Divider()
                Button("Refresh Device State") { model.send(.sync) }
                    .keyboardShortcut("r").disabled(!model.snapshot.controllable)
            }
        }
        MenuBarExtra {
            MenuBarView(model: model)
                .modifier(FinishAppearance(finish: model.snapshot.finish))
        } label: {
            Label("Sonico", systemImage: "headphones")
                .accessibilityLabel("Sonico, \(model.snapshot.status)")
        }
        .menuBarExtraStyle(.window)
        Settings {
            AppSettingsView(model: model)
        }
    }

    private func openNotice(_ resource: String) {
        if let url = Bundle.main.url(forResource: resource, withExtension: "txt") { NSWorkspace.shared.open(url) }
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var model: HeadphoneModel?
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) { model?.stop() }
}

struct ContentView: View {
    @Bindable var model: HeadphoneModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.sonico) private var colors
    @State private var showingDeviceAlert = false

    var body: some View {
        VStack(spacing: 0) {
            if model.snapshot.isDemo {
                HStack {
                    Label("Demo mode", systemImage: "flask").fontWeight(.semibold)
                    Text("No Bluetooth connection").foregroundStyle(colors.secondary)
                    Spacer()
                    Button("Exit Demo") { model.leaveDemo() }.buttonStyle(.borderless)
                }
                .font(.callout).padding(.horizontal, XMTheme.margin).padding(.vertical, 8)
                .foregroundStyle(colors.primary).background(colors.surfaceHigh)
            }
            if model.snapshot.controllable {
                pageNavigation
                // Replace the page's scroll context, not its navigation.
                ScrollView {
                    Group {
                        switch model.page {
                        case .device: OverviewView(model: model)
                        case .equalizer: EqualizerView(model: model)
                        case .settings: DeviceSettingsView(model: model)
                        }
                    }
                    .frame(maxWidth: 820)
                    .frame(maxWidth: .infinity)
                }
                .id(model.page)
                .transition(reduceMotion ? .identity : .asymmetric(insertion: .opacity, removal: .identity))
            } else {
                ConnectionView(model: model)
            }
            if let error = model.visibleError {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                    Text(error).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button("Dismiss", systemImage: "xmark") { model.visibleError = nil }.labelStyle(.iconOnly)
                }
                .font(.callout).padding(16).foregroundStyle(colors.error).background(colors.surface)
            }
            if !model.snapshot.isDemo {
                HStack {
                    StatusLine(snapshot: model.snapshot)
                    Spacer()
                    if model.snapshot.applying {
                        ProgressView().controlSize(.mini)
                        Text("Sending changes…").font(.caption).foregroundStyle(colors.secondary)
                    }
                }
                .frame(minHeight: 20)
                .padding(.horizontal, XMTheme.margin).padding(.vertical, 6)
                .background(colors.surface)
            }
        }
        .animation(reduceMotion ? nil : XMMotion.navigation, value: model.page)
        .frame(minWidth: 530, minHeight: 610)
        .background(colors.background)
        .foregroundStyle(colors.text)
        .toolbar {
            ToolbarItem {
                Button("Connection", systemImage: "headphones") { model.showingConnection.toggle() }
                    .popover(isPresented: $model.showingConnection) {
                        ConnectionView(model: model).frame(width: 410, height: 450)
                            .background(colors.background)
                            .modifier(FinishAppearance(finish: model.snapshot.finish))
                    }
            }
        }
        .onChange(of: model.snapshot.deviceAlert, initial: true) { _, alert in
            showingDeviceAlert = alert != nil
        }
        .alert("The headphones need confirmation", isPresented: $showingDeviceAlert) {
            Button("Cancel", role: .cancel) { model.send(.answerAlert(false)) }
            Button("Continue") { model.send(.answerAlert(true)) }
        } message: {
            Text(model.snapshot.deviceAlert ?? "This setting may interrupt the Bluetooth connection.")
        }
    }

    private var pageNavigation: some View {
        // A dedicated row won't be displaced by the title or toolbar overflow as the window narrows.
        Picker("Headphone view", selection: $model.page) {
            ForEach(AppPage.allCases) { page in
                Text(page.rawValue).frame(maxWidth: .infinity).tag(page)
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .controlSize(.large)
        .frame(maxWidth: 360)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, XMTheme.margin)
        .padding(.vertical, 10)
        .background(colors.surface)
    }
}

struct ConnectionView: View {
    @Bindable var model: HeadphoneModel
    @Environment(\.sonico) private var colors
    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 12)
            Image(systemName: "headphones").font(.system(size: 48, weight: .light)).foregroundStyle(colors.primary)
                .accessibilityHidden(true)
            VStack(spacing: 8) {
                Text(model.snapshot.controllable ? model.snapshot.name : "Connect headphones")
                    .font(.title.weight(.semibold)).accessibilityAddTraits(.isHeader)
                if model.snapshot.phase.busy { Text(model.snapshot.name).foregroundStyle(colors.secondary) }
            }
            if !model.snapshot.controllable && !model.snapshot.phase.busy {
                Text("Pair your WH-1000XM3, XM4, XM5, or XM6 in Bluetooth Settings, then find and connect them here.")
                    .foregroundStyle(colors.secondary).multilineTextAlignment(.center).frame(maxWidth: 350)
            }
            if model.snapshot.phase.busy {
                ProgressView(model.snapshot.phase.label).controlSize(.small)
                Button("Cancel") { model.send(.disconnect) }.buttonStyle(TonalButtonStyle())
            } else if model.snapshot.controllable {
                StatusLine(snapshot: model.snapshot)
                Button("Disconnect") { model.send(.disconnect) }.buttonStyle(TonalButtonStyle())
            } else {
                if !model.snapshot.devices.isEmpty {
                    ViewThatFits(in: .vertical) {
                        pairedDeviceButtons
                        ScrollView { pairedDeviceButtons.padding(.vertical, 3).frame(maxWidth: .infinity) }
                            .frame(height: 98)
                    }
                }
                Button("Find Paired Headphones", systemImage: "arrow.clockwise") { model.send(.discover) }
                    .buttonStyle(TonalButtonStyle(prominent: model.snapshot.devices.isEmpty))
                if model.snapshot.devices.isEmpty && model.snapshot.phase == .disconnected {
                    Text("Use the headphones’ original Bluetooth name so they appear in this list.")
                        .font(.caption).foregroundStyle(colors.secondary).multilineTextAlignment(.center).frame(maxWidth: 340)
                }
                HStack(spacing: 16) {
                    Button("Bluetooth Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.BluetoothSettings") { NSWorkspace.shared.open(url) }
                    }
                    Button("Explore Demo") { model.enterDemo() }
                }.buttonStyle(.link)
            }
            Spacer(minLength: 12)
        }
        .padding(28).frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(colors.text)
    }

    private var pairedDeviceButtons: some View {
        VStack(spacing: 10) {
            ForEach(model.snapshot.devices) { device in
                Button { model.send(.connect(device)) } label: {
                    Label("Connect \(device.name)", systemImage: "headphones")
                }.buttonStyle(TonalButtonStyle(prominent: true))
            }
        }
    }
}

struct AppSettingsView: View {
    @Bindable var model: HeadphoneModel
    var body: some View {
        Form {
            Section("Sonico") {
                Text("Independent headphone controller for macOS 15+.")
                Text("Not affiliated with or endorsed by Sony.").foregroundStyle(.secondary)
            }
            Section("Connection & privacy") {
                Text("Connections are explicit. No analytics or automatic packet recording. Closing the device window keeps the menu bar available; Quit ends the session.")
                Button(model.snapshot.isDemo ? "Exit Demo" : "Explore Demo") {
                    if model.snapshot.isDemo { model.leaveDemo() } else { model.enterDemo() }
                }
                .disabled(model.snapshot.controllable && !model.snapshot.isDemo)
            }
            Section("Development build") {
                Text("Not notarized. Hardware behavior must be verified on your headphones before public distribution.")
            }
        }
        .formStyle(.grouped).frame(width: 460, height: 390)
    }
}
