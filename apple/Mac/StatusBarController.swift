import AppKit
import SwiftUI

class StatusBarController {
  private var statusBar: NSStatusBar
  private var statusItem: NSStatusItem
  
  init() {
    statusBar = NSStatusBar.system
    statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
    
    if let button = statusItem.button {
      button.title = "Hello"
      button.target = self
      button.action = #selector(showPopover)
    }
  }
  
  @objc func showPopover() {
    if let button = statusItem.button {
      let popover = NSPopover()
      popover.contentViewController = NSHostingController(rootView: ChronographTabView())
      popover.behavior = .transient
      popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
  }
}
