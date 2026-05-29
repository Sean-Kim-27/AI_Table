//
//  ContentView.swift
//  AI Table
//
//  Created by SeanKim on 3/19/26.
//

import SwiftUI

// 실제 UI 화면
struct ContentView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.black.opacity(0.8))
            
            VStack {
                Text("AI Table")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("여기에 API 버튼을 추가해 주세요")
                    .foregroundColor(.gray)
                Text("단축키(Option+Space)를 누르면 창이 표시되거나 숨겨집니다")
                    .font(.caption)
                    .foregroundColor(.yellow)
                    .padding(.top, 10)
            }
        }
        .frame(width: 350, height: 500)
    }
}
