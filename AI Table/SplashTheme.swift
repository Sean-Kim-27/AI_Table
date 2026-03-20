//
//  SplashTheme.swift
//  AIDock
//

import SwiftUI
import AppKit
import Splash

// Splash 공식 테마 구성
let aidockDarkSplashTheme = Splash.Theme(
    font: Splash.Font(size: 13),
    plainTextColor: Splash.Color(white: 0.9, alpha: 1.0),
    tokenColors: [
        .keyword: Splash.Color(red: 0.94, green: 0.35, blue: 0.47, alpha: 1.0),
        .string: Splash.Color(red: 0.89, green: 0.78, blue: 0.44, alpha: 1.0),
        .number: Splash.Color(red: 0.38, green: 0.69, blue: 0.94, alpha: 1.0),
        .type: Splash.Color(red: 0.42, green: 0.82, blue: 0.76, alpha: 1.0),
        .call: Splash.Color(red: 0.64, green: 0.84, blue: 0.47, alpha: 1.0),
        .property: Splash.Color(red: 0.64, green: 0.84, blue: 0.47, alpha: 1.0),
        .comment: Splash.Color(red: 0.53, green: 0.53, blue: 0.53, alpha: 1.0),
        .preprocessing: Splash.Color(red: 0.96, green: 0.61, blue: 0.34, alpha: 1.0)
    ]
)
