# Ahoy Money App

Ahoy Money App is a native SwiftUI iOS wallet experience for digital money management. The app focuses on a polished consumer banking flow with onboarding, identity verification, wallet balance, top-ups, transfers, virtual cards, beneficiaries, transaction history, settings, and support screens.

The interface is built for iOS 26 with a dark financial UI, native SwiftUI navigation, SF Symbols, biometric-ready security flows, and Liquid Glass treatments across key wallet surfaces.

## Features

- Onboarding, registration, login, OTP verification, password creation, and password reset flows
- Wallet setup with Emirates ID front/back capture, selfie capture, verification states, and wallet-created confirmation
- Home wallet dashboard with balance, quick top-up access, virtual card entry point, recent activity, and search
- Top-up flow with preset amounts, custom amount entry, payment method selection, and wallet balance context
- Transfers section with beneficiaries, beneficiary details, OTP confirmation, success states, and edit flows
- Virtual card flows for card listing, card creation, card detail, card terms, and card success states
- Transactions screen for wallet activity review
- Settings area with profile details, language selection, security controls, notification preferences, transfer limits, and account update sheets
- Help center with categories, article detail pages, and search
- iOS 26 visual system using SwiftUI, SF Symbols, native tab navigation, and Liquid Glass components

## Requirements

- Xcode 26 or newer
- iOS 26 simulator or device

## Open

Open `Ahoy Money App.xcodeproj` in Xcode and run the `AhoyMoney` scheme.

## Project Structure

- `AhoyMoney/Views`: SwiftUI screens, sheets, and reusable visual flows
- `AhoyMoney/Models`: wallet, card, beneficiary, and help article models
- `AhoyMoney/Helpers`: biometric auth, country data, image picking, and scroll edge helpers
- `AhoyMoney/Theme`: shared colors and design tokens
- `AhoyMoney/Assets.xcassets`: app icon, card artwork, identity assets, onboarding imagery, and UI images
