//
//  LogCategory.swift
//  IosDevelopersGuide
//
//  Log categories for different subsystems
//

import Foundation

enum LogCategory: String {
    case database = "Database"
    case network = "Network"
    case ui = "UI"
    case analytics = "Analytics"
    case repository = "Repository"
    case viewModel = "ViewModel"
    case general = "General"
}
