import Cocoa
import Foundation
import CoreGraphics
import Darwin

final class Options {
    var configPath: String = "config.json"
    var server: String = "ws://127.0.0.1:8000/ws/mac"
    var token: String = "change-me-123"
    var fps: Double = 12.0
    var quality: CGFloat = 0.45
    var maxWidth: Int = 1280
    var receiveDir: String = "Desktop"
    var skipUnchangedFrames: Bool = true
    var sendUnchangedEverySec: Double = 2.0
}

func currentDirectoryPath(_ path: String) -> String {
    if path.hasPrefix("/") {
        return path
    }

    return FileManager.default.currentDirectoryPath + "/" + path
}

func loadConfig(_ path: String) -> [String: Any]? {
    let fullPath = currentDirectoryPath(path)

    if !FileManager.default.fileExists(atPath: fullPath) {
        return nil
    }

    do {
        let data = try Data(contentsOf: URL(fileURLWithPath: fullPath))
        let obj = try JSONSerialization.jsonObject(with: data, options: [])
        return obj as? [String: Any]
    } catch {
        print("Config read failed: \(error)")
        return nil
    }
}

func numberValue(_ value: Any?) -> Double? {
    if let v = value as? Double {
        return v
    }

    if let v = value as? Int {
        return Double(v)
    }

    if let v = value as? NSNumber {
        return v.doubleValue
    }

    if let v = value as? String {
        return Double(v)
    }

    return nil
}

func boolValue(_ value: Any?) -> Bool? {
    if let v = value as? Bool {
        return v
    }

    if let v = value as? NSNumber {
        return v.boolValue
    }

    if let v = value as? String {
        let lower = v.lowercased()
        if lower == "true" || lower == "yes" || lower == "1" || lower == "on" {
            return true
        }
        if lower == "false" || lower == "no" || lower == "0" || lower == "off" {
            return false
        }
    }

    return nil
}

func applyConfig(_ cfg: [String: Any], to opt: Options) {
    if let value = cfg["server"] as? String, !value.isEmpty {
        opt.server = value
    }

    if let value = cfg["token"] as? String, !value.isEmpty {
        opt.token = value
    }

    if let value = numberValue(cfg["fps"]) {
        opt.fps = value
    }

    if let value = numberValue(cfg["quality"]) {
        opt.quality = CGFloat(value)
    }

    if let value = numberValue(cfg["max_width"]) ?? numberValue(cfg["maxWidth"]) {
        opt.maxWidth = Int(value)
    }

    if let value = cfg["receive_dir"] as? String, !value.isEmpty {
        opt.receiveDir = value
    } else if let value = cfg["receiveDir"] as? String, !value.isEmpty {
        opt.receiveDir = value
    }

    if let value = boolValue(cfg["skip_unchanged_frames"]) ?? boolValue(cfg["skipUnchangedFrames"]) {
        opt.skipUnchangedFrames = value
    }

    if let value = numberValue(cfg["send_unchanged_every_sec"]) ?? numberValue(cfg["sendUnchangedEverySec"]) {
        opt.sendUnchangedEverySec = value
    }
}

func encodeToken(_ token: String) -> String {
    return token.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? token
}

func makeServerURL(_ server: String, token: String) -> String {
    if server.range(of: "token=") != nil {
        return server
    }

    if token.isEmpty {
        return server
    }

    let separator = server.range(of: "?") == nil ? "?" : "&"
    return server + separator + "token=" + encodeToken(token)
}

func tokenFromServerURL(_ server: String) -> String? {
    guard let range = server.range(of: "token=") else {
        return nil
    }

    let afterToken = server[range.upperBound..<server.endIndex]
    let tokenPart = String(afterToken.split(separator: "&", maxSplits: 1, omittingEmptySubsequences: false).first ?? "")

    if tokenPart.isEmpty {
        return nil
    }

    return tokenPart
}

func makeViewerURL(_ server: String, token: String) -> String {
    guard let url = URL(string: server), let host = url.host else {
        return "http://SERVER_IP:8000/viewer/?token=\(encodeToken(token))"
    }

    let scheme = url.scheme == "wss" ? "https" : "http"
    let portPart: String

    if let port = url.port {
        portPart = ":\(port)"
    } else {
        portPart = ""
    }

    let finalToken = tokenFromServerURL(server) ?? encodeToken(token)

    return "\(scheme)://\(host)\(portPart)/viewer/?token=\(finalToken)"
}

func normalizeOptions(_ opt: Options) {
    if opt.fps < 1 { opt.fps = 1 }
    if opt.fps > 20 { opt.fps = 20 }
    if opt.quality < 0.1 { opt.quality = 0.1 }
    if opt.quality > 0.9 { opt.quality = 0.9 }
    if opt.maxWidth < 320 { opt.maxWidth = 320 }
    if opt.sendUnchangedEverySec < 0.5 { opt.sendUnchangedEverySec = 0.5 }
    if opt.sendUnchangedEverySec > 10.0 { opt.sendUnchangedEverySec = 10.0 }

    opt.server = makeServerURL(opt.server, token: opt.token)
}

func readOptions() -> Options {
    let opt = Options()
    let args = CommandLine.arguments

    var scan = 1
    while scan < args.count {
        if args[scan] == "--config" && scan + 1 < args.count {
            opt.configPath = args[scan + 1]
            scan += 2
        } else {
            scan += 1
        }
    }

    if let cfg = loadConfig(opt.configPath) {
        applyConfig(cfg, to: opt)
    }

    var i = 1
    while i < args.count {
        let key = args[i]

        if key == "--config" && i + 1 < args.count {
            opt.configPath = args[i + 1]
            i += 2
        } else if key == "--server" && i + 1 < args.count {
            opt.server = args[i + 1]
            i += 2
        } else if key == "--token" && i + 1 < args.count {
            opt.token = args[i + 1]
            i += 2
        } else if key == "--fps" && i + 1 < args.count {
            opt.fps = Double(args[i + 1]) ?? opt.fps
            i += 2
        } else if key == "--quality" && i + 1 < args.count {
            opt.quality = CGFloat(Double(args[i + 1]) ?? Double(opt.quality))
            i += 2
        } else if key == "--max-width" && i + 1 < args.count {
            opt.maxWidth = Int(args[i + 1]) ?? opt.maxWidth
            i += 2
        } else if key == "--receive-dir" && i + 1 < args.count {
            opt.receiveDir = args[i + 1]
            i += 2
        } else if key == "--skip-unchanged-frames" && i + 1 < args.count {
            opt.skipUnchangedFrames = boolValue(args[i + 1]) ?? opt.skipUnchangedFrames
            i += 2
        } else if key == "--send-unchanged-every-sec" && i + 1 < args.count {
            opt.sendUnchangedEverySec = Double(args[i + 1]) ?? opt.sendUnchangedEverySec
            i += 2
        } else {
            i += 1
        }
    }

    normalizeOptions(opt)
    return opt
}

func randomBytes(_ count: Int) -> [UInt8] {
    var bytes = [UInt8](repeating: 0, count: count)
    for i in 0..<count {
        bytes[i] = UInt8(arc4random_uniform(256))
    }
    return bytes
}

func dataFromBytes(_ bytes: [UInt8]) -> Data {
    if bytes.isEmpty {
        return Data()
    }

    return bytes.withUnsafeBufferPointer { buffer in
        return Data(bytes: buffer.baseAddress!, count: bytes.count)
    }
}

func appendByte(_ data: inout Data, _ byte: UInt8) {
    var value = byte
    data.append(&value, count: 1)
}

func appendBytes(_ data: inout Data, _ bytes: [UInt8]) {
    if bytes.isEmpty {
        return
    }

    bytes.withUnsafeBufferPointer { buffer in
        if let base = buffer.baseAddress {
            data.append(base, count: bytes.count)
        }
    }
}

func appendBytes(_ data: inout Data, _ bytes: [UInt8], count: Int) {
    if bytes.isEmpty || count <= 0 {
        return
    }

    let realCount = min(bytes.count, count)
    bytes.withUnsafeBufferPointer { buffer in
        if let base = buffer.baseAddress {
            data.append(base, count: realCount)
        }
    }
}

func makeWebSocketKey() -> String {
    return dataFromBytes(randomBytes(16)).base64EncodedString()
}

func checksumData(_ data: Data) -> UInt64 {
    let bytes = [UInt8](data)

    if bytes.isEmpty {
        return 0
    }

    var hash: UInt64 = 1469598103934665603
    let step = max(1, bytes.count / 4096)
    var index = 0

    while index < bytes.count {
        hash = hash ^ UInt64(bytes[index])
        hash = hash &* 1099511628211
        index += step
    }

    hash = hash ^ UInt64(bytes.count)
    return hash
}

final class WebSocketClient {
    private let url: URL
    private var inputStream: InputStream?
    private var outputStream: OutputStream?
    private let writeLock = NSLock()
    private var connected = false

    var onText: ((String) -> Void)?

    init(url: URL) {
        self.url = url
    }

    func isConnected() -> Bool {
        return connected
    }

    func connect() throws {
        guard let host = url.host else {
            throw NSError(domain: "RemoteMacAgent", code: 1, userInfo: [NSLocalizedDescriptionKey: "Bad host"])
        }

        let port = url.port ?? 80
        var readStream: Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?

        CFStreamCreatePairWithSocketToHost(nil, host as CFString, UInt32(port), &readStream, &writeStream)

        guard let rs = readStream?.takeRetainedValue(), let ws = writeStream?.takeRetainedValue() else {
            throw NSError(domain: "RemoteMacAgent", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot create streams"])
        }

        inputStream = rs
        outputStream = ws

        inputStream?.open()
        outputStream?.open()

        let path = makePath(url)
        let key = makeWebSocketKey()
        let request =
            "GET \(path) HTTP/1.1\r\n" +
            "Host: \(host):\(port)\r\n" +
            "Upgrade: websocket\r\n" +
            "Connection: Upgrade\r\n" +
            "Sec-WebSocket-Key: \(key)\r\n" +
            "Sec-WebSocket-Version: 13\r\n" +
            "\r\n"

        guard let requestData = request.data(using: .utf8) else {
            throw NSError(domain: "RemoteMacAgent", code: 3, userInfo: [NSLocalizedDescriptionKey: "Bad request"])
        }

        requestData.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) in
            _ = outputStream?.write(bytes, maxLength: requestData.count)
        }

        let response = try readHTTPHeader()

        if !response.contains("101") {
            throw NSError(domain: "RemoteMacAgent", code: 4, userInfo: [NSLocalizedDescriptionKey: "Handshake failed: \(response)"])
        }

        connected = true

        DispatchQueue.global(qos: .userInitiated).async {
            self.readLoop()
        }
    }

    func close() {
        connected = false
        inputStream?.close()
        outputStream?.close()
    }

    private func makePath(_ url: URL) -> String {
        var path = url.path
        if path.isEmpty { path = "/" }
        if let query = url.query, !query.isEmpty {
            path += "?\(query)"
        }
        return path
    }

    private func readHTTPHeader() throws -> String {
        var buffer = [UInt8](repeating: 0, count: 1)
        var data = Data()

        while true {
            let n = inputStream?.read(&buffer, maxLength: 1) ?? -1
            if n <= 0 {
                throw NSError(domain: "RemoteMacAgent", code: 5, userInfo: [NSLocalizedDescriptionKey: "Header read failed"])
            }

            appendByte(&data, buffer[0])

            if data.count >= 4 {
                let suffix = data.suffix(4)
                if Array(suffix) == [13, 10, 13, 10] {
                    break
                }
            }
        }

        return String(data: data, encoding: .utf8) ?? ""
    }

    private func readExactly(_ count: Int) -> Data? {
        var result = Data()
        var buffer = [UInt8](repeating: 0, count: max(1, min(4096, count)))

        while result.count < count {
            let need = min(buffer.count, count - result.count)
            let n = inputStream?.read(&buffer, maxLength: need) ?? -1
            if n <= 0 { return nil }
            appendBytes(&result, buffer, count: n)
        }

        return result
    }

    private func readLoop() {
        while connected {
            guard let header = readExactly(2) else {
                connected = false
                break
            }

            let h = [UInt8](header)
            let opcode = h[0] & 0x0F
            let masked = (h[1] & 0x80) != 0
            var length = Int(h[1] & 0x7F)

            if length == 126 {
                guard let ext = readExactly(2) else { connected = false; break }
                let b = [UInt8](ext)
                length = (Int(b[0]) << 8) | Int(b[1])
            } else if length == 127 {
                guard let ext = readExactly(8) else { connected = false; break }
                let b = [UInt8](ext)
                var v: UInt64 = 0
                for x in b {
                    v = (v << 8) | UInt64(x)
                }
                length = Int(v)
            }

            var maskKey: [UInt8] = []
            if masked {
                guard let mask = readExactly(4) else { connected = false; break }
                maskKey = [UInt8](mask)
            }

            guard var payload = readExactly(length) else {
                connected = false
                break
            }

            if masked {
                var bytes = [UInt8](payload)
                for i in 0..<bytes.count {
                    bytes[i] = bytes[i] ^ maskKey[i % 4]
                }
                payload = dataFromBytes(bytes)
            }

            if opcode == 0x8 {
                connected = false
                break
            } else if opcode == 0x9 {
                sendFrame(opcode: 0xA, payload: payload)
            } else if opcode == 0x1 {
                if let text = String(data: payload, encoding: .utf8) {
                    onText?(text)
                }
            }
        }

        close()
    }

    func sendText(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        sendFrame(opcode: 0x1, payload: data)
    }

    func sendBinary(_ data: Data) {
        sendFrame(opcode: 0x2, payload: data)
    }

    private func sendFrame(opcode: UInt8, payload: Data) {
        if !connected { return }

        writeLock.lock()
        defer { writeLock.unlock() }

        var frame = Data()
        appendByte(&frame, 0x80 | opcode)

        let len = payload.count
        let maskBit: UInt8 = 0x80

        if len <= 125 {
            appendByte(&frame, maskBit | UInt8(len))
        } else if len <= 65535 {
            appendByte(&frame, maskBit | 126)
            appendByte(&frame, UInt8((len >> 8) & 0xFF))
            appendByte(&frame, UInt8(len & 0xFF))
        } else {
            appendByte(&frame, maskBit | 127)
            var v = UInt64(len)
            var bytes = [UInt8](repeating: 0, count: 8)
            for i in stride(from: 7, through: 0, by: -1) {
                bytes[i] = UInt8(v & 0xFF)
                v >>= 8
            }
            appendBytes(&frame, bytes)
        }

        let mask = randomBytes(4)
        appendBytes(&frame, mask)

        var payloadBytes = [UInt8](payload)
        for i in 0..<payloadBytes.count {
            payloadBytes[i] = payloadBytes[i] ^ mask[i % 4]
        }
        appendBytes(&frame, payloadBytes)

        frame.withUnsafeBytes { (base: UnsafePointer<UInt8>) in
            var written = 0

            while written < frame.count {
                let n = outputStream?.write(base.advanced(by: written), maxLength: frame.count - written) ?? -1
                if n <= 0 {
                    connected = false
                    break
                }
                written += n
            }
        }
    }
}

func screenInfo() -> (width: Int, height: Int) {
    let display = CGMainDisplayID()
    return (Int(CGDisplayPixelsWide(display)), Int(CGDisplayPixelsHigh(display)))
}

func captureJPEG(maxWidth: Int, quality: CGFloat) -> Data? {
    let display = CGMainDisplayID()

    guard let image = CGDisplayCreateImage(display) else {
        return nil
    }

    let originalWidth = image.width
    let originalHeight = image.height

    var targetWidth = originalWidth
    var targetHeight = originalHeight

    if originalWidth > maxWidth {
        let scale = CGFloat(maxWidth) / CGFloat(originalWidth)
        targetWidth = maxWidth
        targetHeight = Int(CGFloat(originalHeight) * scale)
    }

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

    guard let context = CGContext(
        data: nil,
        width: targetWidth,
        height: targetHeight,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    ) else {
        return nil
    }

    context.interpolationQuality = .medium
    context.draw(image, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

    guard let scaled = context.makeImage() else {
        return nil
    }

    let rep = NSBitmapImageRep(cgImage: scaled)
    return rep.representation(using: .jpeg, properties: [NSBitmapImageRep.PropertyKey.compressionFactor: quality])
}

var lastMousePoint = CGPoint(x: 100, y: 100)

func postMouseMove(xNorm: Double, yNorm: Double) {
    let info = screenInfo()
    let x = CGFloat(max(0.0, min(1.0, xNorm)) * Double(info.width))
    let y = CGFloat(max(0.0, min(1.0, yNorm)) * Double(info.height))
    let point = CGPoint(x: x, y: y)
    lastMousePoint = point

    let source = CGEventSource(stateID: .hidSystemState)
    if let event = CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left) {
        event.post(tap: .cghidEventTap)
    }
}

func mouseButton(_ name: String) -> CGMouseButton {
    if name == "right" {
        return .right
    }
    return .left
}

func mouseTypes(_ button: CGMouseButton, down: Bool) -> CGEventType {
    if button == .right {
        return down ? .rightMouseDown : .rightMouseUp
    }
    return down ? .leftMouseDown : .leftMouseUp
}

func postMouse(buttonName: String, down: Bool, clickState: Int64 = 1) {
    let btn = mouseButton(buttonName)
    let type = mouseTypes(btn, down: down)
    let source = CGEventSource(stateID: .hidSystemState)

    if let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: lastMousePoint, mouseButton: btn) {
        event.setIntegerValueField(.mouseEventClickState, value: clickState)
        event.post(tap: .cghidEventTap)
    }
}

func postClick(buttonName: String) {
    postMouse(buttonName: buttonName, down: true, clickState: 1)
    usleep(35000)
    postMouse(buttonName: buttonName, down: false, clickState: 1)
}

func postDoubleClick(buttonName: String) {
    postMouse(buttonName: buttonName, down: true, clickState: 1)
    usleep(25000)
    postMouse(buttonName: buttonName, down: false, clickState: 1)
    usleep(65000)
    postMouse(buttonName: buttonName, down: true, clickState: 2)
    usleep(25000)
    postMouse(buttonName: buttonName, down: false, clickState: 2)
}

func postRightClick() {
    postMouse(buttonName: "right", down: true, clickState: 1)
    usleep(35000)
    postMouse(buttonName: "right", down: false, clickState: 1)
}

func postScroll(dx: Double, dy: Double) {
    return
}

func keyCodeForSpecial(_ key: String) -> CGKeyCode? {
    switch key {
    case "Enter": return 36
    case "Backspace": return 51
    case "Tab": return 48
    case "Escape": return 53
    case "ArrowLeft": return 123
    case "ArrowRight": return 124
    case "ArrowDown": return 125
    case "ArrowUp": return 126
    case "Delete": return 117
    case "Home": return 115
    case "End": return 119
    case "PageUp": return 116
    case "PageDown": return 121
    default: return nil
    }
}

func postSpecialKey(_ code: CGKeyCode) {
    let source = CGEventSource(stateID: .hidSystemState)

    if let down = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true) {
        down.post(tap: .cghidEventTap)
    }

    usleep(20000)

    if let up = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false) {
        up.post(tap: .cghidEventTap)
    }
}

func keyCodeForName(_ key: String) -> CGKeyCode? {
    let k = key.lowercased()

    if let code = keyCodeForSpecial(key) {
        return code
    }

    switch k {
    case "a": return 0
    case "s": return 1
    case "d": return 2
    case "f": return 3
    case "h": return 4
    case "g": return 5
    case "z": return 6
    case "x": return 7
    case "c": return 8
    case "v": return 9
    case "b": return 11
    case "q": return 12
    case "w": return 13
    case "e": return 14
    case "r": return 15
    case "y": return 16
    case "t": return 17
    case "1": return 18
    case "2": return 19
    case "3": return 20
    case "4": return 21
    case "6": return 22
    case "5": return 23
    case "=": return 24
    case "9": return 25
    case "7": return 26
    case "-": return 27
    case "8": return 28
    case "0": return 29
    case "]": return 30
    case "o": return 31
    case "u": return 32
    case "[": return 33
    case "i": return 34
    case "p": return 35
    case "l": return 37
    case "j": return 38
    case "'": return 39
    case "k": return 40
    case ";": return 41
    case "\\": return 42
    case ",": return 43
    case "/": return 44
    case "n": return 45
    case "m": return 46
    case ".": return 47
    case "space", " ": return 49
    default: return nil
    }
}

func flagsForHotkey(_ keys: [String]) -> CGEventFlags {
    var flags = CGEventFlags()

    for key in keys {
        switch key.lowercased() {
        case "cmd", "command", "meta":
            flags.insert(.maskCommand)
        case "ctrl", "control":
            flags.insert(.maskControl)
        case "alt", "option":
            flags.insert(.maskAlternate)
        case "shift":
            flags.insert(.maskShift)
        default:
            break
        }
    }

    return flags
}

func mainKeyForHotkey(_ keys: [String]) -> CGKeyCode? {
    for key in keys {
        let lower = key.lowercased()
        if lower == "cmd" || lower == "command" || lower == "meta" || lower == "os" || lower == "ctrl" || lower == "control" || lower == "alt" || lower == "option" || lower == "shift" {
            continue
        }

        return keyCodeForName(key)
    }

    return nil
}

func hasFlag(_ flags: CGEventFlags, _ target: CGEventFlags) -> Bool {
    return (flags.rawValue & target.rawValue) != 0
}

func modifierCodesForFlags(_ flags: CGEventFlags) -> [CGKeyCode] {
    var codes: [CGKeyCode] = []

    if hasFlag(flags, .maskCommand) {
        codes.append(55)
    }

    if hasFlag(flags, .maskShift) {
        codes.append(56)
    }

    if hasFlag(flags, .maskAlternate) {
        codes.append(58)
    }

    if hasFlag(flags, .maskControl) {
        codes.append(59)
    }

    return codes
}

func postModifierKey(_ code: CGKeyCode, down: Bool) {
    let source = CGEventSource(stateID: .hidSystemState)

    if let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down) {
        event.post(tap: .cghidEventTap)
    }
}

func postKeyWithFlags(_ code: CGKeyCode, flags: CGEventFlags) {
    let source = CGEventSource(stateID: .hidSystemState)
    let modifiers = modifierCodesForFlags(flags)

    for modifier in modifiers {
        postModifierKey(modifier, down: true)
        usleep(8000)
    }

    if let down = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true) {
        down.flags = flags
        down.post(tap: .cghidEventTap)
    }

    usleep(30000)

    if let up = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false) {
        up.flags = flags
        up.post(tap: .cghidEventTap)
    }

    usleep(8000)

    for modifier in modifiers.reversed() {
        postModifierKey(modifier, down: false)
        usleep(8000)
    }
}

func normalizedHotkeyKeys(_ keys: [String]) -> [String] {
    var normalized: [String] = []

    for raw in keys {
        let lower = raw.lowercased()

        if lower == "control" {
            normalized.append("ctrl")
        } else if lower == "command" || lower == "meta" || lower == "os" {
            normalized.append("cmd")
        } else if lower == "option" {
            normalized.append("alt")
        } else if lower == " " || lower == "spacebar" {
            normalized.append("space")
        } else {
            normalized.append(lower)
        }
    }

    return normalized
}

func isModifierOnlyHotkey(_ keys: [String]) -> Bool {
    if keys.isEmpty {
        return true
    }

    for key in keys {
        let lower = key.lowercased()

        if lower != "cmd" &&
           lower != "ctrl" &&
           lower != "control" &&
           lower != "alt" &&
           lower != "option" &&
           lower != "shift" &&
           lower != "meta" &&
           lower != "command" {
            return false
        }
    }

    return true
}

func macFriendlyHotkeyKeys(_ keys: [String]) -> [String] {
    let normalized = normalizedHotkeyKeys(keys)

    if isModifierOnlyHotkey(normalized) {
        return normalized
    }

    let cmdActions: Set<String> = ["a", "c", "v", "x", "z", "s", "w", "q", "f", "p", "n", "o", "t", "r"]

    var hasCtrl = false
    var hasCmd = false
    var hasAlt = false
    var result: [String] = []
    var action = ""

    for key in normalized {
        if key == "ctrl" {
            hasCtrl = true
        } else if key == "cmd" {
            hasCmd = true
            result.append(key)
        } else if key == "alt" {
            hasAlt = true
            result.append(key)
        } else {
            result.append(key)

            if key != "shift" {
                action = key
            }
        }
    }

    if hasCtrl && !hasCmd && !hasAlt && cmdActions.contains(action) {
        var converted: [String] = []

        for key in result {
            if key == "ctrl" {
                continue
            }

            converted.append(key)
        }

        if !converted.contains("cmd") {
            converted.insert("cmd", at: 0)
        }

        return converted
    }

    if hasCtrl {
        result.insert("ctrl", at: 0)
    }

    return result
}

func postHotkey(_ keys: [String]) {
    let fixedKeys = macFriendlyHotkeyKeys(keys)

    if isModifierOnlyHotkey(fixedKeys) {
        return
    }

    guard let code = mainKeyForHotkey(fixedKeys) else {
        print("Unknown hotkey: \(keys) -> \(fixedKeys)")
        return
    }

    print("Hotkey: \(keys) -> \(fixedKeys)")
    postKeyWithFlags(code, flags: flagsForHotkey(fixedKeys))
}

func postText(_ text: String) {
    let source = CGEventSource(stateID: .hidSystemState)

    for scalar in text.unicodeScalars {
        var value = UniChar(scalar.value)

        if let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) {
            down.keyboardSetUnicodeString(stringLength: 1, unicodeString: &value)
            down.post(tap: .cghidEventTap)
        }

        usleep(10000)

        if let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
            up.keyboardSetUnicodeString(stringLength: 1, unicodeString: &value)
            up.post(tap: .cghidEventTap)
        }

        usleep(10000)
    }
}


final class FileTransfer {
    let id: String
    let originalName: String
    let finalPath: String
    let expectedSize: Int
    var writtenSize: Int = 0
    var handle: FileHandle?

    init(id: String, originalName: String, finalPath: String, expectedSize: Int, handle: FileHandle?) {
        self.id = id
        self.originalName = originalName
        self.finalPath = finalPath
        self.expectedSize = expectedSize
        self.handle = handle
    }
}

var receiveDirectoryPath = ""
var activeTransfers: [String: FileTransfer] = [:]
var currentWebSocket: WebSocketClient? = nil

func expandReceiveDir(_ value: String) -> String {
    let fm = FileManager.default
    let home = NSHomeDirectory()

    if value == "Desktop" || value == "" {
        return home + "/Desktop"
    }

    if value.hasPrefix("~/") {
        return home + "/" + String(value.dropFirst(2))
    }

    if value.hasPrefix("/") {
        return value
    }

    return fm.currentDirectoryPath + "/" + value
}

func sanitizeFileName(_ name: String) -> String {
    var result = ""

    for scalar in name.unicodeScalars {
        let value = scalar.value

        if scalar == "/" || scalar == "\\" || scalar == ":" || value < 32 {
            result += "_"
        } else {
            result.append(String(scalar))
        }
    }

    let trimmed = result.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

    if trimmed.isEmpty {
        return "received_file"
    }

    if trimmed == "." || trimmed == ".." {
        return "received_file"
    }

    return trimmed
}

func uniquePathForFile(_ directory: String, _ fileName: String) -> String {
    let fm = FileManager.default
    let cleanName = sanitizeFileName(fileName)
    let baseURL = URL(fileURLWithPath: directory).appendingPathComponent(cleanName)

    if !fm.fileExists(atPath: baseURL.path) {
        return baseURL.path
    }

    let ext = baseURL.pathExtension
    let stemURL = baseURL.deletingPathExtension()
    let stem = stemURL.lastPathComponent

    for index in 1...999 {
        let candidateName: String

        if ext.isEmpty {
            candidateName = "\(stem) copy \(index)"
        } else {
            candidateName = "\(stem) copy \(index).\(ext)"
        }

        let candidate = URL(fileURLWithPath: directory).appendingPathComponent(candidateName).path

        if !fm.fileExists(atPath: candidate) {
            return candidate
        }
    }

    return URL(fileURLWithPath: directory).appendingPathComponent("\(cleanName).received").path
}

func ensureReceiveDirectory() -> Bool {
    let fm = FileManager.default
    var isDir: ObjCBool = false

    if fm.fileExists(atPath: receiveDirectoryPath, isDirectory: &isDir) {
        return isDir.boolValue
    }

    do {
        try fm.createDirectory(atPath: receiveDirectoryPath, withIntermediateDirectories: true, attributes: nil)
        return true
    } catch {
        print("Cannot create receive dir: \(error)")
        return false
    }
}

func fileTransferBegin(_ obj: [String: Any]) {
    guard ensureReceiveDirectory() else {
        return
    }

    let id = obj["id"] as? String ?? ""
    let name = obj["name"] as? String ?? "received_file"

    if id.isEmpty {
        return
    }

    if let old = activeTransfers[id] {
        old.handle?.closeFile()
        try? FileManager.default.removeItem(atPath: old.finalPath)
        activeTransfers.removeValue(forKey: id)
    }

    let size = Int(numberValue(obj["size"]) ?? 0)
    let finalPath = uniquePathForFile(receiveDirectoryPath, name)

    FileManager.default.createFile(atPath: finalPath, contents: nil, attributes: nil)

    guard let handle = FileHandle(forWritingAtPath: finalPath) else {
        print("Cannot open file for writing: \(finalPath)")
        return
    }

    activeTransfers[id] = FileTransfer(id: id, originalName: name, finalPath: finalPath, expectedSize: size, handle: handle)
    print("Receiving file: \(name) -> \(finalPath)")
}

func fileTransferChunk(_ obj: [String: Any]) {
    let id = obj["id"] as? String ?? ""
    let dataText = obj["data"] as? String ?? ""

    guard let transfer = activeTransfers[id] else {
        return
    }

    guard let data = Data(base64Encoded: dataText, options: []) else {
        print("Bad file chunk: \(transfer.originalName)")
        return
    }

    transfer.handle?.write(data)
    transfer.writtenSize += data.count
}

func fileTransferEnd(_ obj: [String: Any]) {
    let id = obj["id"] as? String ?? ""

    guard let transfer = activeTransfers[id] else {
        return
    }

    transfer.handle?.closeFile()
    activeTransfers.removeValue(forKey: id)

    if transfer.expectedSize > 0 && transfer.expectedSize != transfer.writtenSize {
        print("File received with size mismatch: \(transfer.originalName), expected \(transfer.expectedSize), got \(transfer.writtenSize)")
    } else {
        print("File received: \(transfer.finalPath), \(transfer.writtenSize) bytes")
    }
}

func fileTransferCancel(_ obj: [String: Any]) {
    let id = obj["id"] as? String ?? ""

    guard let transfer = activeTransfers[id] else {
        return
    }

    transfer.handle?.closeFile()
    activeTransfers.removeValue(forKey: id)

    try? FileManager.default.removeItem(atPath: transfer.finalPath)
    print("File transfer canceled: \(transfer.originalName)")
}


func parseJSON(_ text: String) -> [String: Any]? {
    guard let data = text.data(using: .utf8) else { return nil }

    do {
        let obj = try JSONSerialization.jsonObject(with: data, options: [])
        return obj as? [String: Any]
    } catch {
        return nil
    }
}


func jsonEscape(_ text: String) -> String {
    var result = ""

    for scalar in text.unicodeScalars {
        switch scalar {
        case "\"":
            result += "\\\""
        case "\\":
            result += "\\\\"
        case "\n":
            result += "\\n"
        case "\r":
            result += "\\r"
        case "\t":
            result += "\\t"
        default:
            if scalar.value < 32 {
                result += String(format: "\\u%04x", scalar.value)
            } else {
                result.append(String(scalar))
            }
        }
    }

    return result
}

func sendClipboardText(_ value: String) {
    let json = "{\"type\":\"clipboard_text\",\"text\":\"\(jsonEscape(value))\"}"
    currentWebSocket?.sendText(json)
}

func sendClipboardStatus(_ ok: Bool) {
    let json = "{\"type\":\"clipboard_status\",\"ok\":\(ok ? "true" : "false")}"
    currentWebSocket?.sendText(json)
}

func pasteboardString() -> String {
    let pb = NSPasteboard.general

    if let value = pb.string(forType: NSPasteboard.PasteboardType.string) {
        return value
    }

    return ""
}

func setPasteboardString(_ value: String) -> Bool {
    let pb = NSPasteboard.general
    pb.clearContents()
    return pb.setString(value, forType: NSPasteboard.PasteboardType.string)
}

func handleCommand(_ text: String) {
    guard let obj = parseJSON(text) else {
        return
    }

    guard let type = obj["type"] as? String else {
        return
    }

    if type == "move" {
        let x = obj["x"] as? Double ?? 0
        let y = obj["y"] as? Double ?? 0
        postMouseMove(xNorm: x, yNorm: y)
    } else if type == "mousedown" {
        let button = obj["button"] as? String ?? "left"
        postMouse(buttonName: button, down: true)
    } else if type == "mouseup" {
        let button = obj["button"] as? String ?? "left"
        postMouse(buttonName: button, down: false)
    } else if type == "click" {
        let button = obj["button"] as? String ?? "left"
        postClick(buttonName: button)
    } else if type == "doubleclick" {
        let button = obj["button"] as? String ?? "left"
        postDoubleClick(buttonName: button)
    } else if type == "rightclick" {
        postRightClick()
    } else if type == "scroll" {
        let dx = obj["dx"] as? Double ?? 0
        let dy = obj["dy"] as? Double ?? 0
        postScroll(dx: dx, dy: dy)
    } else if type == "key" {
        let key = obj["key"] as? String ?? ""
        if let code = keyCodeForSpecial(key) {
            postSpecialKey(code)
        } else if key.count == 1 {
            postText(key)
        } else if key == " " || key == "Spacebar" {
            postText(" ")
        }
    } else if type == "hotkey" {
        if let keys = obj["keys"] as? [String] {
            postHotkey(keys)
        }
    } else if type == "file_begin" {
        fileTransferBegin(obj)
    } else if type == "file_chunk" {
        fileTransferChunk(obj)
    } else if type == "file_end" {
        fileTransferEnd(obj)
    } else if type == "file_cancel" {
        fileTransferCancel(obj)
    } else if type == "clipboard_get" {
        sendClipboardText(pasteboardString())
    } else if type == "clipboard_set" {
        let value = obj["text"] as? String ?? ""
        let ok = setPasteboardString(value)
        sendClipboardStatus(ok)
    } else if type == "clipboard_set_and_paste" {
        let value = obj["text"] as? String ?? ""
        if setPasteboardString(value) {
            print("Clipboard set and paste: \(value.count) chars")
            usleep(60000)
            postHotkey(["cmd", "v"])
            sendClipboardStatus(true)
        } else {
            print("Clipboard set failed")
            sendClipboardStatus(false)
        }
    } else if type == "text" {
        let value = obj["text"] as? String ?? ""
        postText(value)
    }
}

func sendMeta(_ ws: WebSocketClient) {
    let info = screenInfo()
    let meta: [String: Any] = [
        "type": "meta",
        "width": info.width,
        "height": info.height
    ]

    if let data = try? JSONSerialization.data(withJSONObject: meta, options: []),
       let text = String(data: data, encoding: .utf8) {
        ws.sendText(text)
    }
}

let options = readOptions()
receiveDirectoryPath = expandReceiveDir(options.receiveDir)

let viewerURL = makeViewerURL(options.server, token: options.token)

print("RemoteMacAgent")
print("Config: \(options.configPath)")
print("Server: \(options.server)")
print("Connect URL: \(viewerURL)")
print("FPS: \(options.fps)")
print("Quality: \(options.quality)")
print("Max width: \(options.maxWidth)")
print("Receive dir: \(options.receiveDir)")
print("Skip unchanged frames: \(options.skipUnchangedFrames)")
print("Send unchanged every sec: \(options.sendUnchangedEverySec)")
print("Press Ctrl+C to stop")
print("")

guard let url = URL(string: options.server) else {
    print("Bad server URL")
    exit(1)
}

if url.scheme != "ws" {
    print("Only ws:// is supported in this MVP. Use VPN or local network instead of wss://.")
    exit(1)
}

while true {
    let ws = WebSocketClient(url: url)
    currentWebSocket = ws
    ws.onText = { text in
        handleCommand(text)
    }

    do {
        print("Connecting...")
        try ws.connect()
        print("Connected")
        sendMeta(ws)

        let delay = useconds_t(1000000.0 / options.fps)
        var metaCounter = 0
        var frameCounter = 0
        var skippedCounter = 0
        var lastChecksum: UInt64 = 0
        var lastSize = -1
        var lastSentAt = Date().timeIntervalSince1970
        let logEvery = max(1, Int(options.fps * 10))

        while ws.isConnected() {
            if let jpeg = captureJPEG(maxWidth: options.maxWidth, quality: options.quality) {
                let now = Date().timeIntervalSince1970
                let checksum = checksumData(jpeg)
                let unchanged = options.skipUnchangedFrames && jpeg.count == lastSize && checksum == lastChecksum
                let heartbeatDue = (now - lastSentAt) >= options.sendUnchangedEverySec

                lastChecksum = checksum
                lastSize = jpeg.count

                if !unchanged || heartbeatDue {
                    ws.sendBinary(jpeg)
                    lastSentAt = now
                    frameCounter += 1

                    if frameCounter % logEvery == 0 {
                        print("Frames sent: \(frameCounter), skipped unchanged: \(skippedCounter)")
                    }
                } else {
                    skippedCounter += 1
                }
            }

            metaCounter += 1
            if metaCounter >= Int(options.fps * 5) {
                sendMeta(ws)
                metaCounter = 0
            }

            usleep(delay)
        }

        print("Disconnected")
    } catch {
        print("Connection failed: \(error)")
        print("Waiting for server. Retry in 3 sec...")
    }

    ws.close()
    if currentWebSocket === ws {
        currentWebSocket = nil
    }
    sleep(3)
}
