//
//  TempView.swift
//  MiniPi
//
//  Created by Mayank Upadhyay on 15/07/26.
//

import SwiftUI

struct AsteroidView: View {
    // inject the viewModel from route
    @StateObject var viewModel: AsteroidViewModel
    
    func basics() -> some View {
        Text("AsteriodView")
    }
    
    var body: some View {
        PageScaffold(
            pageTitle: "AsteroidView",
            content: {
                basics()
            }
        )
    }
}

//#Preview {
//    TempView()
//}
