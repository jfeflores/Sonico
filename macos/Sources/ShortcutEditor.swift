import SwiftUI

struct ShortcutEditor: View {
    let model: HeadphoneModel
    let save: (ShortcutLayout) -> Void
    @State private var draft: ShortcutLayout
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.sonico) private var colors

    init(model: HeadphoneModel, layout: ShortcutLayout, save: @escaping (ShortcutLayout) -> Void) {
        self.model = model
        self.save = save
        self._draft = State(initialValue: layout)
    }

    var body: some View {
        let snapshot = model.snapshot
        let shortcuts = draft.available(in: snapshot)
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Edit Shortcuts").font(.title2.weight(.semibold)).accessibilityAddTraits(.isHeader)
                Text("Check what you want on My Device, then drag shortcuts or use the arrows to reorder them.")
                    .font(.callout).foregroundStyle(colors.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(XMTheme.margin)
            Divider()
            if shortcuts.isEmpty {
                ContentUnavailableView("No shortcuts available", systemImage: "slider.horizontal.3",
                                       description: Text("No shortcut controls are currently reported by your headphones."))
            } else {
                List {
                    ForEach(shortcuts) { shortcut in
                        let index = shortcuts.firstIndex(of: shortcut) ?? 0
                        let title = shortcut.title(for: snapshot)
                        HStack(spacing: 12) {
                            Toggle(isOn: Binding(get: { draft.isVisible(shortcut) },
                                                 set: { draft.setVisible($0, for: shortcut) })) {
                                Label(title, systemImage: shortcut.symbol)
                            }
                            .toggleStyle(.checkbox)
                            Spacer(minLength: 0)
                            HStack(spacing: 6) {
                                Button("Move \(title) up", systemImage: "chevron.up") {
                                    move(from: IndexSet(integer: index), to: index - 1, among: shortcuts)
                                }
                                .disabled(index == 0)
                                .help("Move up")
                                Button("Move \(title) down", systemImage: "chevron.down") {
                                    move(from: IndexSet(integer: index), to: index + 2, among: shortcuts)
                                }
                                .disabled(index == shortcuts.count - 1)
                                .help("Move down")
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 4)
                    }
                    .onMove { move(from: $0, to: $1, among: shortcuts) }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }
            Divider()
            HStack {
                Button("Restore Defaults") { draft = ShortcutLayout() }
                    .disabled(draft == ShortcutLayout())
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") {
                    save(draft)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(XMTheme.margin)
        }
        .foregroundStyle(colors.text)
        .background(colors.background)
        .frame(width: 480, height: 510)
    }

    private func move(from source: IndexSet, to destination: Int, among shortcuts: [OverviewShortcut]) {
        withAnimation(reduceMotion ? nil : XMMotion.reveal) {
            draft.move(from: source, to: destination, among: shortcuts)
        }
    }
}
