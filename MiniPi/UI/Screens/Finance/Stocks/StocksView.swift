//
//  TempView.swift
//  MiniPi
//
//  Created by Mayank Upadhyay on 15/07/26.
//

import SwiftUI

struct StocksView: View {
    // inject the viewModel from route
    @StateObject var viewModel: StocksViewModel
    
    func basics() -> some View {
        Text("StocksView")
    }
    
    var body: some View {
        PageScaffold(
            title: "StocksView",
            mobile: {
                basics()
            }
        )
    }
}

//#Preview {
//    TempView()
//}
