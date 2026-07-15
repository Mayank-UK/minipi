//
//  TempView.swift
//  MiniPi
//
//  Created by Mayank Upadhyay on 15/07/26.
//

import SwiftUI

struct TempView: View {
    // inject the viewModel from route
    @StateObject var viewModel: TempViewModel
    
    func basics() -> some View {
        Text("Hello world!")
    }
    
    var body: some View {
        PageScaffold(
            title: "TestView",
            mobile: {
                basics()
            }
        )
    }
}

//#Preview {
//    TempView()
//}
