import SwiftUI

struct BrowserInputView: View {
    enum Mode { case navigate, keyboard }

    let engine: BrowserEngine
    @Binding var isPresented: Bool
    var initialMode: Mode = .navigate

    @State private var mode: Mode = .navigate
    @State private var urlText = ""
    @State private var keyText = ""
    @State private var lastKey = ""
    @FocusState private var urlFocused: Bool
    @FocusState private var keyFocused: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("Mode", selection: $mode) {
                    Text("Navigate").tag(Mode.navigate)
                    Text("Keyboard").tag(Mode.keyboard)
                }
                .pickerStyle(.segmented)
                .padding()

                if mode == .navigate { navigatePane }
                else { keyboardPane }

                Spacer()
            }
            .navigationTitle(mode == .navigate ? "Go to…" : "Type on TV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { isPresented = false }
                }
            }
        }
        .onAppear {
            mode = initialMode
            if initialMode == .navigate { urlFocused = true }
            else { keyFocused = true }
        }
    }

    // MARK: Navigate pane

    private var navigatePane: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Enter a URL or search term")
                .font(.subheadline).foregroundColor(.secondary).padding(.horizontal)

            HStack {
                TextField("google.com or search…", text: $urlText)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .focused($urlFocused)
                    .onSubmit { submitURL() }
                Button("Go") { submitURL() }
                    .buttonStyle(.borderedProminent)
                    .disabled(urlText.isEmpty)
            }
            .padding(.horizontal)

            // Quick-access shortcuts
            LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), spacing: 8) {
                ForEach(quickSites, id: \.0) { name, url in
                    Button {
                        engine.navigate(to: url)
                        isPresented = false
                    } label: {
                        Text(name)
                            .font(.callout)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .cornerRadius(8)
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 4)
        }
        .padding(.top, 8)
    }

    private let quickSites: [(String, String)] = [
        ("YouTube", "https://www.youtube.com"),
        ("Twitch",  "https://www.twitch.tv"),
        ("Reddit",  "https://www.reddit.com"),
        ("Netflix", "https://www.netflix.com"),
        ("Plex",    "https://app.plex.tv"),
        ("Google",  "https://www.google.com"),
    ]

    private func submitURL() {
        guard !urlText.isEmpty else { return }
        engine.navigate(to: urlText)
        isPresented = false
    }

    // MARK: Keyboard pane

    private var keyboardPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Type here — text goes into the focused field on TV")
                .font(.subheadline).foregroundColor(.secondary).padding(.horizontal)

            TextField("Start typing…", text: $keyText)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .focused($keyFocused)
                .padding(.horizontal)
                .onChange(of: keyText) { new in
                    let delta = new.count - lastKey.count
                    if delta > 0 {
                        engine.injectText(String(new.suffix(delta)))
                    } else if delta < 0 {
                        for _ in 0..<abs(delta) { engine.deleteChar() }
                    }
                    lastKey = new
                }

            HStack(spacing: 12) {
                Button {
                    engine.deleteChar()
                    if !keyText.isEmpty {
                        let updated = String(keyText.dropLast())
                        lastKey = updated   // sync before keyText so onChange sees delta = 0
                        keyText = updated
                    }
                } label: {
                    Label("Delete", systemImage: "delete.left").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    engine.injectText("\n")
                } label: {
                    Label("Return", systemImage: "return").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button("Clear") {
                    for _ in keyText.indices { engine.deleteChar() }
                    keyText = ""; lastKey = ""
                }
                .buttonStyle(.bordered).foregroundColor(.red)
            }
            .padding(.horizontal)
        }
        .padding(.top, 8)
        .onAppear { keyFocused = true }
    }
}
