import Foundation
import Network
import Combine

struct RemoteCommand: Codable {
    var t: String
    var id: String?
    var title: String?
    var url: String?
    var by: String?
    var dx: Double?
    var dy: Double?
    var v: String?
    var nx: Double?
    var ny: Double?

    init(_ t: String, id: String? = nil, title: String? = nil, url: String? = nil, by: String? = nil,
         dx: Double? = nil, dy: Double? = nil, v: String? = nil, nx: Double? = nil, ny: Double? = nil) {
        self.t = t
        self.id = id
        self.title = title
        self.url = url
        self.by = by
        self.dx = dx
        self.dy = dy
        self.v = v
        self.nx = nx
        self.ny = ny
    }
}

struct RoomItem: Codable, Identifiable, Equatable {
    let id: String
    var title: String
    var url: String
    var by: String
    var votes: Int
    var voters: [String]
}

struct RoomState: Codable {
    var items: [RoomItem]
    var selectedID: String?
    var roomCode: String
}

// Binary protocol [type: 1 byte][length: 4 bytes BE][payload]
// 0x01 = JSON command, 0x03 = JSON room state.
class TVClient: ObservableObject {
    private var browser: NWBrowser?
    private var connection: NWConnection?
    private var recvBuf = Data()
    private var pendingType: UInt8?
    private var pendingLen: UInt32?

    @Published var isConnected = false
    @Published var items: [RoomItem] = []
    @Published var selectedID: String?
    @Published var roomCode = "----"

    func startDiscovery() {
        if browser != nil { return }

        let desc = NWBrowser.Descriptor.bonjour(type: "_couchqueue._tcp", domain: nil)
        let params = NWParameters.tcp
        params.includePeerToPeer = true
        let b = NWBrowser(for: desc, using: params)
        browser = b
        b.browseResultsChangedHandler = { [weak self] results, _ in
            guard let endpoint = results.first?.endpoint else { return }
            DispatchQueue.main.async { self?.connect(to: endpoint) }
        }
        b.start(queue: .main)
    }

    private func connect(to endpoint: NWEndpoint) {
        guard !isConnected, connection == nil else { return }
        let conn = NWConnection(to: endpoint, using: .tcp)
        connection = conn
        conn.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.isConnected = true
                    self?.readLoop()
                case .failed, .cancelled:
                    self?.reset()
                default:
                    break
                }
            }
        }
        conn.start(queue: .main)
    }

    private func reset() {
        isConnected = false
        connection = nil
        browser?.cancel()
        browser = nil
        recvBuf = Data()
        pendingType = nil
        pendingLen = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in self?.startDiscovery() }
    }

    func sendCommand(_ cmd: RemoteCommand) {
        guard let data = try? JSONEncoder().encode(cmd) else { return }
        transmit(type: 0x01, payload: data)
    }

    func sendFrame(_ jpeg: Data) {
        transmit(type: 0x02, payload: jpeg)
    }

    private func transmit(type: UInt8, payload: Data) {
        guard isConnected else { return }
        var msg = Data([type])
        var len = UInt32(payload.count).bigEndian
        withUnsafeBytes(of: &len) { msg.append(contentsOf: $0) }
        msg.append(payload)
        connection?.send(content: msg, completion: .idempotent)
    }

    private func readLoop() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 131_072) { [weak self] data, _, isDone, err in
            guard let self else { return }
            if let data, !data.isEmpty {
                self.recvBuf.append(data)
                self.drain()
            }
            if !isDone && err == nil { self.readLoop() }
        }
    }

    private func drain() {
        while true {
            if pendingLen == nil {
                guard recvBuf.count >= 5 else { return }
                pendingType = recvBuf[0]
                let b = recvBuf
                pendingLen = (UInt32(b[1]) << 24) | (UInt32(b[2]) << 16) | (UInt32(b[3]) << 8) | UInt32(b[4])
                recvBuf = recvBuf.dropFirst(5)
            }

            guard let type = pendingType, let len = pendingLen, recvBuf.count >= Int(len) else { return }
            let payload = Data(recvBuf.prefix(Int(len)))
            recvBuf = recvBuf.dropFirst(Int(len))
            pendingType = nil
            pendingLen = nil

            switch type {
            case 0x03:
                if let state = try? JSONDecoder().decode(RoomState.self, from: payload) {
                    items = state.items
                    selectedID = state.selectedID
                    roomCode = state.roomCode
                }
            default:
                break
            }
        }
    }
}
