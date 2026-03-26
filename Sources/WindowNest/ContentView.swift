import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: WindowNestModel

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("WindowNest")
                .font(.system(size: 24, weight: .semibold))

            Text("A fresh, original macOS window snapping utility inspired by common tiling workflows.")
                .foregroundStyle(.secondary)

            permissionCard
            settingsCard

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(model.layouts) { layout in
                    Button {
                        model.apply(layout)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(layout.title)
                                .font(.headline)
                            Text(layout.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
                        .padding(12)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.accessibilityGranted)
                }
            }

            Text(model.statusMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack {
                Button("Refresh Permissions") {
                    model.refreshPermissions()
                }

                Spacer()

                Button("Quit") {
                    NSApp.terminate(nil)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(width: 380)
        .onAppear {
            model.refreshPermissions()
        }
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(
                model.accessibilityGranted ? "Accessibility access enabled" : "Accessibility access required",
                systemImage: model.accessibilityGranted ? "checkmark.shield" : "hand.raised"
            )
            .font(.headline)

            Text("WindowNest needs macOS Accessibility permission so it can move and resize the currently focused window.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Button("Request Access") {
                    model.requestPermissions()
                }

                Button("Open Settings") {
                    model.openAccessibilitySettings()
                }
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Launch WindowNest at login", isOn: Binding(
                get: { model.launchAtLoginEnabled },
                set: { model.toggleLaunchAtLogin($0) }
            ))
            .toggleStyle(.switch)

            Divider()

            Text("Global shortcuts")
                .font(.headline)

            ForEach(model.hotKeys) { hotKey in
                HStack(alignment: .firstTextBaseline) {
                    Text(hotKey.layout.title)
                    Spacer()
                    Text(hotKey.displayText)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
