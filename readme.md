# Elsewhere

[![Swift](https://img.shields.io/badge/Swift-F54A2A?logo=swift&logoColor=white)](#) [![macOS](https://img.shields.io/badge/macOS-000000?logo=apple&logoColor=F0F0F0)](#)

A native menubar app to track friends, teammates or city time zones on macOS.

Elsewhere is a maintained fork of [There](https://github.com/dena-sohrabi/There) by Dena Sohrabi, which is no longer updated. It includes fixes for entry saving, time zone handling, sorting and photo cleanup, and removes analytics and the remote signup.

## Install

```
brew install --cask 1stevengrant/tap/elsewhere
```

If Homebrew says the tap is untrusted, run `brew trust 1stevengrant/tap` and try again.

Or download the latest zip from [Releases](https://github.com/1stevengrant/Elsewhere/releases), unzip it and move Elsewhere to Applications.

To build from source, open `Elsewhere.xcodeproj` in Xcode 16 or later and run the Elsewhere scheme.

## Features

- Add photos for people from X (Twitter), Telegram or pick locally (X and Telegram photos are fetched through [unavatar.io](https://unavatar.io), which receives the username)
- Add any city without knowing the time zone
- Supports raw UTC offsets
- 0 to 1% idle CPU usage
- Ultra low memory
- Written in SwiftUI
- macOS 13+

## Moving from There

Elsewhere is a separate app with its own storage, so it starts empty. To bring your entries and photos across, open the settings menu, choose Import from There, and confirm the folder it suggests. Your entries in There are not changed.

## Roadmap

- [ ] Widgets
- [ ] Time slider to view future or past times
- [ ] Auto update
- [ ] AppleScript API for third party integrations such as Raycast

## Contributions

Contributions are welcome. For simple fixes, open a PR with the smallest change. For features or user facing changes, open an issue first to discuss the proposal.

## License

Licensed under the [MIT License](LICENSE). Original work copyright (c) 2024 Dena Sohrabi.
