import SwiftUI
import CoreImage.CIFilterBuiltins

struct ContentView: View {
    @StateObject private var server = TVServer()

    @State private var items: [RoomItem] = []
    @State private var selectedID: String?
    @State private var roomCode = String(Int.random(in: 1000...9999))

    private var selectedItem: RoomItem? {
        items.first { $0.id == selectedID } ?? items.first
    }

    private var rankedItems: [RoomItem] {
        items.sorted {
            if $0.votes == $1.votes { return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            return $0.votes > $1.votes
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.06, blue: 0.08), Color(red: 0.11, green: 0.09, blue: 0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            HStack(spacing: 36) {
                mainPanel
                queuePanel
            }
            .padding(48)
        }
        .onAppear {
            server.onCommand = handle
            server.start()
            broadcastState()
        }
    }

    private var mainPanel: some View {
        VStack(alignment: .leading, spacing: 28) {
            header

            if let selectedItem {
                selectedCard(selectedItem)
            } else {
                emptyState
            }

            Spacer()

            joinPanel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CouchQueue")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Shared queue for deciding what everyone sees next.")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.68))
        }
    }

    private func selectedCard(_ item: RoomItem) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Now Up")
                    .font(.headline)
                    .foregroundStyle(.black.opacity(0.65))
                Spacer()
                Label("\(item.votes)", systemImage: "hand.thumbsup.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.black.opacity(0.72))
            }

            Text(item.title)
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
                .lineLimit(3)
                .minimumScaleFactor(0.65)

            Text(item.url)
                .font(.title3)
                .foregroundStyle(.black.opacity(0.65))
                .lineLimit(2)

            Text("Submitted by \(item.by)")
                .font(.headline)
                .foregroundStyle(.black.opacity(0.56))
        }
        .padding(34)
        .frame(maxWidth: .infinity, minHeight: 310, alignment: .topLeading)
        .background(Color(red: 0.94, green: 0.89, blue: 0.74))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("No ideas yet")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Open the remote app on the same Wi-Fi and add the first link, search, restaurant, product, or trip idea.")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.64))
                .lineLimit(3)
        }
        .padding(34)
        .frame(maxWidth: .infinity, minHeight: 310, alignment: .leading)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var joinPanel: some View {
        HStack(spacing: 22) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.white)
                qrImage(for: roomCode)
                    .interpolation(.none)
                    .resizable()
                    .padding(10)
            }
            .frame(width: 160, height: 160)

            VStack(alignment: .leading, spacing: 8) {
                Text("Room \(roomCode)")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(server.isClientConnected ? "Remote connected" : "Waiting for remote")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(server.isClientConnected ? .green : .orange)
                Text("Guest web join is the next layer; this build uses the iPhone remote as the first client.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.56))
                    .lineLimit(2)
            }
        }
    }

    private var queuePanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Queue")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(items.count)")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
            }

            if rankedItems.isEmpty {
                Spacer()
                Text("Submitted ideas will rank here as people vote.")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.56))
                    .multilineTextAlignment(.center)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Array(rankedItems.enumerated()), id: \.element.id) { index, item in
                            queueRow(item, rank: index + 1)
                        }
                    }
                }
            }
        }
        .padding(24)
        .frame(width: 520)
        .frame(maxHeight: .infinity)
        .background(Color.black.opacity(0.28))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func queueRow(_ item: RoomItem, rank: Int) -> some View {
        HStack(spacing: 14) {
            Text("\(rank)")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(item.by)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.48))
            }

            Spacer()

            Label("\(item.votes)", systemImage: "hand.thumbsup.fill")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.76))
        }
        .padding(14)
        .background(item.id == selectedItem?.id ? Color.white.opacity(0.18) : Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func handle(_ command: RemoteCommand) {
        switch command.t {
        case "submit":
            submit(command)
        case "vote":
            vote(command)
        case "select":
            if let id = command.id { selectedID = id }
        case "delete":
            if let id = command.id {
                items.removeAll { $0.id == id }
                if selectedID == id { selectedID = items.first?.id }
            }
        case "clear":
            items.removeAll()
            selectedID = nil
        default:
            break
        }

        broadcastState()
    }

    private func submit(_ command: RemoteCommand) {
        let id = command.id ?? UUID().uuidString
        let title = (command.title?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "Untitled"
        let url = (command.url?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? title
        let by = (command.by?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "Someone"

        guard !items.contains(where: { $0.id == id }) else { return }
        let item = RoomItem(id: id, title: title, url: url, by: by, votes: 0, voters: [])
        items.append(item)
        selectedID = selectedID ?? id
    }

    private func vote(_ command: RemoteCommand) {
        guard let id = command.id,
              let by = command.by,
              let index = items.firstIndex(where: { $0.id == id }) else { return }

        if items[index].voters.contains(by) {
            items[index].voters.removeAll { $0 == by }
            items[index].votes = max(0, items[index].votes - 1)
        } else {
            items[index].voters.append(by)
            items[index].votes += 1
        }
    }

    private func qrImage(for code: String) -> Image {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(code.utf8)
        let context = CIContext()
        if let ciImage = filter.outputImage,
           let cgImage = context.createCGImage(
               ciImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
               from: ciImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10)).extent) {
            return Image(uiImage: UIImage(cgImage: cgImage))
        }
        return Image(systemName: "qrcode")
    }

    private func broadcastState() {
        server.sendState(RoomState(items: rankedItems, selectedID: selectedID, roomCode: roomCode))
    }
}
