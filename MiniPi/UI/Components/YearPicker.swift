//
//  YearPicker.swift
//  MiniPi
//
//  A compact Menu-based year selector for the Indicators Ranking / Stats / Compare tabs.
//  "Latest" uses each country's most recent available year; a concrete year filters to
//  that exact year. Styled as a `ChipLabel` so it reads like the adjacent filter chips.
//

import SwiftUI

struct YearPicker: View {
    @ObservedObject var viewModel: IndicatorsViewModel
    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    private var label: String {
        if let year = viewModel.selectedYear { return "\(year)" }
        return "Latest"
    }

    var body: some View {
        Menu {
            Button {
                viewModel.selectedYear = nil
            } label: {
                Label("Latest", systemImage: viewModel.selectedYear == nil ? "checkmark" : "")
            }
            ForEach(viewModel.availableYears, id: \.self) { year in
                Button {
                    viewModel.selectedYear = year
                } label: {
                    if viewModel.selectedYear == year {
                        Label("\(year)", systemImage: "checkmark")
                    } else {
                        Text("\(year)")
                    }
                }
            }
        } label: {
            ChipLabel(label: label, icon: "calendar", isSelected: viewModel.selectedYear != nil)
        }
    }
}
