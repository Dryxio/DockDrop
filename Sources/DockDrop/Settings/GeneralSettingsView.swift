import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var preferences: UserPreferences

    var body: some View {
        Form {
            Picker("Shelf position", selection: $preferences.shelfPosition) {
                ForEach(ShelfPosition.allCases) { position in
                    Text(position.title).tag(position)
                }
            }

            HStack {
                Text("Activation delay")
                Slider(
                    value: $preferences.activationDelayMs,
                    in: Constants.minActivationDelayMs...Constants.maxActivationDelayMs,
                    step: 50
                )
                Text("\(Int(preferences.activationDelayMs)) ms")
                    .frame(width: 70, alignment: .trailing)
            }

            Picker("Show shelf for", selection: $preferences.dragVisibilityMode) {
                ForEach(DragVisibilityMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }

            Picker("Shelf icon size", selection: $preferences.iconSize) {
                ForEach(ShelfIconSize.allCases) { size in
                    Text(size.title).tag(size)
                }
            }

            Picker("Show app labels", selection: $preferences.labelDisplayMode) {
                ForEach(LabelDisplayMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }

            Picker("Shelf appearance", selection: $preferences.appearance) {
                ForEach(ShelfAppearance.allCases) { appearance in
                    Text(appearance.title).tag(appearance)
                }
            }

            Toggle("Launch at login", isOn: $preferences.launchAtLogin)

            HStack {
                Text(AccessibilityHelper.isTrusted() ? "Accessibility permission: Granted" : "Accessibility permission: Missing")
                    .foregroundStyle(AccessibilityHelper.isTrusted() ? Color.green : Color.orange)
                Spacer()
                Button("Open Accessibility Settings") {
                    AccessibilityHelper.openSystemSettings()
                }
            }
        }
        .formStyle(.grouped)
        .padding(18)
        .frame(width: 460)
        .onChange(of: preferences.launchAtLogin) { _, newValue in
            LaunchAtLoginManager.setEnabled(newValue)
        }
    }
}
