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
        
        // ログイン時に起動するオプション
        let launchAtLoginItem = NSMenuItem(title: "ログイン時に起動", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.state = contentViewState.launchAtLogin ? .on : .off
        rightClickMenu.addItem(launchAtLoginItem)
        
        rightClickMenu.addItem(NSMenuItem.separator())
        rightClickMenu.addItem(NSMenuItem(title: "終了", action: #selector(quitApp), keyEquivalent: "q"))
        
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
                rightClickMenu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
            }
            return nil
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

    func startRecording() {
        // スクリーンレコードを開始するシェルコマンド
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", "\(adbPath) shell screenrecord /sdcard/screenrecord1.mp4"]
        task.launch()
        recordingTask = task
        
        if let button = statusItem?.button {
            // 録画中の表示に変更
            button.image = NSImage(systemSymbolName: "record.circle.fill", accessibilityDescription: "Stop Record")
            button.title = " Recording..."
        }
    }

    func stopRecording() {
        guard let task = recordingTask else { return }
        
        // 録画を停止するコマンドを実行
        DispatchQueue.global().async {
            let stopTask = Process()
            stopTask.launchPath = "/bin/bash"
            stopTask.arguments = ["-c", "\(self.adbPath) shell kill -2 $(\(self.adbPath) shell ps | grep screenrecord | awk '{print $2}')"]
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
            pullTask.arguments = ["-c", "\(self.adbPath) pull /sdcard/screenrecord1.mp4 \(savePath) && \(self.adbPath) shell rm /sdcard/screenrecord1.mp4"]
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
                button.image = NSImage(systemSymbolName: "record.circle", accessibilityDescription: "Screen Record")
                button.title = "" // "Recording..." の表示を消す
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
