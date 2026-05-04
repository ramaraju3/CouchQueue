import SwiftUI

struct RemoteContentView: View {
    @StateObject private var client: TVClient
    @StateObject private var engine: BrowserEngine

    @State private var displayName = UserDefaults.standard.string(forKey: "displayName") ?? ""
    @State private var title = ""
    @State private var link = ""
    @State private var showClearConfirm = false

    init() {
        let client = TVClient()
        _client = StateObject(wrappedValue: client)
        _engine = StateObject(wrappedValue: BrowserEngine(client: client))
    }

    private var validName: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Someone" : trimmed
    }

    private var selectedItem: RoomItem? {
        client.items.first { $0.id == client.selectedID }
    }

    var body: some View {
        TabView {
            queueTab
                .tabItem { Label("Queue", systemImage: "list.number") }
            BrowserControlView(engine: engine)
                .tabItem { Label("Browser", systemImage: "globe") }
        }
        .onAppear { client.startDiscovery() }
        .onChange(of: displayName) { newValue in
            UserDefaults.standard.set(newValue, forKey: "displayName")
        }
    }

    // MARK: Queue tab

    private var queueTab: some View {
        NavigationView {
            VStack(spacing: 0) {
                statusBar
                submitPanel
                queueList
                hostControls
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("CouchQueue")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var statusBar: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(client.isConnected ? Color.green : Color.orange)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(client.isConnected ? "Connected to room \(client.roomCode)" : "Searching for Apple TV")
                    .font(.subheadline.weight(.semibold))
                if let selectedItem {
                    Text("Now up: \(selectedItem.title)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
    }

    private var submitPanel: some View {
        VStack(spacing: 10) {
            TextField("Your name", text: $displayName)
                .textInputAutocapitalization(.words)
                .textFieldStyle(.roundedBorder)

            TextField("Title, restaurant, product, trip idea", text: $title)
                .textFieldStyle(.roundedBorder)

            TextField("URL or search text", text: $link)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)

            Button { submit() } label: {
                Label("Add to Queue", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!client.isConnected || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var queueList: some View {
        List {
            if client.items.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "rectangle.stack.badge.plus")
                        .font(.system(size: 34))
                        .foregroundStyle(.secondary)
                    Text("No Ideas Yet")
                        .font(.headline)
                    Text("Add a link, search, or option for everyone to vote on.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowBackground(Color.clear)
            } else {
                ForEach(client.items) { item in
                    itemRow(item)
                }
            }
        }
        .listStyle(.plain)
    }

    private func itemRow(_ item: RoomItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)
                    Text(item.url)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Text("by \(item.by)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(item.votes)")
                    .font(.title3.weight(.bold))
                    .frame(minWidth: 34)
            }

            HStack {
                Button {
                    client.sendCommand(RemoteCommand("vote", id: item.id, by: validName))
                } label: {
                    Label(item.voters.contains(validName) ? "Voted" : "Vote",
                          systemImage: item.voters.contains(validName) ? "hand.thumbsup.fill" : "hand.thumbsup")
                }
                .buttonStyle(.bordered)

                Button {
                    client.sendCommand(RemoteCommand("select", id: item.id, by: validName))
                } label: {
                    Label(client.selectedID == item.id ? "On TV" : "Show", systemImage: "tv")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(role: .destructive) {
                    client.sendCommand(RemoteCommand("delete", id: item.id, by: validName))
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
            }
            .font(.subheadline)
        }
        .padding(.vertical, 6)
    }

    private var hostControls: some View {
        HStack {
            Button(role: .destructive) {
                showClearConfirm = true
            } label: {
                Label("Clear", systemImage: "xmark.circle")
            }
            .buttonStyle(.bordered)
            .disabled(!client.isConnected || client.items.isEmpty)
            .confirmationDialog("Clear the entire queue?", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("Clear Queue", role: .destructive) {
                    client.sendCommand(RemoteCommand("clear", by: validName))
                }
            }

            Spacer()

            Text("\(client.items.count) queued")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
    }

    private func submit() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanLink = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }
        client.sendCommand(RemoteCommand(
            "submit",
            id: UUID().uuidString,
            title: cleanTitle,
            url: cleanLink.isEmpty ? cleanTitle : cleanLink,
            by: validName
        ))
        title = ""
        link = ""
    }
}

// MARK: - Browser tab

struct BrowserControlView: View {
    @ObservedObject var engine: BrowserEngine
    @State private var showInput = false
    @State private var inputMode: BrowserInputView.Mode = .navigate

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                previewPanel
                Divider()
                TrackpadView(engine: engine)
                    .frame(height: 240)
                    .padding(12)
            }
            .navigationTitle(engine.pageTitle.isEmpty ? "Browser" : engine.pageTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button { engine.goBack() } label: {
                        Image(systemName: "chevron.left")
                    }
                    Button { engine.goForward() } label: {
                        Image(systemName: "chevron.right")
                    }
                    Button { engine.reload() } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        inputMode = .keyboard
                        showInput = true
                    } label: {
                        Image(systemName: "keyboard")
                    }
                    Button {
                        inputMode = .navigate
                        showInput = true
                    } label: {
                        Image(systemName: "globe")
                    }
                }
            }
        }
        .sheet(isPresented: $showInput) {
            BrowserInputView(engine: engine, isPresented: $showInput, initialMode: inputMode)
        }
        .onAppear {
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = scene.keyWindow ?? scene.windows.first {
                engine.attachWebView(to: window)
            }
            engine.start()
        }
    }

    private var previewPanel: some View {
        Group {
            if let image = engine.previewImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .background(Color.black)
            } else {
                Color(uiColor: .secondarySystemBackground)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .overlay {
                        if engine.isConnected {
                            ProgressView("Loading…")
                        } else {
                            Label("Not connected to Apple TV", systemImage: "wifi.slash")
                                .foregroundStyle(.secondary)
                        }
                    }
            }
        }
    }
}
