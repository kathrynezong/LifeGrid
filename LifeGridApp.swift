//
//  LifeGridApp.swift
//  LifeGrid
//
//  Created by Stuart  on 2026-02-08.
//

import SwiftUI

@main
struct LifeGridApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
