# Metro 2033 Redux Next-Gen — DLSS 5 NR on RTX 40

Experimental, game-local **native DLSS 5 Neural Rendering** bridge for RTX 40-series GPUs. Confirmed working on an **RTX 4070 Ti SUPER** (driver 621.01, Metro October 2026). No driver patches and no bundled NVIDIA binaries.

## Install (Windows)

1. Download the Windows release ZIP, extract it and run **Install.cmd**. It detects your GPU and Steam game folder (or lets you browse).
2. Choose how to prepare `nvngx_dlssnr.dll` 310.9.16:
   - **Already patched:** keep the compatible DLL in the game folder.
   - **Bring your own:** select a compatible `nvngx_dlssnr.dll` using the file picker.
   - **Automatic preparation:** download [OpenNR](https://github.com/clshortfuse/openNR) source and reconstruct the RTX 40-compatible DLL from your **original Metro DLL**. Requires **Visual Studio 2022 C++ Build Tools, CMake 3.23+, and CUDA Toolkit 13.4/13.4.3**. It does not download or redistribute NVIDIA's DLL; it uses your game copy.
   - **HTTPS link:** if you have a direct download URL for the exact compatible build, enter it. The downloaded file must match the tested SHA-256.
3. Start Metro, set **DLSS Quality**, and enable **Neural Rendering** in the game's native graphics options.

**Advanced Configurator is NOT required**. [Gametism's Advanced Configurator](https://www.nexusmods.com/metro2033redux/mods/57) is optional for extra NR controls. Keep its `winmm.dll` separate; our bridge uses `dinput8.dll`.

**Known working patched NR DLL:** 310.9.16.0, SHA-256 `CDFA6C1EC784867182164C7836F324F087B5C9F374D0C9FE46F54999FEABF3ED`.
Original Metro DLL SHA-256 `2BC19BC09A7B89DD44F73E2AC0108FCC586E2154BDD0830F242F4F040E28789F`. The **310.8 RTX 40 DLL used in the GTA IV installer is NOT the tested Metro runtime**, so the installer will reject it.

Uninstall: close Metro and run **Uninstall.cmd**. Our `dinput8.dll` and bridge settings are removed, leaving game files, NR DLL and any optional configurator untouched. Existing managed installation upgrades are backed up; unmanaged `dinput8.dll` files are never overwritten.

## What it does

The proxy reports a Blackwell-compatible identity for targeted NGX checks, bypasses feature-18 discovery, and routes init/create/evaluate to your patched NR DLL. It does not emulate Blackwell. Our working log observed direct NR init, feature creation and repeated successful evaluation on RTX 4070 Ti SUPER. Main-menu test: NR off 273 FPS, on 80–83 FPS; gameplay ~80 FPS at 1440p, max settings, DLSS Quality (one user's measurements).

The native bridge and the quiet-logging changes are experimental on GPUs other than the tested card; game/driver updates may break it. `Report.cmd` collects diagnostics. `MetroNRVerbose.on` in the game folder enables verbose logging for troubleshooting.

## Build & licensing

Build locally with `Build.ps1` (MSVC x64) or download the compiled ZIP from GitHub Actions / Releases. Installer never modifies system NVIDIA files. [MinHook](https://github.com/TsudaKageyu/minhook) v1.3.3 is fetched during compilation; the project itself is MIT licensed; OpenNR is an independent upstream project. Proprietary NVIDIA binaries are **not** included. Automatic OpenNR source download uses the upstream main branch; final output must exactly match the known tested SHA-256 before installation. No source-only preparation is completely turnkey if CUDA/MSVC are not already available.

Unofficial community project, not affiliated with NVIDIA, Valve or 4A Games. Use only with software you own and without multiplayer anti-cheat.
