import SwiftUI
import AppKit

@main
struct ScreenRecordApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView() // UIは不要なので空
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var recordingTask: Process?
    var deviceInfoMenuItem: NSMenuItem?
    var deviceSubMenu: NSMenu?
    var connectedDevices: [(id: String, model: String)] = []
    var selectedDeviceID: String = ""
    var readyPopover: NSPopover?
    
    // adb の絶対パスを指定
    let adbPath = "/Users/k_kumamoto/Library/Android/sdk/platform-tools/adb"

    var contentViewState = ContentViewState()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // ステータスバーにアイコンを追加
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "record.circle", accessibilityDescription: "Screen Record")
            button.action = #selector(toggleRecording)
            // 通常のクリックで toggleRecording を呼び出す
        }
        
        // 右クリックメニューの作成
        let rightClickMenu = NSMenu()
        
        // デバイスサブメニューを作成
        deviceSubMenu = NSMenu()
        
        // デバイス情報を表示するメニュー項目
        deviceInfoMenuItem = NSMenuItem(title: "デバイス: 取得中...", action: nil, keyEquivalent: "")
        deviceInfoMenuItem?.submenu = deviceSubMenu
        rightClickMenu.addItem(deviceInfoMenuItem!)
        
        // デバイス情報を取得して表示
        updateDeviceInfo()
        
        rightClickMenu.addItem(NSMenuItem.separator())
        
        // ログイン時に起動するオプション
        let launchAtLoginItem = NSMenuItem(title: "ログイン時に起動", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.state = contentViewState.launchAtLogin ? .on : .off
        rightClickMenu.addItem(launchAtLoginItem)
        
        rightClickMenu.addItem(NSMenuItem.separator())
        rightClickMenu.addItem(NSMenuItem(title: "終了", action: #selector(quitApp), keyEquivalent: "q"))
        
        // 左クリック検出を設定（Alt+クリックでスクリーンショット）
        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            guard let self = self,
                  let button = self.statusItem?.button,
                  let buttonWindow = button.window,
                  buttonWindow.isEqual(event.window),
                  button.frame.contains(button.convert(event.locationInWindow, from: nil)) else {
                return event
            }
            
            // Optionキー（Alt）が押されているかチェック
            if event.modifierFlags.contains(.option) {
                // Alt+クリックの場合、スクリーンショットを撮影
                self.captureScreenshot()
                return nil
            }
            
            // 通常のクリックの場合は、デフォルトのアクション（toggleRecording）を実行
            return event
        }
        
        // 右クリック検出を設定
        NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown]) { [weak self] event in
            guard let self = self,
                  let button = self.statusItem?.button,
                  let buttonWindow = button.window,
                  buttonWindow.isEqual(event.window),
                  button.frame.contains(button.convert(event.locationInWindow, from: nil)) else {
                return event
            }
            
            DispatchQueue.main.async {
                // 右クリック時にデバイス情報を更新
                self.updateDeviceInfo()
                rightClickMenu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
            }
            return nil
        }
        
        // 起動完了メッセージを表示
        showReadyPopover()
    }
    
    func showReadyPopover() {
        guard let button = statusItem?.button else { return }
        
        // ポップオーバーを作成
        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: ReadyPopoverView())
        popover.contentSize = NSSize(width: 260, height: 40)
        
        // メニューバーのボタンの下に表示
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        
        readyPopover = popover
        
        // 10秒後に自動的に閉じる
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.readyPopover?.performClose(nil)
            self?.readyPopover = nil
        }
    }
    
    @objc func toggleRecording(_ sender: AnyObject) {
        // 左クリックで録画操作
        if recordingTask == nil {
            startRecording()
        } else {
            stopRecording()
        }
    }
    
    @objc func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        // 現在の状態を反転
        let newState = !contentViewState.launchAtLogin
        
        // 設定を更新
        contentViewState.toggleLaunchAtLogin(newState)
        
        // メニューアイテムの表示を更新
        sender.state = contentViewState.launchAtLogin ? .on : .off
    }
    
    @objc func quitApp() {
        NSApp.terminate(nil)
    }
    
    @objc func refreshDeviceList(_ sender: NSMenuItem) {
        // デバイス一覧を更新
        updateDeviceInfo()
    }
    
    @objc func selectDevice(_ sender: NSMenuItem) {
        // タグからデバイスのインデックスを取得
        let deviceIndex = sender.tag
        
        if deviceIndex >= 0 && deviceIndex < connectedDevices.count {
            // 選択されたデバイスを設定
            selectedDeviceID = connectedDevices[deviceIndex].id
            
            // サブメニューの全項目のチェックマークをクリア
            deviceSubMenu?.items.forEach { $0.state = .off }
            
            // 選択された項目にチェックマークを設定
            sender.state = .on
            
            // メインメニュー項目のタイトルを更新
            let displayName = connectedDevices[deviceIndex].model.isEmpty ? 
                              connectedDevices[deviceIndex].id : 
                              connectedDevices[deviceIndex].model
            deviceInfoMenuItem?.title = "デバイス: \(displayName)"
        }
    }
    
    func updateDeviceInfo() {
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            
            // デバッグログ - 開始
            Swift.print("デバイス情報取得開始")
            
            // adbで接続されているデバイス情報を取得
            let task = Process()
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe // エラー出力も取得
            task.launchPath = "/bin/bash"
            task.arguments = ["-c", "\(self.adbPath) devices -l"]
            
            do {
                try task.run()
                task.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    // デバッグログ - adb出力
                    Swift.print("ADB出力: \(output)")
                    
                    // デバイス情報を解析
                    let lines = output.components(separatedBy: "\n")
                    var devices: [(id: String, model: String)] = []
                    
                    // 最初の行は "List of devices attached" のようなヘッダーなのでスキップ
                    if lines.count > 1 {
                        Swift.print("検出された行数: \(lines.count)")
                        
                        for i in 1..<lines.count {
                            let line = lines[i].trimmingCharacters(in: .whitespaces)
                            if !line.isEmpty {
                                Swift.print("処理中の行: \(line)")
                                
                                // デバイス情報を抽出 - 最初の空白までがデバイスID
                                if let firstSpaceIndex = line.firstIndex(of: " ") {
                                    let deviceID = String(line[..<firstSpaceIndex]).trimmingCharacters(in: .whitespaces)
                                    let remainder = String(line[firstSpaceIndex...]).trimmingCharacters(in: .whitespaces)
                                    
                                    // デバイスの状態を取得
                                    let components = remainder.components(separatedBy: .whitespaces)
                                    if !components.isEmpty && components[0] == "device" {
                                        // モデル情報を取得
                                        var modelInfo = ""
                                        
                                        // "model:" を含む部分を探す
                                        if let modelRange = line.range(of: "model:") {
                                            // "model:" 以降のテキストを取得
                                            let modelStart = modelRange.upperBound
                                            let modelSuffix = line[modelStart...]
                                            
                                            // 次のスペースまたは文字列の終わりまでが値
                                            if let endSpace = modelSuffix.firstIndex(of: " ") {
                                                modelInfo = String(modelSuffix[..<endSpace])
                                            } else {
                                                modelInfo = String(modelSuffix)
                                            }
                                        }
                                        
                                        Swift.print("デバイス検出: ID=\(deviceID), モデル=\(modelInfo)")
                                        devices.append((id: deviceID, model: modelInfo))
                                    }
                                }
                            }
                        }
                    }
                    
                    // デバッグログ - 検出デバイス
                    Swift.print("検出されたデバイス数: \(devices.count)")
                    
                    // UI更新はメインスレッドで行う
                    DispatchQueue.main.async {
                        self.connectedDevices = devices
                        self.updateDeviceMenu()
                    }
                } else {
                    Swift.print("出力の解析に失敗")
                }
            } catch {
                Swift.print("adbコマンド実行エラー: \(error)")
            }
        }
    }
    
    func updateDeviceMenu() {
        // サブメニューをクリア
        deviceSubMenu?.removeAllItems()
        
        // デバイスの更新ボタンを追加
        deviceSubMenu?.addItem(NSMenuItem(title: "デバイス一覧を更新", action: #selector(refreshDeviceList), keyEquivalent: "r"))
        deviceSubMenu?.addItem(NSMenuItem.separator())
        
        if connectedDevices.isEmpty {
            // 接続デバイスがない場合
            deviceInfoMenuItem?.title = "デバイス: 接続なし"
            deviceSubMenu?.addItem(NSMenuItem(title: "接続されたデバイスがありません", action: nil, keyEquivalent: ""))
            selectedDeviceID = ""
        } else {
            // 接続デバイスがある場合、サブメニューに追加
            for (index, device) in connectedDevices.enumerated() {
                let displayName = device.model.isEmpty ? device.id : device.model
                let menuItem = NSMenuItem(title: displayName, action: #selector(selectDevice(_:)), keyEquivalent: "")
                menuItem.tag = index
                
                // 最初のデバイスか、既に選択されているデバイスならチェックを付ける
                if (selectedDeviceID.isEmpty && index == 0) || device.id == selectedDeviceID {
                    menuItem.state = .on
                    selectedDeviceID = device.id
                    deviceInfoMenuItem?.title = "デバイス: \(displayName)"
                }
                
                deviceSubMenu?.addItem(menuItem)
            }
        }
    }

    func startRecording() {
        // デバイスが選択されていない場合は処理しない
        if selectedDeviceID.isEmpty {
            let alert = NSAlert()
            alert.messageText = "デバイスが選択されていません"
            alert.informativeText = "録画を開始するには、まず右クリックメニューからデバイスを選択してください。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        
        // スクリーンレコードを開始するシェルコマンド
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", "\(adbPath) -s \(selectedDeviceID) shell screenrecord /sdcard/screenrecord1.mp4"]
        task.launch()
        recordingTask = task
        
        if let button = statusItem?.button {
            // 録画中の表示に変更
            button.image = NSImage(systemSymbolName: "record.circle.fill", accessibilityDescription: "Stop Record")
        }
    }

    func stopRecording() {
        guard let task = recordingTask else { return }
        
        // 録画を停止するコマンドを実行
        DispatchQueue.global().async {
            let stopTask = Process()
            stopTask.launchPath = "/bin/bash"
            stopTask.arguments = ["-c", "\(self.adbPath) -s \(self.selectedDeviceID) shell kill -2 $(\(self.adbPath) -s \(self.selectedDeviceID) shell ps | grep screenrecord | awk '{print $2}')"]
            stopTask.launch()
            stopTask.waitUntilExit()
            
            // 1秒待ってからファイルをpull
            Thread.sleep(forTimeInterval: 1.0)
            
            // タイムスタンプを生成 (例: 20241016_123456)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
            let timestamp = dateFormatter.string(from: Date())
            
            // 保存ディレクトリを定義
            let desktopPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop/EmulatorScreenRecords")
            let savePath = desktopPath.appendingPathComponent("screenrecord_\(timestamp).mp4").path
            
            // ディレクトリが存在しない場合は作成
            if !FileManager.default.fileExists(atPath: desktopPath.path) {
                try? FileManager.default.createDirectory(at: desktopPath, withIntermediateDirectories: true, attributes: nil)
            }
            
            // 録画ファイルをローカルにpull
            let pullTask = Process()
            pullTask.launchPath = "/bin/bash"
            pullTask.arguments = ["-c", "\(self.adbPath) -s \(self.selectedDeviceID) pull /sdcard/screenrecord1.mp4 \(savePath) && \(self.adbPath) -s \(self.selectedDeviceID) shell rm /sdcard/screenrecord1.mp4"]
            pullTask.launch()
            pullTask.waitUntilExit()
            
            // Finderで保存先のフォルダを開く
            DispatchQueue.main.async {
                let fileURL = URL(fileURLWithPath: savePath)
                
                // クリップボードにファイルをセット
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.writeObjects([fileURL as NSPasteboardWriting])
                
                // Finderでフォルダを開く
                NSWorkspace.shared.activateFileViewerSelecting([fileURL])
            }
        }

        recordingTask = nil
        
        DispatchQueue.main.async {
            if let button = self.statusItem?.button {
                // 録画終了後、表示を元に戻す
                let newImage = NSImage(systemSymbolName: "record.circle", accessibilityDescription: "Screen Record")
                button.image = newImage
            }
        }
    }
    
    func captureScreenshot() {
        // デバイスが選択されていない場合は処理しない
        if selectedDeviceID.isEmpty {
            let alert = NSAlert()
            alert.messageText = "デバイスが選択されていません"
            alert.informativeText = "スクリーンショットを撮影するには、まず右クリックメニューからデバイスを選択してください。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        
        DispatchQueue.global().async {
            // タイムスタンプを生成 (例: 20241016_123456)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
            let timestamp = dateFormatter.string(from: Date())
            
            // 保存ディレクトリを定義
            let desktopPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop/EmulatorScreenRecords")
            let savePath = desktopPath.appendingPathComponent("screenshot_\(timestamp).png").path
            
            // ディレクトリが存在しない場合は作成
            if !FileManager.default.fileExists(atPath: desktopPath.path) {
                try? FileManager.default.createDirectory(at: desktopPath, withIntermediateDirectories: true, attributes: nil)
            }
            
            // スクリーンショットを撮影
            let screenshotTask = Process()
            screenshotTask.launchPath = "/bin/bash"
            screenshotTask.arguments = ["-c", "\(self.adbPath) -s \(self.selectedDeviceID) shell screencap -p /sdcard/screenshot_temp.png"]
            screenshotTask.launch()
            screenshotTask.waitUntilExit()
            
            // 少し待ってからファイルをpull
            Thread.sleep(forTimeInterval: 0.5)
            
            // スクリーンショットをローカルにpull
            let pullTask = Process()
            pullTask.launchPath = "/bin/bash"
            pullTask.arguments = ["-c", "\(self.adbPath) -s \(self.selectedDeviceID) pull /sdcard/screenshot_temp.png \(savePath) && \(self.adbPath) -s \(self.selectedDeviceID) shell rm /sdcard/screenshot_temp.png"]
            pullTask.launch()
            pullTask.waitUntilExit()
            
            // Finderで保存先のフォルダを開く
            DispatchQueue.main.async {
                let fileURL = URL(fileURLWithPath: savePath)
                
                // クリップボードにファイルをセット
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.writeObjects([fileURL as NSPasteboardWriting])
                
                // Finderでフォルダを開く
                NSWorkspace.shared.activateFileViewerSelecting([fileURL])
            }
        }
    }
}

import ServiceManagement

class ContentViewState: ObservableObject {
    @Published var launchAtLogin: Bool

    init() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func toggleLaunchAtLogin(_ isOn: Bool) {
        do {
            if isOn {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Swift.print(error.localizedDescription)
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}

// 起動完了ポップオーバーのビュー
struct ReadyPopoverView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(.green)
            
            Text("AndroidEmulatorCapture is Ready!")
                .font(.system(size: 13))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
