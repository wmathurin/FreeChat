//
//  ContentView.swift
//  Mantras
//
//  Created by Peter Sugihara on 7/31/23.
//

import SwiftUI
import CoreData
import KeyboardShortcuts
import AppKit

struct ContentView: View {
  @Environment(\.managedObjectContext) private var viewContext
  @Environment(\.openWindow) private var openWindow

  @AppStorage("selectedModelId") private var selectedModelId: String?
  @AppStorage("systemPrompt") private var systemPrompt: String = Agent.DEFAULT_SYSTEM_PROMPT
  @AppStorage("firstLaunchComplete") private var firstLaunchComplete = false
  
  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Model.size, ascending: false)]
  )
  private var models: FetchedResults<Model>

  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Conversation.updatedAt, ascending: true)]
  )
  private var conversations: FetchedResults<Conversation>


  @State private var selection: Set<Conversation> = Set()
  @State private var showDeleteConfirmation = false
  
  var agent: Agent? {
    conversationManager.agent
  }
  
  @EnvironmentObject var conversationManager: ConversationManager
  
  var body: some View {
    NavigationSplitView {
      NavList(selection: $selection, showDeleteConfirmation: $showDeleteConfirmation)
        .navigationSplitViewColumnWidth(min: 160, ideal: 160)
    } detail: {
      if conversationManager.showConversation() {
        ConversationView()
      } else if conversations.count == 0 {
        Text("Hit ⌘N to start a conversation")
      } else {
        Text("Select a conversation")
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification), perform: { output in
      Task {
        await agent?.llama.stopServer()
      }
    })
    .onDeleteCommand { showDeleteConfirmation = true }
    .onAppear(perform: rebootAgent)
    .onAppear(perform: initializeFirstLaunchData)
    .onChange(of: selection) { nextSelection in
      if nextSelection.first != nil {
        conversationManager.currentConversation = nextSelection.first!
      } else {
        conversationManager.unsetConversation()
      }
    }
    .onChange(of: conversationManager.currentConversation) { nextCurrent in
      if !selection.contains(nextCurrent) {
        selection = Set([nextCurrent])
      }
    }
  }
  
  private func initializeFirstLaunchData() {
    if !conversationManager.summonRegistered {
      KeyboardShortcuts.onKeyUp(for: .summonFreeChat) {
        NSApp.activate(ignoringOtherApps: true)
        conversationManager.newConversation(viewContext: viewContext, openWindow: openWindow)
      }
      conversationManager.summonRegistered = true
    }

    if firstLaunchComplete { return }
    conversationManager.newConversation(viewContext: viewContext, openWindow: openWindow)
    firstLaunchComplete = true
  }
  
  private func rebootAgent() {
    let modelId = self.selectedModelId
    let model = models.first { i in i.id?.uuidString == modelId }
    
    conversationManager.rebootAgent(systemPrompt: self.systemPrompt, model: model, viewContext: viewContext)
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    let context = PersistenceController.preview.container.viewContext
    ContentView().environment(\.managedObjectContext, context)
  }
}
