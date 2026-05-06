import Foundation
import Network

// Queue actions received from the iPhone Remote app.
struct RemoteCommand: Codable {
    let t: String
    var id: String?
    var title: String?
    var url: String?
    var by: String?
    var nx: Double?
    var ny: Double?
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

// Binary message protocol  [type: 1 byte][length: 4 bytes BE][payload]
// type 0x01 = UTF-8 JSON (RemoteCommand)
// type 0x03 = UTF-8 JSON (RoomState)

class TVServer: ObservableObject {
    private var listener: NWListener?
    private var activeConn: NWConnection?
    private var recvBuf = Data()
    private var pendingType: UInt8?
    private var pendingLen: UInt32?

    @Published var isClientConnected = false
    @Published var frameData: Data?
    @Published var cursorNX: CGFloat = 0.5
    @Published var cursorNY: CGFloat = 0.5

    var onCommand: ((RemoteCommand) -> Void)?
    func start() {
        guard listener == nil else { return }
        guard let l = try? NWListener(using: .tcp, on: 8765) else {
            print("[TVServer] Could not bind port 8765"); return
        }
        listener = l
        l.service = NWListener.Service(name: nil, type: "_couchqueue._tcp")
        l.newConnectionHandler = { [weak self] conn in
            DispatchQueue.main.async { self?.accept(conn) }
        }
        l.start(queue: .main)
        print("[TVServer] Advertising _couchqueue._tcp on :8765")
    }

    private func accept(_ conn: NWConnection) {
        activeConn?.cancel()
        recvBuf = Data(); pendingType = nil; pendingLen = nil
        activeConn = conn
        isClientConnected = true
        conn.stateUpdateHandler = { [weak self] st in
            switch st {
            case .failed, .cancelled: DispatchQueue.main.async { self?.drop() }
            default: break
            }
        }
        conn.start(queue: .main)
        readLoop()
    }

    private func drop() { isClientConnected = false; activeConn = nil }

    func sendState(_ state: RoomState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        transmit(type: 0x03, payload: data)
    }

    private func readLoop() {
        activeConn?.receive(minimumIncompleteLength: 1, maximumLength: 131_072) { [weak self] data, _, isDone, err in
            guard let self else { return }
            if let data, !data.isEmpty { self.recvBuf.append(data); self.drain() }
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
            pendingType = nil; pendingLen = nil

            switch type {
            case 0x01:
                if let cmd = try? JSONDecoder().decode(RemoteCommand.self, from: payload) {
                    if cmd.t == "cursor", let nx = cmd.nx, let ny = cmd.ny {
                        cursorNX = CGFloat(nx)
                        cursorNY = CGFloat(ny)
                    } else {
                        onCommand?(cmd)
                    }
                }
            case 0x02:
                frameData = payload
            default: break
            }
        }
    }

    private func transmit(type: UInt8, payload: Data) {
        var msg = Data([type])
        var len = UInt32(payload.count).bigEndian
        withUnsafeBytes(of: &len) { msg.append(contentsOf: $0) }
        msg.append(payload)
        activeConn?.send(content: msg, completion: .idempotent)
    }
}
