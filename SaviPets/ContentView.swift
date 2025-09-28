//
//  ContentView.swift
//  SaviPets
//
//  Created by K!MO on 9/21/25.
//

import SwiftUI
import SwiftData

@available(iOS 17.0, *)
struct ContentView: View {
	@Environment(\.modelContext) private var modelContext
	var body: some View {
		Text("SaviPets")
			.font(SPDesignSystem.Typography.brandMedium())
			.padding()
	}
}
