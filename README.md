# 🎬 goStream — IMDb Movie Streaming App

A clean, fast, and ad-free Flutter app to stream movies via IMDb & vidsrc.  
No login required. No redirections. Just search and stream. ✨

## 📥 Download

[Download Latest goStream APK](https://github.com/Harish-Srinivas-07/goStream/releases/download/v1.0.4/goStream-arm64-v8a-release.apk)

> Built for arm64-v8a Android devices. Make sure to allow unknown sources when installing.


## ✨ Features

- 🔍 Search movies by **IMDb name or ID**
  - e.g. `inception`, `tt4154796`, or `https://www.imdb.com/title/tt1375666/`
- 📺 Watch instantly using `vidsrc.xyz` in an embedded WebView or open in browser
- ❤️ Mark favorites — view them anytime (no login needed)
- 🕘 See your recently watched movies
- 🌓 Toggle **Dark / Light theme** from Settings
- 🗑️ Clear cache and preferences with a tap
- ✅ No ads, no account, no redirections
- 🌈 Material You + Dynamic Theming supported
- 🧠 Smart fallback: If the IMDb ID is detected in input, it auto-redirects to player


## ⚙️ Settings

- Toggle **Dark Mode**
- **Clear Cache & Preferences**  
- View **App Info** (version, package name, install/update time)


## 🚀 Getting Started

### Prerequisites

- Flutter SDK installed
- Android or iOS device/emulator

### Run the app

```bash
git clone https://github.com/Harish-Srinivas-07/goStream.git
cd goStream
flutter pub get
flutter run
````


## 📦 Packages Used

* [`webview_flutter`](https://pub.dev/packages/webview_flutter)
* [`shared_preferences`](https://pub.dev/packages/shared_preferences)
* [`google_fonts`](https://pub.dev/packages/google_fonts)
* [`dynamic_color`](https://pub.dev/packages/dynamic_color)
* [`package_info_plus`](https://pub.dev/packages/package_info_plus)
* [`shimmer`](https://pub.dev/packages/shimmer)
* [`page_transition`](https://pub.dev/packages/page_transition)
* [`url_launcher`](https://pub.dev/packages/url_launcher)


## 💡 Example Inputs

Search bar accepts:

* Movie title: `Inception`, `The Matrix`, `Avengers`
* IMDb ID: `tt0133093`, `tt4154796`
* IMDb URL: `https://www.imdb.com/title/tt1375666/`

---

## ⚠️ Disclaimer

> **Note:** This app is a simple experimental demonstration using IMDb web scraping and the vidsrc streaming endpoint.
> It explores non-protected content delivery mechanisms purely for educational purposes.
> I do not own or host any of the content shown by IMDb or vidsrc. I'm only the developer showcasing a proof-of-concept.

⭐ Star this repo if you found it useful!

Happy streaming! 🍿

