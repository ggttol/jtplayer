# 第三方许可

## Webamp — MIT
https://github.com/captbaritone/webamp — Copyright (c) 2015 Jordan Eldredge

`Packages/AmplayerKit/Sources/AmplayerSkin/SkinSprites.swift` 中的精灵图坐标、控件位置与字体映射移植自 Webamp。

> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## AMSMB2 / libsmb2 — LGPL-2.1
- https://github.com/amosavian/AMSMB2 — Copyright (c) Amir Abbas Mousavian
- https://github.com/sahlberg/libsmb2 — Copyright (c) Ronnie Sahlberg

AMSMB2 的 SwiftPM 产品声明为 `type: .dynamic`，以 `AMSMB2.framework` 动态库形式嵌入 App，用户可以替换该框架，满足 LGPL-2.1 第 6 节的要求。未修改其源码。

## Monkey's Audio SDK 13.43 — BSD-3-Clause
https://monkeysaudio.com — Copyright 2000-2026 Matthew T. Ashland

`Packages/AmplayerKit/Sources/MonkeysAudio/vendor/` 是 SDK 中解码所需的源码，未修改；完整许可见该目录下的 `License.txt`。Monkey's Audio 自 10.18 版（2023-08）起改为 3-Clause BSD。

## swift-atomics — Apache-2.0
https://github.com/apple/swift-atomics — Copyright (c) Apple Inc.（AMSMB2 的依赖）

## 内置皮肤与图标
JTplayer 的 5 套内置皮肤（静听蓝、炫酷黑、樱花粉、翡翠绿、金属银）和 App 图标由本项目在 `TTSkin/BuiltInSkins.swift`、`Tools/make-icon.swift` 中用代码原创绘制，未包含千千静听的任何素材。
`.skn` 格式（Skin.xml 各元素、四态按钮、LED 字形顺序、播放模式顺序）参考了社区公开的格式说明，没有复制任何代码。
JTplayer 与千千静听、百度无关；用户导入的 .skn 皮肤版权归原作者所有。

内核包里的 `AmplayerSkin` 模块来自姊妹项目 Amplayer（Winamp 皮肤，JTplayer 只用到其中的 ZIP 读取器），其中的 “Amplayer Graphite” 皮肤与像素字体同样为原创绘制。

## 测试素材
第三方 `.skn` / `.wsz` 皮肤仅在本地测试时使用（`Fixtures/local/`），不入库、不随 App 分发。
