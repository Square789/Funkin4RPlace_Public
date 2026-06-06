
# Funkin' 4 r/place
An r/place mod for Friday Night Funkin'.

> [!NOTE]
> This repository contains both the demo and the release version of F4RP, all in a big unwieldy ball of data.
> Simply check out the commit history at the relevant version tags to get where you want. (Probably.)

> [!CAUTION]
> The instructions below are fairly dated. You will likely run into problems if you wanted to follow them.
> As a rule of thumb, try downgrading library versions until the errors go away.

## Download & Play
* [GameBanana](https://gamebanana.com/mods/444552)

## Building
You must have [the most up-to-date version of Haxe](https://haxe.org/download/) (*not* Haxe 4.1.5!)

Then, run the following:
```
haxelib install lime
haxelib update lime
haxelib install openfl
haxelib update openfl
haxelib install flixel 5.2.2
haxelib install flixel-addons 3.0.2
haxelib run lime setup flixel
haxelib install newgrounds
haxelib update newgrounds
haxelib run flixel-tools setup
haxelib run lime setup
haxelib git discord_rpc https://github.com/Aidan63/linc_discord-rpc
haxelib git hscript https://github.com/HaxeFoundation/hscript
haxelib git hscript-ex https://github.com/ianharrigan/hscript-ex
```

(At the moment, you need to also run `haxelib git linc_luajit https://github.com/nebulazorua/linc_luajit`)

If you get an error about StatePointer (or anything else really) when using Lua, run haxelib remove linc_luajit into Command Prompt/PowerShell, then re-install linc_luajit.

When it asks you for your IDE, you can pick your actual IDE (or, if you don't know / can't identify it, choose `4`). Say yes to adding `flixel` and `lime` as commands.

Then:

**For our charters! Add `-debug` to all of these commands**
* If you're building for HTML5, run `lime test html5`
* If you're building for Mac, run `lime test mac`
* If you're building for Linux, run `lime test linux`
* If you're building for Windows, keep reading


If you're building for Windows, download 
~~<sup>[Visual Studio Community 2019](https://visualstudio.microsoft.com/thank-you-downloading-visual-studio/?sku=Community&rel=16) ([try this link if the other one doesn't work](https://my.visualstudio.com/Downloads?q=visual%20studio%202019&wt.mc_id=o~msft~vscom~older-downloads)).~~</sup>

## *Howdy! Microsoft has murdered the previous ways to download **Visual Studio Code 2019***.
### [*Here is a direct link as an alternative.*](https://aka.ms/vs/17/release/vs_community.exe)
### Don't worry, it's safe! It's from an official Microsoft Website! You're good!

##

While installing, **do not choose any option to install workloads**. 

Instead, go to the individual components tab and choose the following:
* MSVC v142 - VS 2019 C++ x64/x86 build tools
* Windows SDK (10.0.17763.0)

This will take up about 4GB of storage. Once that's done, you can run `lime test windows`. **For our charters! Run `lime test windows -debug` instead**

#### Android
(NOTE: Android support is currently experimental and has not been tested on an actual device yet)

All credit to the [Funkin-android repository](https://github.com/luckydog7/Funkin-android) for the entire tutorial.

1. Download [Android Studio](https://developer.android.com/studio), the [Java Development Kit](https://www.oracle.com/java/technologies/javase/javase-jdk8-downloads.html), and the [Android NDK (r15c)](https://github.com/android/ndk/wiki/Unsupported-Downloads#r15c). Install Android Studio and the JDK, and unzip the Android NDK somewhere in your computer.

2. In Android Studio, go to Settings -> Appearance & Behavior -> System Settings -> Android SDK. Install Android 4.4 (KitKat), Android SDK Build-Tools, and Android SDK Platform-Tools.

3. In the Command Prompt (or the Terminal), run `lime setup android`. Insert the corresponding file paths. Your Android SDK should be located in `C:\Users\*username*\AppData\Local\Android\Sdk`, and your Java JDK in `C:\Program Files\Java\jdk1.8.0_331`.

4. Run `lime build android -debug` (remove "-debug" for official releases) to build the APK. The APK will be located inside your source code directory in `export\(debug or release)\android\bin\app\build\outputs\apk`. If you have a device emulator running in Android Studio, you can instead do `lime test android` to open it in the emulator.

## Licensing
All work **not listed below** is under [the Apache License, Version 2.0](./LICENSE-APACHE):
    
    Copyright 2022 The Funkin' 4 r/place authors and contributors

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software 
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
    
The following are *not* under the Apache 2.0 license:
* The Reddit Mono font, found in `assets/fonts/RedditMono-Regular.ttf` and `assets/fonts/RedditMono-Bold.ttf`, is used under the [Reddit Brand Terms of Use](./LICENSE-REDDITMONO.md).
* The Inter font, found in `assets/fonts/Inter-Regular.otf` and `assets/fonts/Inter-Bold.otf`, is used under the [SIL Open Font License, Version 1.1](./LICENSE-INTER).
* The Pixel Arial 11 font, found in `assets/fonts/pixel.otf`, is not specifically under any one license, but the author stated it was free use.
* The VCR OSD Mono font, found in `assets/fonts/vcr.ttf`, is not specifically under any one license, but the author stated it was free use.
* The IBM Plex font, found in `assets/fonts/IBMPlexSans-Regular.ttf`, `assets/fonts/IBMPlexSans-Medium.ttf` and `assets/fonts/IBMPlexSans-Bold.ttf` is used under the [SIL Open Font License, Version 1.1](./LICENSE-IBMPLEX).
* The Pokémon DP Pro font is used in a few images under the [CC-BY-SA 3.0](http://creativecommons.org/licenses/by-sa/3.0/) license. See the [licensing notice](./LICENSE-POKEMON-DP-PRO-FONTSTRUCT).
