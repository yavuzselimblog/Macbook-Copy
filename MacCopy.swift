import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate {
    var statusItem: NSStatusItem!
    var menu: NSMenu!
    
    var clipboardHistory: [String] = []
    let maxHistory = 100
    var timer: Timer?
    var lastChangeCount: Int = 0
    let pasteboard = NSPasteboard.general
    
    // UI State
    var showingAllItems: Bool = false
    let maxInitialDisplayCount = 20
    
    // Custom View Components
    var scrollView: NSScrollView!
    var tableView: NSTableView!
    var customMenuItem: NSMenuItem!
    var showAllMenuItem: NSMenuItem!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            if let image = NSImage(named: NSImage.Name("MyIcon")) {
                image.size = NSSize(width: 18, height: 18)
                button.image = image
            } else {
                button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "softwarencodercopylist")
            }
        }
        
        setupMenu()
        startMonitoring()
    }
    
    func setupMenu() {
        menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        
        // Header
        let header = NSMenuItem(title: "softwarencodercopylist History", action: nil, keyEquivalent: "")
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 13)]
        let attrString = NSAttributedString(string: "softwarencodercopylist History", attributes: attrs)
        header.attributedTitle = attrString
        menu.addItem(header)
        menu.addItem(NSMenuItem.separator())
        
        // Custom Scrollable View setup
        setupCustomScrollView()
        customMenuItem = NSMenuItem()
        customMenuItem.view = scrollView
        menu.addItem(customMenuItem)
        
        // Show All Toggle Item
        showAllMenuItem = NSMenuItem(title: "Tümünü Göster / Show All", action: #selector(toggleShowAll), keyEquivalent: "")
        showAllMenuItem.target = self
        menu.addItem(showAllMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        let clearItem = NSMenuItem(title: "Clear History", action: #selector(clearHistory), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }
    
    func setupCustomScrollView() {
        // Main view dimensions
        let frameRect = NSRect(x: 0, y: 0, width: 320, height: 400)
        
        scrollView = NSScrollView(frame: frameRect)
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false // transparent bg
        
        tableView = NSTableView(frame: frameRect)
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("HistoryColumn"))
        column.width = 300
        tableView.addTableColumn(column)
        
        tableView.headerView = nil 
        tableView.dataSource = self
        tableView.delegate = self
        
        // Aesthetics
        tableView.backgroundColor = .clear
        tableView.intercellSpacing = NSSize(width: 0, height: 4) // tighter space between cells
        tableView.selectionHighlightStyle = .none // Handled entirely in custom cells
        
        scrollView.documentView = tableView
    }
    
    var visibleItemCount: Int {
        if clipboardHistory.isEmpty { return 1 } // for "Empty" message
        if showingAllItems { return clipboardHistory.count }
        return min(clipboardHistory.count, maxInitialDisplayCount)
    }
    
    // MARK: - Actions
    
    @objc func toggleShowAll() {
        showingAllItems.toggle()
        showAllMenuItem.title = showingAllItems ? "Daha Az Göster / Show Less" : "Tümünü Göster / Show All"
        
        tableView.reloadData()
        updateMenuHeight()
        
        // Re-open menu to apply height changes smoothly
        if let menu = statusItem.menu {
            menu.cancelTracking()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.statusItem.button?.performClick(nil)
            }
        }
    }
    
    func copyItem(at row: Int) {
        guard row >= 0, row < visibleItemCount, !clipboardHistory.isEmpty else { return }
        
        let text = clipboardHistory[row]
        
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        lastChangeCount = pasteboard.changeCount
        
        // Move to top
        clipboardHistory.remove(at: row)
        clipboardHistory.insert(text, at: 0)
        
        tableView.reloadData()
        
        // Small delay to allow visual click feedback to render before menu closes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.menu.cancelTracking()
        }
    }
    
    @objc func clearHistory() {
        clipboardHistory.removeAll()
        showingAllItems = false
        showAllMenuItem.title = "Tümünü Göster / Show All"
        tableView.reloadData()
        updateMenuUI()
    }
    
    @objc func quit() {
        NSApplication.shared.terminate(self)
    }
    
    // MARK: - Monitoring Actions
    
    func startMonitoring() {
        lastChangeCount = pasteboard.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
    }
    
    func checkForChanges() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        
        if let newString = pasteboard.string(forType: .string) {
            let trimmed = newString.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                if let index = clipboardHistory.firstIndex(of: newString) {
                    clipboardHistory.remove(at: index)
                }
                
                clipboardHistory.insert(newString, at: 0)
                
                if clipboardHistory.count > maxHistory {
                    clipboardHistory.removeLast()
                }
                
                tableView.reloadData()
                updateMenuUI()
            }
        }
    }
    
    func updateMenuUI() {
        showAllMenuItem.isHidden = clipboardHistory.count <= maxInitialDisplayCount
        updateMenuHeight()
    }
    
    func updateMenuHeight() {
        // Calculate required height based on content
        var totalHeight: CGFloat = 0
        for i in 0..<visibleItemCount {
            totalHeight += heightForRow(at: i) + tableView.intercellSpacing.height
        }
        
        let currentHeight = max(40, min(totalHeight, 450)) // max 450px height
        
        scrollView.frame.size.height = currentHeight
        tableView.frame.size.height = max(currentHeight, totalHeight)
        customMenuItem.view?.frame.size.height = currentHeight
    }
    
    // MARK: - NSTableView DataSource & Delegate
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return visibleItemCount
    }
    
    func heightForRow(at index: Int) -> CGFloat {
        if clipboardHistory.isEmpty { return 40 }
        
        // Create a temporary text field to calculate required height for long strings
        let text = clipboardHistory[index].replacingOccurrences(of: "\n", with: " ↵ ")
        let font = NSFont.systemFont(ofSize: 13, weight: .medium)
        // Adjust width to compensate for icon and horizontal padding constraints
        let rect = text.boundingRect(with: NSSize(width: 250, height: CGFloat.greatestFiniteMagnitude),
                                     options: .usesLineFragmentOrigin,
                                     attributes: [.font: font])
        // Compact height constraints
        return min(max(rect.height + 16, 36), 64)
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return heightForRow(at: row)
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("CustomHistoryCell")
        var cellView = tableView.makeView(withIdentifier: identifier, owner: self) as? CustomCellView
        
        if cellView == nil {
            cellView = CustomCellView(frame: NSRect(x: 0, y: 0, width: 300, height: 36))
            cellView?.identifier = identifier
        }
        
        if clipboardHistory.isEmpty {
            cellView?.textFieldLocal.stringValue = "Hafıza Boş / History is empty"
            cellView?.textFieldLocal.textColor = .tertiaryLabelColor
            cellView?.textFieldLocal.alignment = .center
            cellView?.iconView.isHidden = true
            cellView?.copyAction = nil
        } else {
            let displayString = clipboardHistory[row].replacingOccurrences(of: "\n", with: " ↵ ")
            cellView?.textFieldLocal.stringValue = displayString
            cellView?.textFieldLocal.textColor = .labelColor
            cellView?.textFieldLocal.alignment = .left
            cellView?.iconView.isHidden = false
            cellView?.copyAction = { [weak self] in
                self?.copyItem(at: row)
            }
        }
        
        return cellView
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return false // We handle selection via hover and clicks in CustomCellView to keep design clean
    }
}

// Magnificent Custom View for Beautiful Cell layout
class CustomCellView: NSView {
    var textFieldLocal: NSTextField!
    var iconView: NSImageView!
    var containerView: NSView!
    var copyAction: (() -> Void)?
    var trackingArea: NSTrackingArea?
    
    // Modern UI Colors
    let defaultBg = NSColor.textColor.withAlphaComponent(0.03).cgColor
    let hoverBg = NSColor.textColor.withAlphaComponent(0.08).cgColor
    let clickBg = NSColor.controlAccentColor.cgColor
    
    let defaultBorder = NSColor.separatorColor.withAlphaComponent(0.05).cgColor
    let hoverBorder = NSColor.separatorColor.withAlphaComponent(0.3).cgColor
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    func setup() {
        containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 6
        containerView.layer?.backgroundColor = defaultBg
        containerView.layer?.borderWidth = 1
        containerView.layer?.borderColor = defaultBorder
        
        iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: nil)
        iconView.contentTintColor = .secondaryLabelColor
        iconView.imageScaling = .scaleProportionallyUpOrDown
        
        textFieldLocal = NSTextField(labelWithString: "")
        textFieldLocal.lineBreakMode = .byTruncatingTail
        textFieldLocal.maximumNumberOfLines = 3 
        textFieldLocal.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        textFieldLocal.cell?.truncatesLastVisibleLine = true
        
        containerView.translatesAutoresizingMaskIntoConstraints = false
        iconView.translatesAutoresizingMaskIntoConstraints = false
        textFieldLocal.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(containerView)
        containerView.addSubview(iconView)
        containerView.addSubview(textFieldLocal)
        
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            containerView.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1),
            
            iconView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 10),
            iconView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 14),
            iconView.heightAnchor.constraint(equalToConstant: 14),
            
            textFieldLocal.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            textFieldLocal.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -10),
            textFieldLocal.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let ta = trackingArea { removeTrackingArea(ta) }
        trackingArea = NSTrackingArea(rect: bounds, options: [.activeInKeyWindow, .activeAlways, .mouseEnteredAndExited, .inVisibleRect], owner: self, userInfo: nil)
        if let ta = trackingArea { addTrackingArea(ta) }
    }
    
    override func mouseEntered(with event: NSEvent) {
        containerView.layer?.backgroundColor = hoverBg
        containerView.layer?.borderColor = hoverBorder
        NSCursor.pointingHand.push()
    }
    
    override func mouseExited(with event: NSEvent) {
        containerView.layer?.backgroundColor = defaultBg
        containerView.layer?.borderColor = defaultBorder
        NSCursor.pop()
    }
    
    override func mouseDown(with event: NSEvent) {
        containerView.layer?.backgroundColor = clickBg
        textFieldLocal.textColor = .white
        iconView.contentTintColor = .white
    }
    
    override func mouseUp(with event: NSEvent) {
        copyAction?()
        
        // Revert colors with a slight delay so visual click is perceived properly
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.containerView.layer?.backgroundColor = self.hoverBg
            self.textFieldLocal.textColor = .labelColor
            self.iconView.contentTintColor = .secondaryLabelColor
        }
    }
}

// Enable NSMenuDelegate compliance
extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        tableView.reloadData()
        updateMenuUI()
    }
}

// Swift UI App Entry point
@main
struct MacCopyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

