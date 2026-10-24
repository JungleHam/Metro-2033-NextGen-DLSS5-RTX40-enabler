# Metro 2033 Redux Next-Gen — Neural Rendering for RTX 40

Make **Metro 2033 Redux** look more modern with improved lighting, shadows and ambient occlusion using the game's built-in **DLSS 5 Neural Rendering**.

This mod makes that feature work on **NVIDIA RTX 40-series graphics cards**. Normally, it isn't available on these cards.

> **Experimental mod.** Confirmed working on an RTX 4070 Ti SUPER. Other RTX 40 cards haven't been fully tested. It can lower your FPS significantly.

## What do I need?

**Required:**
- **Windows** and an **NVIDIA RTX 40-series** graphics card.
- **Metro 2033 Redux** or **Metro Last Light Redux**, with the October 2026 Next-Gen update.
- A compatible **DLSS Neural Rendering file** (`nvngx_dlssnr.dll`, version **310.9.16**). The installer will guide you through this part.

**Optional — you do NOT need these just to play:**
- [**Advanced Configurator**](https://www.nexusmods.com/metro2033redux/mods/57): adds extra controls to fine-tune Neural Rendering. **The game's own Neural Rendering switch works without it.**
- **Visual Studio / CMake / CUDA**: only needed if you're building the mod yourself or choosing the option to create a compatible DLSS file from the original game file.

## Download and install (no setup required)

**[Download the portable installer from GitHub Releases](https://github.com/JungleHam/Metro-NextGen-DLSS5-RTX40-enabler/releases)**

Look for **Metro-NR-RTX40-Portable-v1.0.0-preview1.exe** in the latest *Portable Preview* release.

1. **Download the EXE and double-click it.** No extraction, setup wizard, or installer installation.
2. Select **Metro 2033 Redux** or **Metro Last Light Redux**.
3. Choose **Install / update** (or **Uninstall mod**).
4. Check your game folder and choose the compatible Neural Rendering DLL option.
5. Click **Install mod**, then watch progress and messages in the same window.
6. Launch your game, enable DLSS Quality, and turn on Neural Rendering in the graphics settings.

**The same EXE can uninstall the mod later.** It removes our GPU hook and settings but deliberately leaves the game's NR DLL and optional Advanced Configurator alone. You don't need to keep an installed manager on your PC. To make further changes, simply run the downloaded EXE again.

If the portable preview isn't listed yet, the Windows build hasn't successfully published it. The [Actions page](https://github.com/JungleHam/Metro-NextGen-DLSS5-RTX40-enabler/actions) shows build status.

**Installation logs and backups survive after closing the installer.** Find them under `%LOCALAPPDATA%\Metro-NR-RTX40\Logs` and `%LOCALAPPDATA%\Metro-NR-RTX40\Backups`.

### Which DLSS file option should I pick?

The game includes a DLSS file, but on RTX 40 cards it needs a compatible version. The installer checks the file so that it doesn't silently install the wrong one.

| What you have | What to choose |
| --- | --- |
| You already have a working, compatible file in your Metro folder | **Keep existing file** — the installer checks and keeps it |
| You downloaded a compatible `nvngx_dlssnr.dll` yourself | **Browse for a file** — select it on your PC |
| You only have the original game file and the developer tools listed above | **Build from game file** — downloads the OpenNR project and creates the compatible version on your PC |
| You have a direct HTTPS link to the *correct* compatible DLL | **Download from link** — paste the link; the installer checks the download |

**Important:** The installer **does not currently have a built-in direct download link** for the exact tested Metro DLL. The "Build from game file" option downloads the tools' *source code*, not a ready-to-use DLL, and requires Visual Studio C++ Build Tools, CMake and CUDA 13.4. If those tools are missing, use **Browse for a file** instead.

**Do not use the older 310.8.0 RTX 40 DLL from our GTA IV mod.** This Metro mod expects the tested **310.9.16** version.

## Optional: more Neural Rendering settings

Want to adjust the effect beyond the game's normal graphics options?

Install [**Metro 2033 Advanced Configurator**](https://www.nexusmods.com/metro2033redux/mods/57) separately and use its extra controls.

**Completely optional.** This mod works on its own.

## How much FPS will I lose?

Neural Rendering can be demanding. On our RTX 4070 Ti SUPER test PC at **1440p, maximum graphics settings, DLSS Quality**, we saw around **80 FPS during gameplay**. Your results may differ.

## Uninstall or get help

- **To uninstall:** open **Metro NR Setup** from the Start menu, select **Uninstall mod**, and click the button. It only removes files the mod can safely identify; your game, DLSS file and optional configurator remain untouched.
- **If Metro won't start or Neural Rendering doesn't work:** click **Open saved log** in the setup window, or run **`Report.cmd`** for game diagnostics, and attach the results to a [GitHub issue](https://github.com/JungleHam/Metro-NextGen-DLSS5-RTX40-enabler/issues).
- **If another mod already uses `dinput8.dll`:** the installer won't overwrite it without recognizing it as one of our previous installations.

The installer makes backups before changing managed files. It **does not patch your NVIDIA graphics driver**. Logs are saved in **`%LOCALAPPDATA%\\Metro-NR-RTX40\\Logs`**. Progress is shown inside the installer; the moving progress bar indicates activity, not an exact completion percentage.

## For advanced users

- Tested compatible DLL: **310.9.16**, SHA-256 `CDFA6C1EC784867182164C7836F324F087B5C9F374D0C9FE46F54999FEABF3ED`.
- Original Metro DLL SHA-256: `2BC19BC09A7B89DD44F73E2AC0108FCC586E2154BDD0830F242F4F040E28789F`.
- Source builders: run `Build.ps1` (Visual Studio C++ tools required). See `THIRD_PARTY.md` for upstream projects.
- This repository does **not** include NVIDIA's proprietary DLSS DLL. The bridge uses MinHook and is licensed under MIT.

Unofficial community project. Not affiliated with NVIDIA or 4A Games.


## Metro Last Light Redux

The portable installer supports **both Metro games**. Last Light has also been reported working with the same NR bridge on an RTX 4070 Ti SUPER. Other cards and game versions still need testing.

Select your game carefully. Each installation has its own backups, saved folder path, and uninstall action. Selecting Last Light does not modify Metro 2033.
