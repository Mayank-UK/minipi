//
//  TempView.swift
//  MiniPi
//
//  Created by Mayank Upadhyay on 15/07/26.
//

import SwiftUI

struct IndicatorsView: View {
    // inject the viewModel from route
    @StateObject var viewModel: IndicatorsViewModel
    
    func basics() -> some View {
        Text("IndicatorsView")
    }
    
    var body: some View {
        PageScaffold(
            title: "IndicatorsView",
            mobile: {
                basics()
            }
        )
    }
}

//#Preview {
//    TempView()
//}
