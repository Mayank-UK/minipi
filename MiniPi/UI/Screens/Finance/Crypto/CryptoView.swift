//
//  TempView.swift
//  MiniPi
//
//  Created by Mayank Upadhyay on 15/07/26.
//

import SwiftUI

struct CryptoView: View {
    // inject the viewModel from route
    @StateObject var viewModel: CryptoViewModel
    
    func basics() -> some View {
        Text("CryptoView")
    }
    
    var body: some View {
        PageScaffold(
            title: "CryptoView",
            mobile: {
                basics()
            }
        )
    }
}

//#Preview {
//    TempView()
//}
