//
//  TempView.swift
//  MiniPi
//
//  Created by Mayank Upadhyay on 15/07/26.
//

import SwiftUI

struct EarthquakeView: View {
    // inject the viewModel from route
    @StateObject var viewModel: EarthquakeViewModel
    
    func basics() -> some View {
        Text("Earthquake")
    }
    
    var body: some View {
        PageScaffold(
            title: "EarthquakeView",
            mobile: {
                basics()
            }
        )
    }
}

//#Preview {
//    TempView()
//}
