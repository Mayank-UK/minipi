//
//  TempView.swift
//  MiniPi
//
//  Created by Mayank Upadhyay on 15/07/26.
//

import SwiftUI

struct WeatherView: View {
    // inject the viewModel from route
    @StateObject var viewModel: WeatherViewModel
    
    func basics() -> some View {
        Text("WeatherView")
    }
    
    var body: some View {
        PageScaffold(
            pageTitle: "WeatherView",
            content: {
                basics()
            }
        )
    }
}

//#Preview {
//    TempView()
//}
