//
//  PageScaffold.swift
//  IosDevelopersGuide
//
//  Created by Mayank Upadhyay on 05/03/24.
//

import SwiftUI

struct PageScaffold<Content: View>: View {
    let pageTitle: String
    private let children: Content
    
    init(pageTitle: String, @ViewBuilder content: @escaping () -> Content) {
        self.children = content()
        self.pageTitle = pageTitle
    }
    
    var body: some View {
        ScrollView(.vertical){
            Spacer().frame(height: 32)
            children
        }
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Text(pageTitle)
                        .bold()
                        .font(.system(size: 24))
                        .foregroundColor(Color.black)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
        
    }
}

#Preview {
    PageScaffold(
        pageTitle: "Test",
        content: {
            Text("Hello world!")
        }
    )
}
