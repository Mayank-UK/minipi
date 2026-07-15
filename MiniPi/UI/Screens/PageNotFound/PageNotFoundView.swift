//
//  PageNotFound.swift
//  IosDevelopersGuide
//
//  Created by Mayank Upadhyay on 01/03/24.
//

import SwiftUI

struct PageNotFoundView: View {    
    // inject the viewModel from route
    @StateObject var viewModel: PageNotFoundViewModel
    
    var body: some View {
        PageScaffold(
            pageTitle: "Page not found",
            content: {
                Text("Page not found")
                    .frame(maxWidth: .infinity)
                    .frame(height: 500)
                
            }
        )
    }
}

//#Preview {
//    PageNotFoundView()
//}
