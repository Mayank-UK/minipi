//
//  TempView.swift
//  MiniPi
//
//  Created by Mayank Upadhyay on 15/07/26.
//

import SwiftUI

struct AIModelsView: View {
    // inject the viewModel from route
    @StateObject var viewModel: AIModelsViewModel
    
    func basics() -> some View {
        Text("AIModelsView")
    }
    
    var body: some View {
        PageScaffold(
            title: "AIModelsView",
            mobile: {
                basics()
            }
        )
    }
}

//#Preview {
//    TempView()
//}
