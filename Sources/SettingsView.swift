import SwiftUI
import AppKit

/// The Settings window: snapping behaviour, shortcuts, login item, ignored apps and permission status.
struct SettingsView: View {
    @EnvironmentObject private var state: AppState
    @AppStorage(Prefs.sensitivityKey) private var sensitivity = 8.0
    @AppStorage(Prefs.gapKey) private var gap = 0
    @AppStorage(Prefs.dragKey) private var dragToSnap = true
    @AppStorage(Prefs.hotkeysKey) private var shortcuts = true
    @AppStorage(Prefs.ignoredKey) private var ignoredRaw = ""
    @State private var selection: String?

    private var ignored: [String] { ignoredRaw.split(separator: "\n").map(String.init) }

    var body: some View {
        Form {
            Section("Permissions") {
                HStack {
                    Image(systemName: state.trusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(state.trusted ? .green : .orange)
                    VStack(alignment: .leading) {
                        Text(state.trusted ? "Accessibility access granted" : "Accessibility access needed")
                        if !state.trusted {
                            Text("EdgeSnapZones needs Accessibility to move and resize other apps' windows.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button("Open Privacy Settings") {
                        state.requestAccess()
                        state.openAccessibilityPane()
                    }
                }
            }
            Section("Snapping") {
                Toggle("Drag windows to edges to snap", isOn: $dragToSnap)
                LabeledContent("Edge sensitivity") {
                    HStack {
                        Slider(value: $sensitivity, in: 2...30, step: 1)
                        Text("\(Int(sensitivity)) pt").monospacedDigit().frame(width: 44, alignment: .trailing)
                    }
                }
                Stepper("Gap between windows: \(gap) pt", value: $gap, in: 0...40, step: 2)
                Toggle("Keyboard shortcuts (⌃⌥ + arrows, ↩, U I J K, D F G, C, ⌫)", isOn: $shortcuts)
            }
            Section("General") {
                Toggle("Launch at login", isOn: Binding(get: { state.launchAtLogin }, set: { state.setLaunchAtLogin($0) }))
                if let error = state.loginError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }
            Section("Ignored Apps") {
                List(ignored, id: \.self, selection: $selection) { bundle in
                    Text(displayName(for: bundle))
                }
                .frame(minHeight: 90)
                HStack {
                    Menu("Add Running App") {
                        ForEach(runningApps, id: \.bundleIdentifier) { app in
                            Button(app.localizedName ?? app.bundleIdentifier ?? "") { add(app.bundleIdentifier) }
                        }
                    }
                    .fixedSize()
                    Button("Remove") { remove() }.disabled(selection == nil)
                }
            }
            Section {
                HStack {
                    Text("EdgeSnapZones is free and open source.").foregroundStyle(.secondary)
                    Spacer()
                    Button("Support / Donate ❤️") { Support.openDonate() }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 600)
    }

    private var runningApps: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .filter { !ignored.contains($0.bundleIdentifier ?? "") }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    private func displayName(for bundle: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle) else { return bundle }
        return "\(FileManager.default.displayName(atPath: url.path)) (\(bundle))"
    }

    private func add(_ bundle: String?) {
        guard let bundle, !ignored.contains(bundle) else { return }
        ignoredRaw = (ignored + [bundle]).joined(separator: "\n")
    }

    private func remove() {
        guard let selection else { return }
        ignoredRaw = ignored.filter { $0 != selection }.joined(separator: "\n")
        self.selection = nil
    }
}
