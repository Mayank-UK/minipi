//
//  LinkData.swift
//  IosDevelopersGuide
//
//  Created by Mayank Upadhyay on 06/03/24.
//

import Foundation

//  use Identifiable for views that need a stable identity (e.g., list items)
//  use Hashable when you need efficient hashing and equality checks for non-view types
struct LinkData: Hashable {
    var id = UUID()
    var image: String
    var title: String
    var routePath: Router.routePaths
}
