//
//  TempView.swift
//  MiniPi
//
//  Created by Mayank Upadhyay on 15/07/26.
//

import SwiftUI

struct LibraryView: View {
    // inject the viewModel from route
    @StateObject var viewModel: LibraryViewModel
    
    func basics() -> some View {
        Text("LibraryView")
    }
    
    var body: some View {
        PageScaffold(
            title: "LibraryView",
            mobile: {
                basics()
            }
        )
    }
}

//#Preview {
//    TempView()
//}
