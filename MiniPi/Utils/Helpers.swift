//
//  Helpers.swift
//  IosDevelopersGuide
//
//  Created by Mayank Upadhyay on 01/03/24.
//

import Foundation

class ScreenData: ObservableObject {
    @Published var height: CGFloat = 0
    @Published var width: CGFloat = 0
    @Published var isCompactHeight: Bool = false
    @Published var isCompactWidth: Bool = false
}
