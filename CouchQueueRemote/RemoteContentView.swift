import SwiftUI

struct RemoteContentView: View {
    @StateObject private var client = TVClient()

    @State private var displayName = UserDefaults.standard.string(forKey: "displayName") ?? "Rama"
    @State private var title = ""
    @State private var link = ""

    private var selectedItem: RoomItem? {
        client.items.first { $0.id == client.selectedID }
    }

    var body: some View {
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
        .onAppear { client.startDiscovery() }
        .onChange(of: displayName) { newValue in
            UserDefaults.standard.set(newValue, forKey: "displayName")
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
            HStack {
                TextField("Your name", text: $displayName)
                    .textInputAutocapitalization(.words)
                    .textFieldStyle(.roundedBorder)
            }

            TextField("Title, restaurant, product, trip idea", text: $title)
                .textFieldStyle(.roundedBorder)

            TextField("URL or search text", text: $link)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)

            Button {
                submit()
            } label: {
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
                    client.sendCommand(RemoteCommand("vote", id: item.id, by: displayName))
                } label: {
                    Label(item.voters.contains(displayName) ? "Voted" : "Vote", systemImage: item.voters.contains(displayName) ? "hand.thumbsup.fill" : "hand.thumbsup")
                }
                .buttonStyle(.bordered)

                Button {
                    client.sendCommand(RemoteCommand("select", id: item.id, by: displayName))
                } label: {
                    Label(client.selectedID == item.id ? "On TV" : "Show", systemImage: "tv")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(role: .destructive) {
                    client.sendCommand(RemoteCommand("delete", id: item.id, by: displayName))
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
                client.sendCommand(RemoteCommand("clear", by: displayName))
            } label: {
                Label("Clear", systemImage: "xmark.circle")
            }
            .buttonStyle(.bordered)
            .disabled(!client.isConnected || client.items.isEmpty)

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

        client.sendCommand(
            RemoteCommand(
                "submit",
                id: UUID().uuidString,
                title: cleanTitle,
                url: cleanLink.isEmpty ? cleanTitle : cleanLink,
                by: displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Someone" : displayName
            )
        )
        title = ""
        link = ""
    }
}
