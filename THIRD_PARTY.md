# Third-party downloads / hashes

The release contains only the game-local community bridge and its source. No NVIDIA or 4A Games binaries.

- Runtime: original `nvngx_dlssnr.dll` 310.9.16.0 comes with Metro; OpenNR source (`https://github.com/clshortfuse/openNR`) can reconstruct the tested RTX 40 version from it, locally. Upstream source is downloaded over HTTPS and its locally built DLL is verified against the pinned known-good hash.
- MinHook v1.3.3 (`https://github.com/TsudaKageyu/minhook`) is downloaded by the optional local compiler build. Third-party licensing: see its upstream LICENSE.
- The Metro Advanced Configurator (`https://www.nexusmods.com/metro2033redux/mods/57`) is optional and is not redistributed.
- For a direct download / manually supplied patched DLL, the installer validates SHA-256 `CDFA6C1EC784867182164C7836F324F087B5C9F374D0C9FE46F54999FEABF3ED` before touching the target DLL. User-selected alternate DLL versions are deliberately rejected until tested.
