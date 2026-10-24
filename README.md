# Metro 2033 Redux Next-Gen — Neural Rendering for RTX 40

Make **Metro 2033 Redux** look more modern with improved lighting, shadows and ambient occlusion using the game's built-in **DLSS 5 Neural Rendering**.

This mod makes that feature work on **NVIDIA RTX 40-series graphics cards**. Normally, it isn't available on these cards.

> **Experimental mod.** Confirmed working on an RTX 4070 Ti SUPER. Other RTX 40 cards haven't been fully tested. It can lower your FPS significantly.

## What do I need?

**Required:**
- **Windows** and an **NVIDIA RTX 40-series** graphics card.
- **Metro 2033 Redux with the October 2026 Next-Gen update**.
- A compatible **DLSS Neural Rendering file** (`nvngx_dlssnr.dll`, version **310.9.16**). The installer will guide you through this part.

**Optional — you do NOT need these just to play:**
- [**Advanced Configurator**](https://www.nexusmods.com/metro2033redux/mods/57): adds extra controls to fine-tune Neural Rendering. **The game's own Neural Rendering switch works without it.**
- **Visual Studio / CMake / CUDA**: only needed if you're building the mod yourself or choosing the option to create a compatible DLSS file from the original game file.

## How to install

1. Open [**Releases**](https://github.com/JungleHam/Metro-2033-NextGen-DLSS5-RTX40/releases) and download **`Metro-NR-RTX40-Setup-v1.0.0-rc2.exe`** when the build is available.
2. Open the downloaded setup file. The **Metro NR Setup** window opens — no scary black command window.
3. Choose **Install / update**, and check that it found your Metro game folder.
4. Choose how to get the compatible DLSS file (see the simple guide below), then click **Install mod**.
5. Watch the installation progress in the same window. You can see the steps and a live log there.
6. Start Metro. Set **DLSS Quality** and turn **Neural Rendering ON** in the game's graphics settings.

**Already installed?** Open **Start → Metro NR RTX40 → Install or Uninstall** to manage or remove the mod.

**Prefer the ZIP?** The Windows ZIP contains the same game mod plus manual `Install.cmd` and `Uninstall.cmd` scripts for advanced users.

That's it. **You don't need Advanced Configurator or an extra in-game menu.**

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
- **If Metro won't start or Neural Rendering doesn't work:** click **Open saved log** in the setup window, or run **`Report.cmd`** for game diagnostics, and attach the results to a [GitHub issue](https://github.com/JungleHam/Metro-2033-NextGen-DLSS5-RTX40/issues).
- **If another mod already uses `dinput8.dll`:** the installer won't overwrite it without recognizing it as one of our previous installations.

The installer makes backups before changing managed files. It **does not patch your NVIDIA graphics driver**. Logs are saved in **`%LOCALAPPDATA%\\Metro-NR-RTX40\\Logs`**. Progress is shown inside the installer; the moving progress bar indicates activity, not an exact completion percentage.

## For advanced users

- Tested compatible DLL: **310.9.16**, SHA-256 `CDFA6C1EC784867182164C7836F324F087B5C9F374D0C9FE46F54999FEABF3ED`.
- Original Metro DLL SHA-256: `2BC19BC09A7B89DD44F73E2AC0108FCC586E2154BDD0830F242F4F040E28789F`.
- Source builders: run `Build.ps1` (Visual Studio C++ tools required). See `THIRD_PARTY.md` for upstream projects.
- This repository does **not** include NVIDIA's proprietary DLSS DLL. The bridge uses MinHook and is licensed under MIT.

Unofficial community project. Not affiliated with NVIDIA or 4A Games.
