//
//  ContentViewModel.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI
import Combine

class ContentViewModel: ObservableObject {
    @Published var title = "Hello, iPad!"
    @Published var subtitle = "MVVM Architecture"
    
    func titleTapped() {
        print("Title tapped")
    }
}