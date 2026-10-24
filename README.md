# Metro 2033 and Last Light - Next Gen Update — DLSS 5 Neural Rendering on RTX 40

Use **Neural Rendering** in **Metro 2033 Redux Next Gen** and **Metro Last Light Redux Next Gen** on NVIDIA **RTX 40-series** graphics cards. Can significantly reduce FPS though.

## Download

### [Download Portable Preview 3](https://github.com/JungleHam/Metro-NextGen-DLSS5-RTX40-enabler/releases/tag/v1.0.0-portable-preview3)

Download **`Metro-NR-RTX40-Portable-v1.0.0-preview3.exe`** from **Assets**.

## How to use it

1. Open the downloaded EXE.
2. Choose **Metro 2033 Redux** or **Metro Last Light Redux**.
3. Leave **Install / update** selected.
4. Confirm your game folder and select your DLSS Neural Rendering file option (see below).
5. Click **Install mod** and watch the progress and messages in the same window.
6. Start your game, set **DLSS Quality**, and switch **Neural Rendering** **ON** in its graphics settings.
## Optional but preferred:

[**Metro 2033 Advanced Configurator**](https://www.nexusmods.com/metro2033redux/mods/57) offers more Neural Rendering tweaks for Metro 2033. **It is optional**, not required for the normal in-game NR switch to work. It is not bundled with our mod.

### Which DLL option should I choose?

The installer needs a **compatible DLSS Neural Rendering file** named `nvngx_dlssnr.dll` (version **310.9.16**). It verifies the file before using it.

| Your situation | Select |
| --- | --- |
| You already use a compatible DLL in that game's folder | **Use compatible DLL already in Metro folder** |
| You have the compatible DLL elsewhere on your PC | **Browse for a compatible DLL** |
| You have the original game DLL and the required developer tools | **Build from my original game DLL** |
| You have an HTTPS link to the exact compatible DLL | **Download from an HTTPS link** |

**Important:** There is **no automatic one-click download of the patched DLL** yet. The *Build* option downloads source code and requires **Visual Studio C++ Build Tools, CMake, and CUDA 13.4** already installed. The installer does **not** install those tools. The *Browse* option is the simplest choice if you already have the working DLL.

The older **310.8.0** DLL is assumed **not compatible with this verified Metro installation** so it wasn't tested.

## How to uninstall

Run **the same portable EXE**, choose the correct game, select **Uninstall mod**, and confirm.

The uninstall removes our mod's hook and settings **only if it can verify them**. It deliberately **keeps** the game's `nvngx_dlssnr.dll`, your backups, and other mods. No need to uninstall the portable EXE: you can simply delete your downloaded copy.


## Technical notes (optional reading)

This is a **game-local mod**. It does not modify your NVIDIA driver. The portable EXE includes our compiled proxy, not NVIDIA's proprietary DLSS DLL.

Tested patched `nvngx_dlssnr.dll` **310.9.16** SHA-256:
`CDFA6C1EC784867182164C7836F324F087B5C9F374D0C9FE46F54999FEABF3ED`.

On the tested RTX 4070 Ti SUPER at 1440p, DLSS Quality, maximum settings, one gameplay test averaged around **80 FPS** with NR enabled. Your results may vary.

The source build uses `Build.ps1` and Windows C++ tools. Developers can use `Report.ps1 -Game 2033` or `Report.ps1 -Game LastLight` for detailed game diagnostics. See [third-party notes](THIRD_PARTY.md) for dependencies and upstream projects.

Unofficial project; not affiliated with NVIDIA or 4A Games.
