// kakaotalk-ax — macOS KakaoTalk accessibility primitives (JSON on stdout).
// Built by `scripts/kakaotalk build` into a fixed path outside the skill directory.
// Every command prints one JSON object. Non-zero exit = failure (JSON still printed).
import Cocoa
import Vision

// MARK: - JSON output

func emit(_ obj: [String: Any], code: Int32 = 0) -> Never {
  let data = try! JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys])
  FileHandle.standardOutput.write(data); FileHandle.standardOutput.write("\n".data(using: .utf8)!)
  exit(code)
}
func fail(_ reason: String, _ extra: [String: Any] = [:], code: Int32 = 1) -> Never {
  var o = extra; o["ok"] = false; o["error"] = reason; emit(o, code: code)
}

// MARK: - AX helpers

let bundleId = "com.kakao.KakaoTalkMac"
let mainWindowTitle = "카카오톡"
let inputDescription = "메시지 입력"

func attr(_ e: AXUIElement, _ a: String) -> AnyObject? {
  var v: AnyObject?; return AXUIElementCopyAttributeValue(e, a as CFString, &v) == .success ? v : nil
}
func kids(_ e: AXUIElement) -> [AXUIElement] { (attr(e, "AXChildren") as? [AXUIElement]) ?? [] }
func role(_ e: AXUIElement) -> String { attr(e, "AXRole") as? String ?? "" }
func str(_ e: AXUIElement, _ a: String) -> String { attr(e, a) as? String ?? "" }
func rect(_ e: AXUIElement) -> CGRect {
  var p = CGPoint.zero, s = CGSize.zero
  if let v = attr(e, "AXPosition") { AXValueGetValue(v as! AXValue, .cgPoint, &p) }
  if let v = attr(e, "AXSize") { AXValueGetValue(v as! AXValue, .cgSize, &s) }
  return CGRect(origin: p, size: s)
}
@discardableResult func setAttr(_ e: AXUIElement, _ a: String, _ v: AnyObject) -> AXError {
  AXUIElementSetAttributeValue(e, a as CFString, v)
}
func sleepMs(_ ms: Int) { usleep(useconds_t(ms * 1000)) }

struct Kakao {
  let running: NSRunningApplication
  let app: AXUIElement
  var pid: pid_t { running.processIdentifier }
  static func connect() -> Kakao {
    guard AXIsProcessTrusted() else {
      fail("accessibility-not-trusted", ["hint": "Grant Accessibility to the process that runs this binary (terminal app, or this binary itself for launchd jobs)."], code: 10)
    }
    guard let r = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first else {
      fail("kakaotalk-not-running", code: 11)
    }
    return Kakao(running: r, app: AXUIElementCreateApplication(r.processIdentifier))
  }
  var windows: [AXUIElement] { (attr(app, "AXWindows") as? [AXUIElement]) ?? [] }
  func window(_ title: String) -> AXUIElement? { windows.first { str($0, "AXTitle") == title } }
  var main: AXUIElement? { window(mainWindowTitle) }
  var chatWindows: [AXUIElement] { windows.filter { inputOf($0) != nil } }
  func postKey(_ code: CGKeyCode) {
    for d in [true, false] { CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: d)!.postToPid(pid) }
  }
}

func inputOf(_ w: AXUIElement) -> AXUIElement? {
  for sa in kids(w) where role(sa) == "AXScrollArea" {
    if let t = kids(sa).first(where: { role($0) == "AXTextArea" && str($0, "AXDescription") == inputDescription }) { return t }
  }
  return nil
}
func messageTable(_ w: AXUIElement) -> (AXUIElement, AXUIElement)? {
  for sa in kids(w) where role(sa) == "AXScrollArea" {
    if let t = kids(sa).first(where: { role($0) == "AXTable" }) { return (sa, t) }
  }
  return nil
}
func rowsOf(_ table: AXUIElement) -> [AXUIElement] { kids(table).filter { role($0) == "AXRow" } }

// MARK: - Chat list (main window)

struct RoomRow { let row: AXUIElement; let name: String; let unread: Int; let time: String; let preview: String; let isSelf: Bool }

func chatList(_ k: Kakao) -> (AXUIElement, [RoomRow])? {
  guard let m = k.main, let (_, table) = messageTable(m) else { return nil }
  var out: [RoomRow] = []
  for row in rowsOf(table) {
    guard let cell = kids(row).first else { continue }
    let ks = kids(cell)
    func byId(_ id: String) -> AXUIElement? { ks.first { str($0, "AXIdentifier") == id } }
    let name = byId("_NS:40").map { str($0, "AXValue") } ?? ""
    let unread = Int(byId("Count Label").map { str($0, "AXValue") } ?? "") ?? 0
    let time = byId("_NS:69").map { str($0, "AXValue") } ?? ""
    var preview = ""
    if let sa = ks.first(where: { role($0) == "AXScrollArea" }), let ta = kids(sa).first { preview = str(ta, "AXValue") }
    let isSelf = ks.contains { str($0, "AXDescription") == "badge me" }
    out.append(RoomRow(row: row, name: name, unread: unread, time: time, preview: preview, isSelf: isSelf))
  }
  return (table, out)
}

// MARK: - Commands

var args = Array(CommandLine.arguments.dropFirst())
func opt(_ name: String) -> String? {
  guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
  return args[i + 1]
}
func flag(_ name: String) -> Bool { args.contains(name) }
let cmd = args.first ?? "help"

func resolveRoom(_ k: Kakao) -> RoomRow {
  guard let (_, rooms) = chatList(k) else { fail("main-window-not-found", ["hint": "Open the KakaoTalk main window (chat list tab)."]) }
  let matches = flag("--self") ? rooms.filter { $0.isSelf } : rooms.filter { $0.name == (opt("--room") ?? "") }
  if matches.isEmpty { fail("room-not-found", ["hint": "Room must be visible in the loaded chat list; use exact name or --self."]) }
  if matches.count > 1 { fail("room-ambiguous", ["count": matches.count]) }
  return matches[0]
}

/// Open (or reuse) a chat window. Returns the window and its title.
func openRoom(_ k: Kakao, allowUnread: Bool, allowActivate: Bool) -> (AXUIElement, String, String) {
  let room = resolveRoom(k)
  if let w = k.window(room.name), inputOf(w) != nil { return (w, room.name, "reused") }
  if room.unread > 0 && !allowUnread {
    fail("room-has-unread", ["unread": room.unread, "hint": "Opening marks messages as read. Pass --allow-unread only with user consent."], code: 3)
  }
  // Enter goes to the app's key window. Refuse if any open chat window holds a draft that Enter could send.
  for w in k.chatWindows where !(str(inputOf(w)!, "AXValue")).isEmpty {
    fail("other-window-has-draft", ["window": str(w, "AXTitle")], code: 3)
  }
  guard let main = k.main, let (_, table) = messageTable(main) else { fail("main-window-not-found") }
  func attempt(activate: Bool) -> AXUIElement? {
    let prev = NSWorkspace.shared.frontmostApplication
    if activate { k.running.activate(); sleepMs(400) }
    AXUIElementPerformAction(main, "AXRaise" as CFString)
    setAttr(main, "AXMain", kCFBooleanTrue)
    setAttr(table, "AXSelectedRows", [room.row] as CFArray)
    setAttr(table, "AXFocused", kCFBooleanTrue)
    sleepMs(250)
    guard let fw = attr(k.app, "AXFocusedWindow"), CFEqual(fw, main) else {
      if activate, let p = prev, p.processIdentifier != k.pid { p.activate() }
      return nil
    }
    k.postKey(36)
    var found: AXUIElement?
    for _ in 0..<15 { sleepMs(200); if let w = k.window(room.name), inputOf(w) != nil { found = w; break } }
    if activate, let p = prev, p.processIdentifier != k.pid { p.activate() }
    return found
  }
  if let w = attempt(activate: false) { return (w, room.name, "opened-background") }
  if allowActivate, let w = attempt(activate: true) { return (w, room.name, "opened-activated") }
  fail("open-failed", ["hint": "Background open did not produce the room window. Retry with --activate (briefly brings KakaoTalk to front)."])
}

func chatWindowArg(_ k: Kakao) -> AXUIElement {
  guard let t = opt("--window") else { fail("missing --window") }
  guard let w = k.window(t), inputOf(w) != nil else { fail("chat-window-not-open", ["window": t]) }
  return w
}

func rowElements(_ w: AXUIElement, _ row: AXUIElement) -> [[String: Any]] {
  let wf = rect(w)
  guard let cell = kids(row).first else { return [] }
  var out: [[String: Any]] = []
  func walk(_ e: AXUIElement, _ depth: Int) {
    let r = rect(e)
    var o: [String: Any] = ["role": role(e), "x": Int(r.minX - wf.minX), "w": Int(r.width), "h": Int(r.height)]
    for (k, a) in [("value", "AXValue"), ("desc", "AXDescription"), ("title", "AXTitle")] {
      let s = str(e, a); if !s.isEmpty { o[k] = s }
    }
    out.append(o)
    if depth < 2 { for c in kids(e) where role(c) != "AXLink" { walk(c, depth + 1) } }
  }
  for e in kids(cell) { walk(e, 0) }
  return out
}

/// Upscale small (1x display) crops before OCR; small Hangul glyphs are misread otherwise.
func upscaled(_ img: CGImage, _ f: Int = 3) -> CGImage {
  guard let ctx = CGContext(data: nil, width: img.width * f, height: img.height * f, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return img }
  ctx.interpolationQuality = .high
  ctx.draw(img, in: CGRect(x: 0, y: 0, width: img.width * f, height: img.height * f))
  return ctx.makeImage() ?? img
}
func ocr(_ src: CGImage) -> [String] {
  let img = src.width < 1200 ? upscaled(src) : src
  let r = VNRecognizeTextRequest()
  r.recognitionLanguages = ["ko-KR", "en-US"]; r.recognitionLevel = .accurate; r.usesLanguageCorrection = false
  try? VNImageRequestHandler(cgImage: img).perform([r])
  return (r.results ?? []).compactMap { $0.topCandidates(1).first?.string }
}

func windowNumber(_ k: Kakao, title: String) -> Int? {
  let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
  return list.first { ($0["kCGWindowOwnerPID"] as? Int32) == k.pid && ($0["kCGWindowName"] as? String) == title }?["kCGWindowNumber"] as? Int
}

func scrollRowIntoView(_ sa: AXUIElement, _ rows: [AXUIElement], _ idx: Int) {
  let first = rect(rows.first!), last = rect(rows.last!), view = rect(sa)
  let range = (last.maxY - first.minY) - view.height
  guard range > 0, let sb = kids(sa).first(where: { role($0) == "AXScrollBar" }) else { return }
  let target = max(0, rect(rows[idx]).midY - first.minY - view.height / 2)
  setAttr(sb, "AXValue", NSNumber(value: Double(min(1, max(0.0001, target / range)))))
  sleepMs(400)
}

// Send: focus input, set value, verify, Enter, verify last row. Never retries.
func send(_ k: Kakao, _ w: AXUIElement, _ text: String) -> [String: Any] {
  let title = str(w, "AXTitle")
  if (attr(w, "AXMinimized") as? Bool) == true {
    if flag("--unminimize") { setAttr(w, "AXMinimized", kCFBooleanFalse); sleepMs(600) }
    else { fail("window-minimized", ["hint": "Sending does not work in a minimized window. Pass --unminimize."], code: 4) }
  }
  guard let input = inputOf(w) else { fail("input-not-found") }
  guard str(input, "AXValue").isEmpty else { fail("draft-present", ["hint": "The input already has text; refusing to overwrite a user draft."], code: 4) }
  guard let (_, table) = messageTable(w) else { fail("message-table-not-found") }
  let before = rowsOf(table).count
  setAttr(input, "AXFocused", kCFBooleanTrue)
  setAttr(input, "AXValue", text as CFString)
  sleepMs(300)
  guard str(input, "AXValue") == text else {
    setAttr(input, "AXValue", "" as CFString)
    fail("input-mismatch", ["hint": "Input did not hold the exact text (IME interference?). Cleared; nothing sent."], code: 4)
  }
  // Enter goes to the focused element of the key window. Confirm focus is our input.
  guard let fe = attr(k.app, "AXFocusedUIElement"), CFEqual(fe, input) else {
    setAttr(input, "AXValue", "" as CFString)
    fail("focus-not-on-input", ["hint": "Cleared; nothing sent."], code: 4)
  }
  // Enter has once landed in a different window than the AX focus reported; never risk sending another window's draft.
  for other in k.chatWindows where !CFEqual(other, w) {
    if let oi = inputOf(other), !str(oi, "AXValue").isEmpty {
      setAttr(input, "AXValue", "" as CFString)
      fail("other-window-has-draft", ["window": str(other, "AXTitle"), "hint": "Cleared our input; nothing sent."], code: 4)
    }
  }
  // Count matching own rows before/after: KakaoTalk keeps undelivered messages pinned at the bottom, so the new
  // row is not necessarily last. Delivered = matching row with a time label; undelivered = retry/delete buttons.
  func tally() -> (sent: Int, failed: Int, any: Int) {
    var s = 0, f = 0, a = 0
    for row in rowsOf(table) {
      let els = rowElements(w, row)
      let tas = els.filter { $0["role"] as? String == "AXTextArea" }
      if tas.isEmpty { continue }
      let body = tas.compactMap { $0["value"] as? String }.joined(separator: "\n")
      let first = tas.first?["value"] as? String ?? ""
      let right = tas.map { ($0["x"] as! Int) + ($0["w"] as! Int) }.max() ?? 0
      guard (body == text || first == text) && right >= Int(rect(w).width) - 30 else { continue }
      a += 1
      let unnamed = els.filter { $0["role"] as? String == "AXButton" && $0["desc"] == nil && $0["title"] == nil }.count
      let hasTime = els.contains { $0["role"] as? String == "AXStaticText" && (($0["value"] as? String)?.range(of: "^(오전|오후) \\d{1,2}:\\d{2}$", options: .regularExpression) != nil) }
      if hasTime { s += 1 } else if unnamed > 0 { f += 1 }
    }
    return (s, f, a)
  }
  let t0 = tally()
  k.postKey(36)
  var t1 = t0
  for _ in 0..<32 {
    sleepMs(250)
    guard str(input, "AXValue").isEmpty, rowsOf(table).count > before else { continue }
    t1 = tally()
    if t1.sent > t0.sent { return ["ok": true, "status": "sent", "window": title] }
    if t1.failed > t0.failed {
      return ["ok": false, "status": "failed-in-app", "window": title, "hint": "KakaoTalk shows retry/delete on this message: not delivered. Do not resend automatically."]
    }
  }
  if t1.any > t0.any {
    return ["ok": false, "status": "unverified", "window": title, "hint": "Message row appeared but neither a time label (sent) nor retry buttons (failed). Check the room; do not resend automatically."]
  }
  if str(input, "AXValue").isEmpty {
    return ["ok": false, "status": "unverified", "window": title, "hint": "Input cleared but the sent row was not confirmed. Do NOT resend automatically; check the room."]
  }
  return ["ok": false, "status": "not-sent", "window": title, "hint": "Input still holds the text; the app did not accept Enter."]
}

switch cmd {
case "check":
  // --prompt: ask macOS to show the Accessibility request, which also adds this binary to the list (toggle off).
  // Only meaningful when this binary is the responsible process (e.g. run by launchd), not under a terminal.
  let trusted = flag("--prompt")
    ? AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
    : AXIsProcessTrusted()
  let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first
  var o: [String: Any] = ["ok": trusted && running != nil, "trusted": trusted, "kakaotalk_running": running != nil]
  if trusted, let r = running {
    let app = AXUIElementCreateApplication(r.processIdentifier)
    o["windows"] = ((attr(app, "AXWindows") as? [AXUIElement]) ?? []).map { str($0, "AXTitle") }
    o["active"] = r.isActive; o["hidden"] = r.isHidden
  }
  emit(o, code: (o["ok"] as! Bool) ? 0 : 1)

case "rooms":
  let k = Kakao.connect()
  guard let (_, rooms) = chatList(k) else { fail("main-window-not-found") }
  emit(["ok": true, "rooms": rooms.map { ["name": $0.name, "unread": $0.unread, "time": $0.time, "preview": $0.preview, "self": $0.isSelf] as [String: Any] }])

case "open":
  let k = Kakao.connect()
  let (_, title, how) = openRoom(k, allowUnread: flag("--allow-unread"), allowActivate: flag("--activate"))
  emit(["ok": true, "window": title, "how": how])

case "rows":
  let k = Kakao.connect(); let w = chatWindowArg(k)
  guard let (sa, table) = messageTable(w) else { fail("message-table-not-found") }
  let view = rect(sa)
  let rows = rowsOf(table).enumerated().map { (i, r) -> [String: Any] in
    let f = rect(r)
    return ["i": i, "h": Int(f.height), "visible": view.intersects(f), "elements": rowElements(w, r)]
  }
  emit(["ok": true, "window": str(w, "AXTitle"), "window_width": Int(rect(w).width), "rows": rows])

case "load-older":
  let k = Kakao.connect(); let w = chatWindowArg(k)
  guard let (sa, table) = messageTable(w), let sb = kids(sa).first(where: { role($0) == "AXScrollBar" }) else { fail("scrollbar-not-found") }
  let before = rowsOf(table).count
  setAttr(sb, "AXValue", NSNumber(value: 0.0))
  var after = before
  for _ in 0..<15 { sleepMs(200); after = rowsOf(table).count; if after > before { break } }
  emit(["ok": true, "before": before, "after": after, "loaded": after - before])

case "capture":
  // capture --window T --row I --out file.png  : scroll row into view, crop to the message viewport, OCR
  let k = Kakao.connect(); let w = chatWindowArg(k)
  guard let (sa, table) = messageTable(w) else { fail("message-table-not-found") }
  guard let idx = Int(opt("--row") ?? ""), let out = opt("--out") else { fail("usage: capture --window T --row I --out file.png") }
  if (attr(w, "AXMinimized") as? Bool) == true || k.running.isHidden { fail("window-not-on-screen", ["hint": "Capture needs the window on screen (it may be covered)."]) }
  var rows = rowsOf(table); guard idx >= 0 && idx < rows.count else { fail("row-out-of-range") }
  scrollRowIntoView(sa, rows, idx); rows = rowsOf(table)
  let title = str(w, "AXTitle")
  guard let wid = windowNumber(k, title: title) else { fail("window-number-not-found", ["hint": "Needs Screen Recording permission for window titles."]) }
  let full = out + ".window.png"
  let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture"); p.arguments = ["-x", "-o", "-l", "\(wid)", full]
  try? p.run(); p.waitUntilExit()
  defer { try? FileManager.default.removeItem(atPath: full) }
  guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: full) as CFURL, nil), let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
    fail("capture-failed", ["hint": "Grant Screen Recording to the terminal app."])
  }
  let wf = rect(w), sc = CGFloat(img.width) / wf.width
  let visible = rect(rows[idx]).intersection(rect(sa))
  guard !visible.isNull, visible.height > 4 else { fail("row-not-visible") }
  let crop = CGRect(x: (visible.minX - wf.minX) * sc, y: (visible.minY - wf.minY) * sc, width: visible.width * sc, height: visible.height * sc)
  guard let c = img.cropping(to: crop) else { fail("crop-failed") }
  let d = CGImageDestinationCreateWithURL(URL(fileURLWithPath: out) as CFURL, "public.png" as CFString, 1, nil)!
  CGImageDestinationAddImage(d, c, nil); CGImageDestinationFinalize(d)
  emit(["ok": true, "path": out, "partial": visible.height < rect(rows[idx]).height - 1, "ocr": flag("--ocr") ? ocr(c) : []])

case "send":
  let k = Kakao.connect(); let w = chatWindowArg(k)
  guard let text = opt("--text"), !text.isEmpty else { fail("missing --text") }
  let r = send(k, w, text)
  emit(r, code: (r["ok"] as? Bool) == true ? 0 : 2)

case "close":
  let k = Kakao.connect(); let w = chatWindowArg(k)
  if let b = kids(w).first(where: { str($0, "AXSubrole") == "AXCloseButton" }) { AXUIElementPerformAction(b, "AXPress" as CFString) }
  emit(["ok": true])

case "job":
  // job <job.json> : run by launchd. Logic lives here because launchd-run processes need their own Accessibility grant.
  runJob(args.count > 1 ? args[1] : "")

default:
  emit(["ok": false, "error": "usage", "commands": ["check", "rooms", "open", "rows", "load-older", "capture", "send", "close", "job"]], code: 64)
}

// MARK: - Scheduled job

func runJob(_ path: String) -> Never {
  let jobURL = URL(fileURLWithPath: path)
  guard let data = try? Data(contentsOf: jobURL), let job = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
    fail("job-unreadable", ["path": path])
  }
  let id = job["id"] as? String ?? "?"
  let label = job["label"] as? String ?? ""
  let plist = job["plist"] as? String ?? ""
  let statePath = path.replacingOccurrences(of: ".json", with: ".state.json")
  let logPath = job["log"] as? String ?? "/dev/null"
  var state = (try? JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: statePath)))) as? [String: Any] ?? [:]
  let now = Date()
  let iso = ISO8601DateFormatter(); iso.timeZone = .current; iso.formatOptions = [.withInternetDateTime]

  func log(_ o: [String: Any]) {
    var e = o; e["at"] = iso.string(from: Date()); e["job"] = id
    let line = (try! JSONSerialization.data(withJSONObject: e, options: [.sortedKeys])) + "\n".data(using: .utf8)!
    if let h = FileHandle(forWritingAtPath: logPath) { h.seekToEndOfFile(); h.write(line); h.closeFile() }
    else { FileManager.default.createFile(atPath: logPath, contents: line) }
  }
  func saveState() {
    if let d = try? JSONSerialization.data(withJSONObject: state, options: [.sortedKeys]) { try? d.write(to: URL(fileURLWithPath: statePath), options: .atomic) }
  }
  func retire(_ why: String) -> Never {
    log(["event": "retired", "reason": why])
    try? FileManager.default.removeItem(atPath: plist)
    try? FileManager.default.removeItem(at: jobURL)
    try? FileManager.default.removeItem(atPath: statePath)
    let p = Process(); p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
    p.arguments = ["bootout", "gui/\(getuid())/\(label)"]; try? p.run(); p.waitUntilExit()
    exit(0)
  }

  // Serialize UI automation across jobs.
  let lockFd = open(jobURL.deletingLastPathComponent().appendingPathComponent(".lock").path, O_CREAT | O_RDWR, 0o600)
  if lockFd >= 0 { flock(lockFd, LOCK_EX) }

  let runs = state["runs"] as? Int ?? 0
  if let until = job["until"] as? Double, now.timeIntervalSince1970 > until { retire("expired") }
  if let maxRuns = job["max_runs"] as? Int, runs >= maxRuns { retire("max-runs-reached") }

  // Lateness gate for calendar-based jobs: launchd fires missed calendar jobs on wake.
  let grace = job["grace_sec"] as? Double ?? 600
  if let at = job["once_at"] as? Double {
    let late = now.timeIntervalSince1970 - at
    if late < -90 { log(["event": "skipped", "reason": "fired-early", "early_sec": -late]); exit(0) }  // same date next year etc.
    if late > grace { retire("missed-window") }
  } else if let entries = job["calendar"] as? [[String: Int]] {
    let cal = Calendar.current
    var matched = false
    var t = now
    while now.timeIntervalSince(t) <= grace && !matched {
      let c = cal.dateComponents([.minute, .hour, .day, .month, .weekday], from: t)
      matched = entries.contains { e in
        (e["Minute"].map { $0 == c.minute } ?? true) && (e["Hour"].map { $0 == c.hour } ?? true) &&
        (e["Day"].map { $0 == c.day } ?? true) && (e["Month"].map { $0 == c.month } ?? true) &&
        (e["Weekday"].map { ($0 % 7) == ((c.weekday! - 1) % 7) } ?? true)
      }
      t = t.addingTimeInterval(-60)
    }
    if !matched { log(["event": "skipped", "reason": "outside-grace-window"]); exit(0) }
  }

  state["runs"] = runs + 1; state["last_run"] = iso.string(from: now); saveState()

  // Every outcome goes through finish(): log, persist, then retire once/max-runs jobs even on failure.
  func finish(_ status: String, _ detail: [String: Any], code: Int32) -> Never {
    log(["event": status, "detail": detail])
    state["last_status"] = status; saveState()
    if job["once_at"] != nil { retire("once-done") }
    if let maxRuns = job["max_runs"] as? Int, runs + 1 >= maxRuns { retire("max-runs-reached") }
    exit(code)
  }
  guard AXIsProcessTrusted() else { finish("failed", ["error": "accessibility-not-trusted"], code: 10) }
  guard NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first != nil else {
    finish("failed", ["error": "kakaotalk-not-running"], code: 11)
  }
  // Re-enter this binary for open+send so fail() exits are captured as JSON.
  let me = CommandLine.arguments[0]
  func sub(_ a: [String]) -> [String: Any] {
    let p = Process(); p.executableURL = URL(fileURLWithPath: me); p.arguments = a
    let pipe = Pipe(); p.standardOutput = pipe; try? p.run(); p.waitUntilExit()
    let d = pipe.fileHandleForReading.readDataToEndOfFile()
    return (try? JSONSerialization.jsonObject(with: d) as? [String: Any]) ?? ["ok": false, "error": "no-output"]
  }
  var openArgs = ["open"]
  if job["self"] as? Bool == true { openArgs.append("--self") } else { openArgs += ["--room", job["room"] as? String ?? ""] }
  if job["allow_unread"] as? Bool == true { openArgs.append("--allow-unread") }
  if job["allow_activate"] as? Bool == true { openArgs.append("--activate") }
  let o = sub(openArgs)
  var result: [String: Any]
  if o["ok"] as? Bool == true, let win = o["window"] as? String {
    result = sub(["send", "--window", win, "--text", job["text"] as? String ?? "", "--unminimize"])
  } else { result = o }
  let status = (result["status"] as? String) ?? ((result["ok"] as? Bool) == true ? "sent" : "failed")
  finish(status, result, code: status == "sent" ? 0 : 2)
}
