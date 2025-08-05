//
//  _dof_viewerApp.swift
//  3dof_viewer
//
//  Created by wayne on 2025/8/5.
//

import SwiftUI

@main
struct _dof_viewerApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationView {
                ContentView()
            }
            .navigationViewStyle(StackNavigationViewStyle()) // 强制在iPad上使用单栏模式
        }
    }
}
