# Hotwire Native Implementation Plan

> This document outlines the plan for implementing native iOS and Android apps for PropertyWebBuilder using Hotwire Native (formerly Turbo Native).

## Overview

Hotwire Native allows us to wrap our existing Rails/Turbo application in native mobile shells, providing a native app experience while reusing 90%+ of our existing codebase.

### Why Hotwire Native?

- **Already using Turbo** - Our app is Turbo-enabled, making Hotwire Native a natural fit
- **Server-rendered HTML** - No need to build a separate API or SPA
- **Native navigation** - iOS/Android native transitions and navigation patterns
- **Incremental adoption** - Start with web views, add native screens as needed
- **Proven in production** - Powers Basecamp, HEY, and Cookpad apps

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Native Shell                          │
│  ┌─────────────────────────────────────────────────┐    │
│  │         Native Navigation (UIKit/Jetpack)        │    │
│  ├─────────────────────────────────────────────────┤    │
│  │                                                   │    │
│  │            Turbo-powered WebView                  │    │
│  │         (PropertyWebBuilder HTML)                 │    │
│  │                                                   │    │
│  ├─────────────────────────────────────────────────┤    │
│  │    Native Components (optional: maps, camera)    │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│              PropertyWebBuilder Rails App                │
│                  (existing codebase)                     │
└─────────────────────────────────────────────────────────┘
```

## Prerequisites

Before starting, ensure:

1. **Turbo is working correctly** - All navigation uses Turbo Drive
2. **Responsive design** - Views work well on mobile screen sizes
3. **Touch-friendly UI** - Buttons/links are adequately sized (44pt minimum)
4. **PWA foundation** - Service worker and manifest in place (optional but recommended)

## Implementation Phases

### Phase 0: Rails Preparation (1 week)

#### 0.1 Add Native App Detection

```ruby
# app/controllers/concerns/native_app_detection.rb
module NativeAppDetection
  extend ActiveSupport::Concern

  included do
    helper_method :native_app?
    helper_method :ios_app?
    helper_method :android_app?
  end

  def native_app?
    turbo_native_app?
  end

  def ios_app?
    request.user_agent&.include?("PropertyWebBuilder iOS")
  end

  def android_app?
    request.user_agent&.include?("PropertyWebBuilder Android")
  end
end
```

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include NativeAppDetection
end
```

#### 0.2 Create Path Configuration Endpoint

The native apps need to know how to handle different URL paths:

```ruby
# config/routes.rb
namespace :api do
  namespace :v1 do
    get 'path_configuration', to: 'path_configuration#show'
  end
end
```

```ruby
# app/controllers/api/v1/path_configuration_controller.rb
module Api
  module V1
    class PathConfigurationController < ApplicationController
      def show
        render json: {
          settings: {
            screenshots_enabled: true
          },
          rules: [
            {
              patterns: ["/"],
              properties: {
                presentation: "default"
              }
            },
            {
              patterns: ["/properties/*"],
              properties: {
                presentation: "default",
                pull_to_refresh_enabled: true
              }
            },
            {
              patterns: ["/search*"],
              properties: {
                presentation: "default",
                pull_to_refresh_enabled: true
              }
            },
            {
              patterns: ["/contact*"],
              properties: {
                presentation: "modal"
              }
            },
            {
              patterns: ["/site_admin*"],
              properties: {
                presentation: "default",
                requires_authentication: true
              }
            },
            {
              patterns: ["/users/sign_in", "/users/sign_up"],
              properties: {
                presentation: "modal",
                navigation: "none"
              }
            }
          ]
        }
      end
    end
  end
end
```

#### 0.3 Add Turbo Native Meta Tags

```erb
<%# app/views/layouts/application.html.erb %>
<head>
  <!-- Existing head content -->

  <%# Turbo Native hints %>
  <% if native_app? %>
    <meta name="turbo-cache-control" content="no-preview">
  <% end %>
</head>
```

#### 0.4 Handle Native-Specific Behaviors

```erb
<%# Hide web navigation in native app %>
<% unless native_app? %>
  <%= render 'shared/navbar' %>
<% end %>

<%# Or use CSS %>
<nav class="navbar turbo-native:hidden">
  <!-- navbar content -->
</nav>
```

```css
/* app/assets/stylesheets/native.css */
/* Hide elements in native app */
html.turbo-native .turbo-native\:hidden {
  display: none !important;
}

/* Show elements only in native app */
html:not(.turbo-native) .turbo-native\:block {
  display: none !important;
}
```

### Phase 1: iOS App (2-3 weeks)

#### 1.1 Project Setup

```bash
# Create new Xcode project
# Select: App template
# Interface: Storyboard
# Language: Swift
# Bundle ID: com.yourcompany.propertywebbuilder
```

#### 1.2 Add Hotwire Native Dependency

```swift
// Package.swift dependencies or via Xcode SPM
// Add: https://github.com/hotwired/hotwire-native-ios
```

#### 1.3 Basic Implementation

```swift
// SceneDelegate.swift
import UIKit
import HotwireNative

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    private let navigator = Navigator()

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = navigator.rootViewController
        window?.makeKeyAndVisible()

        // Configure path rules
        Hotwire.loadPathConfiguration(from: [
            .server(URL(string: "https://yourapp.com/api/v1/path_configuration")!)
        ])

        // Set custom user agent
        Hotwire.config.userAgent = "PropertyWebBuilder iOS/1.0"

        // Navigate to start URL
        navigator.route(URL(string: "https://yourapp.com")!)
    }
}
```

```swift
// Navigator.swift
import HotwireNative
import UIKit

class Navigator: HotwireNavigator {

    override func handle(proposal: VisitProposal) -> VisitProposalResult {
        // Handle special paths with native screens
        switch proposal.url.path {
        case "/native/photo_upload":
            return .acceptCustom(PhotoUploadViewController())
        case "/native/map":
            return .acceptCustom(NativeMapViewController())
        default:
            return .accept
        }
    }

    override func visitableDidFailRequest(_ visitable: Visitable, error: Error) {
        // Handle errors (show offline screen, retry, etc.)
        if isOfflineError(error) {
            showOfflineScreen()
        } else {
            super.visitableDidFailRequest(visitable, error: error)
        }
    }
}
```

#### 1.4 Handle Authentication

```swift
// AuthenticationController.swift
import HotwireNative
import WebKit

class AuthenticationController {

    func clearSession() {
        // Clear cookies
        HTTPCookieStorage.shared.cookies?.forEach {
            HTTPCookieStorage.shared.deleteCookie($0)
        }

        // Clear WebView data
        WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: Date(timeIntervalSince1970: 0)
        ) { }
    }

    func handleAuthenticationRequired(url: URL) {
        // Present login modal
        let loginURL = URL(string: "https://yourapp.com/users/sign_in")!
        navigator.route(loginURL, options: .modal)
    }
}
```

#### 1.5 Native Features (Optional)

```swift
// NativeMapViewController.swift
import MapKit
import HotwireNative

class NativeMapViewController: UIViewController {
    private let mapView = MKMapView()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupMapView()
        loadPropertyMarkers()
    }

    private func loadPropertyMarkers() {
        // Fetch properties from API and add markers
    }
}
```

```swift
// PhotoUploadViewController.swift
import UIKit
import PhotosUI

class PhotoUploadViewController: UIViewController, PHPickerViewControllerDelegate {

    func presentPhotoPicker() {
        var config = PHPickerConfiguration()
        config.selectionLimit = 10
        config.filter = .images

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        // Handle selected photos, upload to Rails app
    }
}
```

#### 1.6 Push Notifications

```swift
// AppDelegate.swift
import UserNotifications

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        registerForPushNotifications()
        return true
    }

    func registerForPushNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        // Send token to Rails backend
        sendTokenToServer(token: token, platform: "ios")
    }
}
```

### Phase 2: Android App (2-3 weeks)

#### 2.1 Project Setup

```bash
# Create new Android Studio project
# Select: Empty Activity
# Language: Kotlin
# Minimum SDK: API 24 (Android 7.0)
# Package: com.yourcompany.propertywebbuilder
```

#### 2.2 Add Hotwire Native Dependency

```kotlin
// build.gradle.kts (app level)
dependencies {
    implementation("dev.hotwire:hotwire-native-android:1.0.0")
}
```

#### 2.3 Basic Implementation

```kotlin
// MainApplication.kt
package com.yourcompany.propertywebbuilder

import android.app.Application
import dev.hotwire.core.config.Hotwire

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        Hotwire.loadPathConfiguration(
            context = this,
            location = PathConfiguration.Location(
                remoteFileUrl = "https://yourapp.com/api/v1/path_configuration"
            )
        )

        Hotwire.config.userAgent = "PropertyWebBuilder Android/1.0"
    }
}
```

```kotlin
// MainActivity.kt
package com.yourcompany.propertywebbuilder

import dev.hotwire.core.turbo.activities.HotwireActivity
import dev.hotwire.core.turbo.nav.HotwireNavGraphBuilder

class MainActivity : HotwireActivity() {

    override val startLocation = "https://yourapp.com"

    override val navHostFragmentId = R.id.nav_host_fragment

    override fun buildNavGraph(): HotwireNavGraphBuilder {
        return HotwireNavGraphBuilder(
            startLocation = startLocation,
            navHostFragmentId = navHostFragmentId
        ).apply {
            // Register native fragments for specific paths
            registerFragment("/native/photo_upload") { PhotoUploadFragment() }
            registerFragment("/native/map") { NativeMapFragment() }
        }
    }
}
```

```xml
<!-- res/layout/activity_main.xml -->
<?xml version="1.0" encoding="utf-8"?>
<androidx.fragment.app.FragmentContainerView
    xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/nav_host_fragment"
    android:layout_width="match_parent"
    android:layout_height="match_parent" />
```

#### 2.4 Web Fragment

```kotlin
// WebFragment.kt
package com.yourcompany.propertywebbuilder

import dev.hotwire.core.turbo.fragments.HotwireWebFragment
import dev.hotwire.core.turbo.errors.VisitError

class WebFragment : HotwireWebFragment() {

    override fun onVisitErrorReceived(error: VisitError) {
        when {
            error.isNetworkError -> showOfflineScreen()
            error.isHttpError(401) -> navigateToLogin()
            else -> super.onVisitErrorReceived(error)
        }
    }

    private fun showOfflineScreen() {
        // Show cached content or offline message
    }

    private fun navigateToLogin() {
        navigate("https://yourapp.com/users/sign_in")
    }
}
```

#### 2.5 Native Features (Optional)

```kotlin
// NativeMapFragment.kt
package com.yourcompany.propertywebbuilder

import com.google.android.gms.maps.GoogleMap
import com.google.android.gms.maps.SupportMapFragment

class NativeMapFragment : SupportMapFragment(), OnMapReadyCallback {

    override fun onMapReady(googleMap: GoogleMap) {
        // Load property markers
        loadPropertyMarkers(googleMap)
    }

    private fun loadPropertyMarkers(map: GoogleMap) {
        // Fetch from API and add markers
    }
}
```

```kotlin
// PhotoUploadFragment.kt
package com.yourcompany.propertywebbuilder

import androidx.activity.result.contract.ActivityResultContracts
import androidx.fragment.app.Fragment

class PhotoUploadFragment : Fragment() {

    private val pickImages = registerForActivityResult(
        ActivityResultContracts.GetMultipleContents()
    ) { uris ->
        uris?.let { uploadPhotos(it) }
    }

    fun selectPhotos() {
        pickImages.launch("image/*")
    }

    private fun uploadPhotos(uris: List<Uri>) {
        // Upload to Rails backend
    }
}
```

#### 2.6 Push Notifications

```kotlin
// FirebaseMessagingService.kt
package com.yourcompany.propertywebbuilder

import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class PropertyMessagingService : FirebaseMessagingService() {

    override fun onNewToken(token: String) {
        // Send token to Rails backend
        sendTokenToServer(token, "android")
    }

    override fun onMessageReceived(message: RemoteMessage) {
        message.notification?.let {
            showNotification(it.title, it.body)
        }
    }
}
```

### Phase 3: Rails Backend for Push Notifications (1 week)

#### 3.1 Device Token Model

```bash
rails generate model DeviceToken user:references platform:string token:string:index
```

```ruby
# app/models/device_token.rb
class DeviceToken < ApplicationRecord
  belongs_to :user

  validates :token, presence: true, uniqueness: { scope: :platform }
  validates :platform, inclusion: { in: %w[ios android web] }

  scope :ios, -> { where(platform: 'ios') }
  scope :android, -> { where(platform: 'android') }
end
```

#### 3.2 API Endpoint for Token Registration

```ruby
# app/controllers/api/v1/device_tokens_controller.rb
module Api
  module V1
    class DeviceTokensController < ApplicationController
      before_action :authenticate_user!

      def create
        token = current_user.device_tokens.find_or_initialize_by(
          platform: params[:platform]
        )
        token.token = params[:token]

        if token.save
          render json: { status: 'registered' }
        else
          render json: { errors: token.errors }, status: :unprocessable_entity
        end
      end

      def destroy
        current_user.device_tokens.where(token: params[:token]).destroy_all
        render json: { status: 'unregistered' }
      end
    end
  end
end
```

#### 3.3 Push Notification Service

```ruby
# app/services/push_notification_service.rb
class PushNotificationService
  def self.send_to_user(user:, title:, body:, data: {})
    user.device_tokens.find_each do |token|
      case token.platform
      when 'ios'
        send_ios_notification(token.token, title, body, data)
      when 'android'
        send_android_notification(token.token, title, body, data)
      end
    end
  end

  private

  def self.send_ios_notification(token, title, body, data)
    # Use APNs gem (e.g., apnotic, houston)
    notification = Apnotic::Notification.new(token)
    notification.alert = { title: title, body: body }
    notification.custom_payload = data
    apns_connection.push(notification)
  end

  def self.send_android_notification(token, title, body, data)
    # Use FCM gem (e.g., fcm, firebase-admin-sdk)
    fcm = FCM.new(Rails.application.credentials.fcm_server_key)
    fcm.send(token, notification: { title: title, body: body }, data: data)
  end
end
```

#### 3.4 Trigger Notifications

```ruby
# Example: Notify when new inquiry received
class Pwb::EnquiryMailer < ApplicationMailer
  after_action :send_push_notification, only: [:general_enquiry_targeting_agency]

  private

  def send_push_notification
    return unless @enquiry.website.users.any?

    @enquiry.website.users.each do |user|
      PushNotificationService.send_to_user(
        user: user,
        title: "New Inquiry",
        body: "#{@contact.first_name} is interested in your properties",
        data: { url: "/site_admin/messages/#{@enquiry.id}" }
      )
    end
  end
end
```

## File Structure

```
ios-app/
├── PropertyWebBuilder.xcodeproj
├── PropertyWebBuilder/
│   ├── AppDelegate.swift
│   ├── SceneDelegate.swift
│   ├── Navigator.swift
│   ├── Controllers/
│   │   ├── PhotoUploadViewController.swift
│   │   └── NativeMapViewController.swift
│   └── Services/
│       ├── AuthenticationController.swift
│       └── PushNotificationService.swift
└── Podfile (or use SPM)

android-app/
├── app/
│   ├── src/main/
│   │   ├── java/com/yourcompany/propertywebbuilder/
│   │   │   ├── MainApplication.kt
│   │   │   ├── MainActivity.kt
│   │   │   ├── WebFragment.kt
│   │   │   ├── PhotoUploadFragment.kt
│   │   │   ├── NativeMapFragment.kt
│   │   │   └── PropertyMessagingService.kt
│   │   └── res/
│   │       └── layout/
│   │           └── activity_main.xml
│   └── build.gradle.kts
└── build.gradle.kts
```

## Timeline Summary

| Phase | Duration | Deliverable |
|-------|----------|-------------|
| Phase 0: Rails Preparation | 1 week | Path config, native detection, meta tags |
| Phase 1: iOS App | 2-3 weeks | Basic iOS app with native navigation |
| Phase 2: Android App | 2-3 weeks | Basic Android app with native navigation |
| Phase 3: Push Notifications | 1 week | Backend + mobile push support |
| **Total** | **6-8 weeks** | Full native apps for iOS and Android |

## Native Screens to Consider

Build these as fully native for best UX:

1. **Photo Upload** - Native camera/gallery picker with bulk upload
2. **Property Map** - Native MapKit/Google Maps with clustering
3. **Search Filters** - Native bottom sheet with range sliders
4. **Push Settings** - Native preferences screen
5. **Offline Property Viewer** - Cached property details

## Testing Checklist

- [ ] Deep links work from external sources
- [ ] Authentication persists across sessions
- [ ] Pull-to-refresh works on list pages
- [ ] Back button navigation is correct
- [ ] Modal presentation/dismissal works
- [ ] Push notifications open correct screens
- [ ] Offline mode shows cached content
- [ ] Camera/photo access works
- [ ] Location permissions handled correctly
- [ ] App Store/Play Store screenshots captured

## Resources

- [Hotwire Native iOS](https://github.com/hotwired/hotwire-native-ios)
- [Hotwire Native Android](https://github.com/hotwired/hotwire-native-android)
- [Hotwire Native Documentation](https://hotwired.dev/native)
- [37signals Mobile Guide](https://dev.37signals.com/native/)
- [HEY iOS App Architecture](https://world.hey.com/dhh/the-hey-app-is-now-open-source-7d6b4c79)

## Multi-Tenant White-Label Apps

PropertyWebBuilder is a multi-tenant platform where each website needs its own branded mobile app. This section covers the architecture for provisioning white-label apps.

### Architecture Options

#### Option 1: Single App with Runtime Configuration (Recommended for MVP)

Build one app that detects the website at runtime:

```swift
// iOS: SceneDelegate.swift
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        // Get website URL from:
        // 1. Deep link / Universal link
        // 2. Previously stored preference
        // 3. Prompt user to enter their agency domain

        let websiteURL = loadWebsiteURL()

        Hotwire.loadPathConfiguration(from: [
            .server(URL(string: "\(websiteURL)/api/v1/path_configuration")!)
        ])

        navigator.route(URL(string: websiteURL)!)
    }

    private func loadWebsiteURL() -> String {
        // Check saved preference first
        if let saved = UserDefaults.standard.string(forKey: "website_url") {
            return saved
        }

        // Otherwise prompt user (handled by onboarding flow)
        return "https://app.propertywebbuilder.com" // Default/directory
    }
}
```

**Pros:**
- Single app to maintain
- Users can switch between agencies
- Simpler App Store approval

**Cons:**
- Generic branding (PropertyWebBuilder icon/name)
- Less professional for individual agencies

#### Option 2: Build-Time Branded Apps (Recommended for Production)

Generate unique apps per website with custom branding:

```
┌─────────────────────────────────────────────────────────────┐
│                PropertyWebBuilder Platform                   │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│   Website Admin Panel                                        │
│   ┌──────────────────────────────────────────────────────┐  │
│   │  Mobile App Settings                                  │  │
│   │  ├─ App Name: "Smith Realty"                         │  │
│   │  ├─ Bundle ID: com.smithrealty.app                   │  │
│   │  ├─ App Icon: [Upload]                               │  │
│   │  ├─ Splash Screen: [Upload]                          │  │
│   │  ├─ Primary Color: #2563EB                           │  │
│   │  └─ [Generate iOS App] [Generate Android App]        │  │
│   └──────────────────────────────────────────────────────┘  │
│                           │                                  │
│                           ▼                                  │
│   ┌──────────────────────────────────────────────────────┐  │
│   │            App Build Pipeline (CI/CD)                 │  │
│   │  ┌────────────┐  ┌────────────┐  ┌────────────┐     │  │
│   │  │ Template   │─▶│ Customize  │─▶│   Build    │     │  │
│   │  │   App      │  │  Assets    │  │  & Sign    │     │  │
│   │  └────────────┘  └────────────┘  └────────────┘     │  │
│   └──────────────────────────────────────────────────────┘  │
│                           │                                  │
│                           ▼                                  │
│   ┌──────────────────────────────────────────────────────┐  │
│   │              Distribution                             │  │
│   │  ├─ Download IPA for TestFlight / App Store          │  │
│   │  ├─ Download APK for Play Store                      │  │
│   │  └─ Or: Use Managed App Distribution (Enterprise)    │  │
│   └──────────────────────────────────────────────────────┘  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Database Schema for App Configuration

```ruby
# db/migrate/xxx_create_mobile_app_configs.rb
class CreateMobileAppConfigs < ActiveRecord::Migration[8.0]
  def change
    create_table :pwb_mobile_app_configs do |t|
      t.references :website, null: false, foreign_key: { to_table: :pwb_websites }

      # App Identity
      t.string :app_name, null: false
      t.string :ios_bundle_id
      t.string :android_package_name

      # Branding
      t.string :primary_color, default: '#2563EB'
      t.string :secondary_color

      # Build Status
      t.string :ios_build_status, default: 'not_started'
      t.string :android_build_status, default: 'not_started'
      t.datetime :ios_last_built_at
      t.datetime :android_last_built_at
      t.string :ios_version
      t.string :android_version

      # Push Notification Credentials
      t.text :apns_key_encrypted
      t.string :apns_key_id
      t.string :apns_team_id
      t.text :fcm_credentials_encrypted

      t.timestamps
    end
  end
end
```

```ruby
# app/models/pwb/mobile_app_config.rb
module Pwb
  class MobileAppConfig < ApplicationRecord
    belongs_to :website

    has_one_attached :app_icon          # 1024x1024 PNG
    has_one_attached :splash_image      # Various sizes needed
    has_one_attached :ios_provisioning_profile
    has_one_attached :ios_signing_certificate

    validates :app_name, presence: true, length: { maximum: 30 }
    validates :ios_bundle_id, format: { with: /\Acom\.[a-z0-9]+\.[a-z0-9]+\z/i }, allow_blank: true
    validates :android_package_name, format: { with: /\Acom\.[a-z0-9]+\.[a-z0-9]+\z/i }, allow_blank: true

    encrypts :apns_key_encrypted
    encrypts :fcm_credentials_encrypted

    def base_url
      website.primary_domain || "#{website.subdomain}.propertywebbuilder.com"
    end
  end
end
```

### Build Pipeline with Fastlane

```ruby
# fastlane/Fastfile (Template for iOS)
default_platform(:ios)

platform :ios do
  desc "Build white-label app for a specific website"
  lane :build_whitelabel do |options|
    website_id = options[:website_id]
    config = fetch_app_config(website_id)

    # Update bundle identifier
    update_app_identifier(
      xcodeproj: "PropertyWebBuilder.xcodeproj",
      plist_path: "PropertyWebBuilder/Info.plist",
      app_identifier: config[:bundle_id]
    )

    # Update app name
    update_info_plist(
      xcodeproj: "PropertyWebBuilder.xcodeproj",
      plist_path: "PropertyWebBuilder/Info.plist",
      display_name: config[:app_name]
    )

    # Replace app icon
    copy_app_icon(config[:app_icon_path])

    # Inject website URL
    update_info_plist(
      xcodeproj: "PropertyWebBuilder.xcodeproj",
      plist_path: "PropertyWebBuilder/Info.plist",
      block: proc do |plist|
        plist["PWBWebsiteURL"] = config[:website_url]
        plist["PWBWebsiteID"] = website_id
      end
    )

    # Build
    build_ios_app(
      scheme: "PropertyWebBuilder",
      export_method: "app-store",
      output_directory: "./builds/#{website_id}"
    )
  end
end
```

### Rails Admin Interface for App Provisioning

```ruby
# app/controllers/site_admin/mobile_app_controller.rb
module SiteAdmin
  class MobileAppController < SiteAdminController
    def show
      @config = current_website.mobile_app_config || current_website.build_mobile_app_config
    end

    def update
      @config = current_website.mobile_app_config || current_website.build_mobile_app_config

      if @config.update(mobile_app_params)
        redirect_to site_admin_mobile_app_path, notice: "App configuration saved"
      else
        render :show
      end
    end

    def request_build
      @config = current_website.mobile_app_config

      # Queue build job
      MobileAppBuildJob.perform_later(
        website_id: current_website.id,
        platform: params[:platform]
      )

      redirect_to site_admin_mobile_app_path,
                  notice: "Build requested. You'll receive an email when it's ready."
    end

    private

    def mobile_app_params
      params.require(:mobile_app_config).permit(
        :app_name, :ios_bundle_id, :android_package_name,
        :primary_color, :secondary_color, :app_icon, :splash_image
      )
    end
  end
end
```

```erb
<%# app/views/site_admin/mobile_app/show.html.erb %>
<div class="max-w-4xl mx-auto py-8">
  <h1 class="text-2xl font-bold mb-8">Mobile App Settings</h1>

  <%= form_with model: @config, url: site_admin_mobile_app_path, class: "space-y-6" do |f| %>
    <div class="bg-white shadow rounded-lg p-6">
      <h2 class="text-lg font-semibold mb-4">App Identity</h2>

      <div class="grid grid-cols-2 gap-6">
        <div>
          <%= f.label :app_name, class: "block text-sm font-medium text-gray-700" %>
          <%= f.text_field :app_name, class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm" %>
          <p class="mt-1 text-sm text-gray-500">The name shown under your app icon</p>
        </div>

        <div>
          <%= f.label :app_icon, class: "block text-sm font-medium text-gray-700" %>
          <%= f.file_field :app_icon, accept: "image/png", class: "mt-1" %>
          <p class="mt-1 text-sm text-gray-500">1024x1024 PNG, no transparency</p>
        </div>
      </div>
    </div>

    <div class="bg-white shadow rounded-lg p-6">
      <h2 class="text-lg font-semibold mb-4">Branding</h2>

      <div class="grid grid-cols-2 gap-6">
        <div>
          <%= f.label :primary_color, class: "block text-sm font-medium text-gray-700" %>
          <%= f.color_field :primary_color, class: "mt-1 h-10 w-20" %>
        </div>

        <div>
          <%= f.label :splash_image, class: "block text-sm font-medium text-gray-700" %>
          <%= f.file_field :splash_image, accept: "image/png", class: "mt-1" %>
        </div>
      </div>
    </div>

    <div class="bg-white shadow rounded-lg p-6">
      <h2 class="text-lg font-semibold mb-4">Build Status</h2>

      <div class="grid grid-cols-2 gap-6">
        <div>
          <h3 class="font-medium">iOS App</h3>
          <p class="text-sm text-gray-500">Status: <%= @config.ios_build_status %></p>
          <% if @config.ios_last_built_at %>
            <p class="text-sm text-gray-500">Last built: <%= @config.ios_last_built_at.strftime('%B %d, %Y') %></p>
          <% end %>
          <%= button_to "Build iOS App", request_build_site_admin_mobile_app_path(platform: 'ios'),
                        class: "mt-2 bg-blue-600 text-white px-4 py-2 rounded" %>
        </div>

        <div>
          <h3 class="font-medium">Android App</h3>
          <p class="text-sm text-gray-500">Status: <%= @config.android_build_status %></p>
          <% if @config.android_last_built_at %>
            <p class="text-sm text-gray-500">Last built: <%= @config.android_last_built_at.strftime('%B %d, %Y') %></p>
          <% end %>
          <%= button_to "Build Android App", request_build_site_admin_mobile_app_path(platform: 'android'),
                        class: "mt-2 bg-green-600 text-white px-4 py-2 rounded" %>
        </div>
      </div>
    </div>

    <%= f.submit "Save Configuration", class: "bg-blue-600 text-white px-6 py-3 rounded font-medium" %>
  <% end %>
</div>
```

### iOS App Template with Website Injection

```swift
// AppConfig.swift
import Foundation

struct AppConfig {
    // These are replaced at build time by Fastlane
    static let websiteURL: String = {
        if let url = Bundle.main.object(forInfoDictionaryKey: "PWBWebsiteURL") as? String {
            return url
        }
        return "https://app.propertywebbuilder.com"
    }()

    static let websiteID: String = {
        if let id = Bundle.main.object(forInfoDictionaryKey: "PWBWebsiteID") as? String {
            return id
        }
        return ""
    }()

    static let primaryColor: UIColor = {
        // Loaded from remote config or bundled defaults
        return UIColor(hex: "#2563EB")
    }()
}

// SceneDelegate.swift
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = navigator.rootViewController
        window?.makeKeyAndVisible()

        // Use injected website URL
        let baseURL = AppConfig.websiteURL

        Hotwire.loadPathConfiguration(from: [
            .server(URL(string: "\(baseURL)/api/v1/path_configuration")!)
        ])

        Hotwire.config.userAgent = "PropertyWebBuilder iOS/\(AppConfig.websiteID)"

        navigator.route(URL(string: baseURL)!)
    }
}
```

### Third-Party Services for App Building

Instead of building your own infrastructure, consider:

1. **[Expo Application Services (EAS)](https://expo.dev/eas)** - React Native focused but supports generic builds
2. **[Bitrise](https://bitrise.io)** - CI/CD with iOS/Android build support
3. **[Codemagic](https://codemagic.io)** - Flutter/native app building
4. **[App Center](https://appcenter.ms)** - Microsoft's build/distribution service
5. **[Fastlane + GitHub Actions](https://docs.github.com/en/actions)** - Self-hosted pipeline

### Cost Considerations

| Approach | Setup Cost | Per-App Cost | Maintenance |
|----------|------------|--------------|-------------|
| Single generic app | $1,000-3,000 | $0 | Low |
| Manual white-label | $1,000-3,000 | $500-1,000/app | Medium |
| Automated pipeline | $5,000-10,000 | $50-100/app | High |
| Third-party service | $0 | $99-499/month | Low |

### App Store Considerations

**Apple App Store:**
- Each app needs unique Bundle ID
- Developer account: $99/year
- Can use single account for multiple apps
- Review takes 1-7 days
- 4.2+ rating or risk being hidden

**Google Play Store:**
- Each app needs unique package name
- Developer account: $25 one-time
- Can use single account for multiple apps
- Review typically faster (hours to 2 days)

**Enterprise Distribution (Bypass App Stores):**
- Apple Enterprise Program: $299/year
- Requires business DUNS number
- Can distribute directly to users
- Useful for internal/B2B apps

### Recommended Phased Approach

1. **Phase 1 (MVP)**: Single app with website selector
   - Users enter their agency domain on first launch
   - Generic "PropertyWebBuilder" branding
   - Time: 2-3 weeks

2. **Phase 2 (Beta)**: Manual white-label builds
   - Premium feature for paying customers
   - Build each app manually with Fastlane
   - Time: 1-2 days per app

3. **Phase 3 (Scale)**: Automated build pipeline
   - Self-service app generation from admin panel
   - CI/CD builds triggered automatically
   - Time: 4-6 weeks to build infrastructure

## Notes

- Start with web-only views, add native screens incrementally
- Test on real devices early and often
- Consider hiring iOS/Android contractors for initial setup
- App Store review can take 1-7 days; plan accordingly
- Keep native code minimal to reduce maintenance burden
