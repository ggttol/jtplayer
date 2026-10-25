# JTplayer

**English** · [简体中文](README.zh-CN.md)

<img src="App/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png" width="112" align="right" alt="JTplayer icon">

**A nostalgic, open-source iOS music player — a tribute to TTPlayer (千千静听), the classic Chinese desktop player of the 2000s.**

Remember the glossy main window, the karaoke-style "Lyrics Show" that colored each line as it was sung, and the equalizer and playlist snapped right underneath? JTplayer brings them to the iPhone, and it can load TTPlayer-format `.skn` skins. Play music straight from your NAS, media servers and network shares.

Give it a try! Issues, ideas and pull requests are all welcome.

<p>
  <img src="Docs/screenshots/main.png" width="200" alt="Main window, lyrics and playlist">
  <img src="Docs/screenshots/equalizer.png" width="200" alt="Equalizer and karaoke lyrics">
  <img src="Docs/screenshots/black.png" width="200" alt="Black skin">
  <img src="Docs/screenshots/pink.png" width="200" alt="Sakura skin">
</p>

## Features

**Classic windows**
- **Main window**: spectrum / oscilloscope (tap to switch), scrolling track info, bitrate and channels, LED time (tap for remaining time; blinks when paused), seek bar, volume and mute.
- **Five play modes**: play once, repeat one, in order, repeat all, shuffle. Tap the mode button to cycle.
- **Lyrics Show**: synced lyrics scroll line by line, and the current line fills with color from left to right, karaoke style. Tap a line to jump there; long-press to search online or import an `.lrc`.
- **Equalizer**: on/off, presets, reset, balance, surround, preamp and ten bands from 31 Hz to 16 kHz.
- **Playlist**: the original seven menus — Add, Delete, List, Sort, Find, Edit, Mode. Tap a song to play it; long-press to reorder, multi-select, view info or download for offline use.
- The LRC / EQ / PL buttons show and hide each window; windows snap below the main window. Mini mode keeps only the main window.

**Skins**
- Loads TTPlayer `.skn` skins (`Skin.xml` version="2"): bitmaps for the main, lyrics, equalizer and playlist windows, four-state buttons, sliders, LED digits, nine-slice stretching, and the colors in Lyric.xml, Playlist.xml and Visual.xml. GBK and UTF-8 are both supported.
- Windows missing from a skin fall back to the default skin.
- Five original built-in skins, all drawn in code: Jingting Blue, Black, Sakura, Jade and Silver.
- Open an `.skn` in the Files app to import it.

**Sound effects**
- One-tap effects on top of the equalizer: Bass Boost, Clear Vocals, 3D Surround, 8D Orbit, Concert, KTV, Studio, Vinyl, Lo-Fi, EDM and Night.
- Or fine-tune bass, vocals, treble, reverb, echo, surround, loudness, vinyl crackle, speed (pitch kept) and pitch (speed kept).

**Music sources**

| Source | Notes |
|---|---|
| On this iPhone | Files › JTplayer, or import from Files |
| WebDAV | Including Alist / OpenList (turns most cloud drives into WebDAV), Synology WebDAV Server, Nextcloud |
| SMB 2/3 | Windows shares and NAS devices |
| Subsonic / OpenSubsonic | Navidrome, Airsonic, Gonic, Ampache |
| Jellyfin / Emby | Libraries, albums, artists, folders |
| Synology DSM | IP, domain or QuickConnect ID; File Station for every shared folder, Audio Station for albums and playlists |
| UPnP / DLNA | The media server built into almost every NAS |

SMB, WebDAV and DLNA servers on the local network are discovered automatically.

**Playback**
- MP3, AAC/M4A, ALAC, FLAC, APE (built-in Monkey's Audio decoder), WAV, AIFF, CAF and Opus (in CAF).
- Gapless when the next track is cached and has the same format. Network tracks are cached before playback and can be downloaded for offline use.
- Background audio, Lock Screen and Control Center, headset controls, sleep timer, AirPlay / Bluetooth output.
- Lyrics come from a matching `.lrc` next to the song (UTF-8 or GBK), the server's lyrics API, embedded tags, or [LRCLIB](https://lrclib.net) as a fallback.
- When nothing is playing, the app is in the background or the visualizer is off, the UI stops redrawing and spectrum analysis stops; the audio engine sleeps after a short pause, so your phone stays cool.

## Building

1. A Mac with **Xcode 16 or later** and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`). The app supports iOS 17 and later.
2. Clone the repository and set your signing team:
   ```sh
   git clone https://github.com/ggttol/jtplayer.git && cd jtplayer
   cp Config/Signing.local.xcconfig.example Config/Signing.local.xcconfig   # set DEVELOPMENT_TEAM
   xcodegen generate
   open JTplayer.xcodeproj
   ```
3. Pick your iPhone or a simulator and press Run.

## Project layout

```
App/
  TT/                     TTPlayer-style windows: main, Lyrics Show, equalizer, playlist; skin controls and skin store
  Screens/                Sources, browser, library, sound effects, settings, side menu
Packages/AmplayerKit/     Playback core (shared with the sister project Amplayer)
  TTSkin                  .skn parsing and loading, stretchable window layout, built-in skin drawing
  AmplayerCore            Tracks, play queue, M3U/PLS, equalizer, LRC parsing
  AmplayerAudio           AVAudioEngine player, EQ and effects chain, spectrum, APE decoding, gapless playback
  AmplayerSources         Source protocols, Keychain, LAN discovery, online lyrics
  AmplayerCache           Download cache and offline files
  AmplayerKit             Playback controller, library, source management
UITests/                  XCUITest end-to-end tests
Tools/                    Test servers, UI test script, icon generator
```

## Tests

```sh
(cd Packages/AmplayerKit && swift test)    # unit tests (.skn parsing, built-in skins, offline-rendered effects)
Tools/ui-test.sh                           # UI tests in the simulator (starts a WebDAV test server in Docker)
```

## License

The code is released under the [MIT License](LICENSE). Third-party components keep their own licenses: the Monkey's Audio SDK is BSD, and AMSMB2 / libsmb2 are LGPL and linked dynamically. See [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md).

JTplayer is a fan tribute and is not affiliated with TTPlayer (千千静听) or Baidu; "千千静听" is a trademark of its owner. No original TTPlayer skins or assets are bundled: the built-in skins and the icon are original, and imported `.skn` skins belong to their authors.
