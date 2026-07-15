//
//  TempView.swift
//  MiniPi
//
//  Created by Mayank Upadhyay on 15/07/26.
//

import SwiftUI

struct ForexView: View {
    // inject the viewModel from route
    @StateObject var viewModel: ForexViewModel
    
    func basics() -> some View {
        Text("ForexView")
    }
    
    var body: some View {
        PageScaffold(
            title: "ForexView",
            mobile: {
                basics()
            }
        )
    }
}

//#Preview {
//    TempView()
//}
