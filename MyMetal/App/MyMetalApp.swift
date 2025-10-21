//
//  MyMetalApp.swift
//  MyMetal
//
//  Created by Yauheni Kozich on 29.10.24.
//

import SwiftUI

@main
struct MyMetalApp: App {
    var body: some Scene {
        WindowGroup {
            // Теперь используем полную версию с улучшенной диагностикой
           // CubeMetalView()
            // SimpleMetalView() // Простая версия для отладки
            MetalDemoView()
        }
    }
}
