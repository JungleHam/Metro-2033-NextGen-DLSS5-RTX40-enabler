// Metro NR Direct Snippet Bridge v1.0.0 - quiet logging release candidate.
// Purpose: spoof NVAPI architecture; selectively spoof Metro + NGX core PCI/name/DXGI adapter IDs; trace NGX
// for Ada architecture queries in the Metro process. NOT a GPU emulator.
// Does not modify NVIDIA drivers or NGX binaries.

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <unknwn.h>
#include <dxgi1_2.h>
#include <d3d12.h>
#include <cstdio>
#include <cstdarg>
#include <cwchar>
#include <cstring>
#include <intrin.h>
#include "MinHook.h"

#ifndef _WIN64
#error This test is for 64-bit Metro only.
#endif

namespace {
HMODULE g_self = nullptr;
HMODULE g_real_dinput = nullptr;
HMODULE g_nvapi = nullptr;
INIT_ONCE g_init = INIT_ONCE_STATIC_INIT;
LONG g_arch_calls = 0;
LONG g_ngx_calls = 0;
LONG g_requirements_calls = 0;
LONG g_capability_calls = 0;
// The NGX Core API cannot create feature 18 (0xBAD0000B). The NR model has
// its OWN NGX exports. This opt-in bridge attempts that actual feature path.
// Never fabricate a success handle or bypass failed model initialization.
constexpr unsigned int kNRAppID = 0x0876232C;
constexpr unsigned int kNGXAPIVersion = 0x15;
HMODULE g_nr_module = nullptr;
bool g_direct_initialized = false;
unsigned int g_direct_init_result = 0xBAD00007;
void* g_nr_feature_handle = nullptr;
using SnippetInitFn = unsigned int(__cdecl *)(unsigned long long, const wchar_t*, void*, unsigned int, const void*);
using SnippetCreateFn = unsigned int(__cdecl *)(void*, int, void*, void**);
using SnippetEvaluateFn = unsigned int(__cdecl *)(void*, void*, void*, void*);
using SnippetReleaseFn = unsigned int(__cdecl *)(void*);
SnippetInitFn g_direct_init = nullptr;
SnippetCreateFn g_direct_create = nullptr;
SnippetEvaluateFn g_direct_evaluate = nullptr;
SnippetReleaseFn g_direct_release = nullptr;
using CoreEvaluateFn = unsigned int(__cdecl *)(void*, void*, void*, void*);
using CoreReleaseFn = unsigned int(__cdecl *)(void*);
CoreEvaluateFn g_original_core_eval = nullptr;
CoreReleaseFn g_original_core_release = nullptr;
bool g_core_eval_hooked = false;
bool g_core_release_hooked = false;
LONG g_nr_evaluate_calls = 0;
using GetModuleFileNameWFn = DWORD(WINAPI *)(HMODULE, LPWSTR, DWORD);
GetModuleFileNameWFn g_original_modulefilename = nullptr;
LONG g_caller_compat_spoofs = 0;
bool g_verbose_logging = false; // Optional diagnostics; never required for rendering.
// A probe marker file in the Metro game folder must be created before launch.
// This is separate from the feature-requirement probe marker.
bool DirectSnippetEnabled();
unsigned int AttemptDirectSnippet(void* cmdList, int feature, void* params, void** handle);

LONG g_dxgi_calls = 0;
LONG g_nvapi_pci_calls = 0;
LONG g_nvapi_name_calls = 0;
constexpr unsigned int kRTX5090DeviceID = 0x2B85;
constexpr unsigned int kNvidiaVendorID = 0x10DE;
bool IsMetroCaller(const char* callerName) {
    return callerName && _stricmp(callerName, "metro.exe") == 0;
}
// Only identity lookups directly inside the game and NGX core are spoofed.
// Other NVIDIA, DXGI and Direct3D driver modules still see the real adapter.
bool IsIdentitySpoofCaller(const char* callerName) {
    return IsMetroCaller(callerName) ||
           (callerName && _stricmp(callerName, "_nvngx.dll") == 0);
}


// Windows loader notifications capture short-lived module loads that the
// 50ms GetModuleHandle poll could miss. The callback runs under the loader
// lock and therefore NEVER calls Log(), LoadLibrary or allocates memory.
struct ProbeUnicodeString { USHORT Length; USHORT MaximumLength; PWSTR Buffer; };
struct ProbeModuleNotification {
    ULONG Flags;
    const ProbeUnicodeString* FullDllName;
    const ProbeUnicodeString* BaseDllName;
    void* DllBase;
    ULONG SizeOfImage;
};
union ProbeNotificationData {
    ProbeModuleNotification Loaded;
    ProbeModuleNotification Unloaded;
};
using ProbeNotifyFn = void (CALLBACK *)(ULONG, const ProbeNotificationData*, void*);
using ProbeRegisterFn = LONG (NTAPI *)(ULONG, ProbeNotifyFn, void*, void**);
struct ProbeEvent {
    volatile LONG ready;
    ULONG reason;
    void* address;
    wchar_t name[112];
    wchar_t path[320];
};
constexpr LONG kMaxProbeEvents = 256;
ProbeEvent g_probeEvents[kMaxProbeEvents] = {};
LONG g_probeCount = 0;
void* g_probeCookie = nullptr;
// NGX core and signed NR snippet export identically named functions from
// DIFFERENT MODULES. Hook each export independently; v0.2 only hooked core.
constexpr int kNRFeature = 18;
using CreateFeatureFn = unsigned int (__cdecl *)(void*, int, void*, void**);
using InitExtFn = unsigned int (__cdecl *)(unsigned long long, const wchar_t*,
                                         void*, unsigned int, const void*);
struct CreateSlot {
    const wchar_t* module;
    const char* display;
    const char* exportName;
    CreateFeatureFn original = nullptr;
    void* target = nullptr;
};
CreateSlot g_creates[6] = {
    {L"_nvngx.dll", "core:D3D11", "NVSDK_NGX_D3D11_CreateFeature"},
    {L"_nvngx.dll", "core:D3D12", "NVSDK_NGX_D3D12_CreateFeature"},
    {L"nvngx.dll", "nvngx:D3D11", "NVSDK_NGX_D3D11_CreateFeature"},
    {L"nvngx.dll", "nvngx:D3D12", "NVSDK_NGX_D3D12_CreateFeature"},
    {L"nvngx_dlssnr.dll", "NR-snippet:D3D11", "NVSDK_NGX_D3D11_CreateFeature"},
    {L"nvngx_dlssnr.dll", "NR-snippet:D3D12", "NVSDK_NGX_D3D12_CreateFeature"}
};
struct InitSlot {
    const char* label;
    const char* exportName;
    InitExtFn original = nullptr;
    void* target = nullptr;
};
InitSlot g_nrInits[2] = {
    {"NR-snippet:D3D11", "NVSDK_NGX_D3D11_Init_Ext"},
    {"NR-snippet:D3D12", "NVSDK_NGX_D3D12_Init_Ext"}
};
// NVSDK_NGX_{D3D11,D3D12}_GetFeatureRequirements is allowed before
// NGX initialization. Its result can prevent the NR snippet loading at all.
// Layouts: NVIDIA SDK nvsdk_ngx_defs.h (FeatureDiscoveryInfo begins
// with SDKVersion and FeatureID, both 32-bit enums).
struct FeatureDiscoveryPrefix {
    unsigned int sdkVersion;
    int featureId;
};
struct FeatureRequirementPrefix {
    unsigned int featureSupported;
    unsigned int minHWArchitecture;
};
using GetFeatureRequirementsFn = unsigned int (__cdecl *)(void*, const void*, void*);
using GetCapabilityParametersFn = unsigned int (__cdecl *)(void**);
struct RequirementsSlot {
    const wchar_t* module;
    const char* label;
    const char* exportName;
    GetFeatureRequirementsFn original = nullptr;
    void* target = nullptr;
};
RequirementsSlot g_requirements[4] = {
    {L"_nvngx.dll", "core:D3D11", "NVSDK_NGX_D3D11_GetFeatureRequirements"},
    {L"_nvngx.dll", "core:D3D12", "NVSDK_NGX_D3D12_GetFeatureRequirements"},
    {L"nvngx.dll", "nvngx:D3D11", "NVSDK_NGX_D3D11_GetFeatureRequirements"},
    {L"nvngx.dll", "nvngx:D3D12", "NVSDK_NGX_D3D12_GetFeatureRequirements"}
};
struct CapabilitySlot {
    const wchar_t* module;
    const char* label;
    const char* exportName;
    GetCapabilityParametersFn original = nullptr;
    void* target = nullptr;
};
CapabilitySlot g_capabilities[4] = {
    {L"_nvngx.dll", "core:D3D11", "NVSDK_NGX_D3D11_GetCapabilityParameters"},
    {L"_nvngx.dll", "core:D3D12", "NVSDK_NGX_D3D12_GetCapabilityParameters"},
    {L"nvngx.dll", "nvngx:D3D11", "NVSDK_NGX_D3D11_GetCapabilityParameters"},
    {L"nvngx.dll", "nvngx:D3D12", "NVSDK_NGX_D3D12_GetCapabilityParameters"}
};
constexpr unsigned int kGetArchInfoId = 0xD8265D24;
constexpr unsigned int kGetPCIIdentifiersId = 0x2DDFB66E;
constexpr unsigned int kGetFullNameId = 0xCEEE8E9F;
constexpr unsigned int kAdaArch = 0x190;
constexpr unsigned int kBlackwellGB2Arch = 0x1B0;

struct ArchInfo {
    unsigned int version;
    unsigned int architecture;
    unsigned int implementation;
    unsigned int revision;
};
static_assert(sizeof(ArchInfo) == 16, "NVAPI arch info layout mismatch");
using QueryInterfaceFn = void* (__cdecl *)(unsigned int);
using GetArchInfoFn = int (__cdecl *)(void*, ArchInfo*);
GetArchInfoFn g_original_get_arch = nullptr;
using GetPCIIdentifiersFn = int (__cdecl *)(void*, unsigned int*, unsigned int*, unsigned int*, unsigned int*);
using GetFullNameFn = int (__cdecl *)(void*, char*);
GetPCIIdentifiersFn g_original_get_pci = nullptr;
GetFullNameFn g_original_get_name = nullptr;

// IDXGIAdapter GetDesc / IDXGIAdapter1 GetDesc1 / IDXGIAdapter2 GetDesc2
// share implementation entry points across objects on current Windows builds.
// Hook the method functions, never write into vtables or device-driver memory.
using GetDescFn = HRESULT (STDMETHODCALLTYPE *)(IDXGIAdapter*, DXGI_ADAPTER_DESC*);
using GetDesc1Fn = HRESULT (STDMETHODCALLTYPE *)(IDXGIAdapter1*, DXGI_ADAPTER_DESC1*);
using GetDesc2Fn = HRESULT (STDMETHODCALLTYPE *)(IDXGIAdapter2*, DXGI_ADAPTER_DESC2*);
GetDescFn g_original_desc = nullptr;
GetDesc1Fn g_original_desc1 = nullptr;
GetDesc2Fn g_original_desc2 = nullptr;


// Do not call the hooked GetModuleFileNameW from inside the hook's own
// diagnostics. CallerModuleName() is called by HookGetModuleFileNameW, and
// Log() is called after enabling that hook. Calling the hooked entry point
// recursively caused a startup stack overflow in v0.9/v0.9.1.
DWORD UnhookedGetModuleFileNameW(HMODULE module, LPWSTR buffer, DWORD size) {
    if (g_original_modulefilename)
        return g_original_modulefilename(module, buffer, size);
    return ::GetModuleFileNameW(module, buffer, size);
}

void Log(const char* fmt, ...) {
    wchar_t path[MAX_PATH] = {};
    if (!UnhookedGetModuleFileNameW(g_self, path, MAX_PATH)) return;
    wchar_t* sep = wcsrchr(path, L'\\');
    if (!sep) return;
    *(sep + 1) = 0;
    if (wcslen(path) + wcslen(L"MetroNRGpuSpoof.log") + 1 >= MAX_PATH) return;
    wcscat_s(path, MAX_PATH, L"MetroNRGpuSpoof.log");

    char message[1024] = {};
    va_list args;
    va_start(args, fmt);
    vsnprintf_s(message, sizeof(message), _TRUNCATE, fmt, args);
    va_end(args);
    HANDLE file = CreateFileW(path, FILE_APPEND_DATA, FILE_SHARE_READ | FILE_SHARE_WRITE,
                              nullptr, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (file == INVALID_HANDLE_VALUE) return;
    DWORD wrote = 0;
    WriteFile(file, message, static_cast<DWORD>(strlen(message)), &wrote, nullptr);
    CloseHandle(file);
    OutputDebugStringA(message);
}

// Return the module name that requested the GPU architecture, not just the value.
void CallerModuleName(void* returnAddr, char* result, size_t capacity) {
    if (!result || !capacity) return;
    strncpy_s(result, capacity, "unknown", _TRUNCATE);
    HMODULE module = nullptr;
    if (!GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
                            GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                            reinterpret_cast<LPCWSTR>(returnAddr), &module)) return;
    wchar_t path[MAX_PATH] = {};
    if (!UnhookedGetModuleFileNameW(module, path, MAX_PATH)) return;
    const wchar_t* name = wcsrchr(path, L'\\');
    name = name ? name + 1 : path;
    WideCharToMultiByte(CP_UTF8, 0, name, -1, result, static_cast<int>(capacity), nullptr, nullptr);
}

// v0.7: test identity spoofing when the caller is metro.exe OR _nvngx.dll.
// Calls from driver internals (nvapi64_impl.dll, d3d11.dll, dxgi.dll, etc.)
// are not changed. Reversible user-mode experiment, not GPU emulation.
int __cdecl HookGetPCIIdentifiers(void* gpu, unsigned int* device, unsigned int* subsystem,
                                 unsigned int* revision, unsigned int* external) {
    if (!g_original_get_pci) return -1;
    char caller[128] = {};
    CallerModuleName(_ReturnAddress(), caller, sizeof(caller));
    const int rc = g_original_get_pci(gpu, device, subsystem, revision, external);
    const LONG n = InterlockedIncrement(&g_nvapi_pci_calls);
    if (rc == 0 && device) {
        const unsigned int real = *device;
        const bool spoof = IsIdentitySpoofCaller(caller) && (real & 0xffffu) == kNvidiaVendorID;
        if (spoof) *device = (kRTX5090DeviceID << 16) | kNvidiaVendorID;
        if (n <= 60) Log("[nvapi-pci] caller=%s result=%d original=0x%08X returned=0x%08X spoof=%d\r\n",
                         caller, rc, real, *device, spoof ? 1 : 0);
    } else if (n <= 60) {
        Log("[nvapi-pci] caller=%s result=%d no-details\r\n", caller, rc);
    }
    return rc;
}

int __cdecl HookGetFullName(void* gpu, char* name) {
    if (!g_original_get_name) return -1;
    char caller[128] = {};
    CallerModuleName(_ReturnAddress(), caller, sizeof(caller));
    const int rc = g_original_get_name(gpu, name);
    const LONG n = InterlockedIncrement(&g_nvapi_name_calls);
    if (rc == 0 && name) {
        char previous[64] = {};
        strncpy_s(previous, sizeof(previous), name, _TRUNCATE);
        const bool spoof = IsIdentitySpoofCaller(caller);
        if (spoof) strncpy_s(name, 64, "NVIDIA GeForce RTX 5090", _TRUNCATE);
        if (n <= 60) Log("[nvapi-name] caller=%s original=%s returned=%s spoof=%d\r\n",
                         caller, previous, name, spoof ? 1 : 0);
    } else if (n <= 60) {
        Log("[nvapi-name] caller=%s result=%d\r\n", caller, rc);
    }
    return rc;
}

void LogAndSpoofDxgi(unsigned int* vendor, unsigned int* device, wchar_t* name,
                    size_t nameCapacity, const char* api, void* callerAddress) {
    char caller[128] = {};
    CallerModuleName(callerAddress, caller, sizeof(caller));
    const LONG n = InterlockedIncrement(&g_dxgi_calls);
    const unsigned int realVendor = vendor ? *vendor : 0;
    const unsigned int realDevice = device ? *device : 0;
    const bool spoof = IsIdentitySpoofCaller(caller) && realVendor == kNvidiaVendorID;
    if (spoof) {
        if (device) *device = kRTX5090DeviceID;
        if (name && nameCapacity) wcsncpy_s(name, nameCapacity, L"NVIDIA GeForce RTX 5090", _TRUNCATE);
    }
    if (n <= 80) {
        Log("[dxgi-id] api=%s caller=%s vendor=0x%04X originalDevice=0x%04X returnedDevice=0x%04X spoof=%d\r\n",
            api, caller, realVendor, realDevice, device ? *device : 0, spoof ? 1 : 0);
    }
}

HRESULT STDMETHODCALLTYPE HookGetDesc(IDXGIAdapter* adapter, DXGI_ADAPTER_DESC* desc) {
    if (!g_original_desc) return E_FAIL;
    void* caller = _ReturnAddress();
    const HRESULT hr = g_original_desc(adapter, desc);
    if (SUCCEEDED(hr) && desc) LogAndSpoofDxgi(&desc->VendorId, &desc->DeviceId,
        desc->Description, _countof(desc->Description), "GetDesc", caller);
    return hr;
}
HRESULT STDMETHODCALLTYPE HookGetDesc1(IDXGIAdapter1* adapter, DXGI_ADAPTER_DESC1* desc) {
    if (!g_original_desc1) return E_FAIL;
    void* caller = _ReturnAddress();
    const HRESULT hr = g_original_desc1(adapter, desc);
    if (SUCCEEDED(hr) && desc) LogAndSpoofDxgi(&desc->VendorId, &desc->DeviceId,
        desc->Description, _countof(desc->Description), "GetDesc1", caller);
    return hr;
}
HRESULT STDMETHODCALLTYPE HookGetDesc2(IDXGIAdapter2* adapter, DXGI_ADAPTER_DESC2* desc) {
    if (!g_original_desc2) return E_FAIL;
    void* caller = _ReturnAddress();
    const HRESULT hr = g_original_desc2(adapter, desc);
    if (SUCCEEDED(hr) && desc) LogAndSpoofDxgi(&desc->VendorId, &desc->DeviceId,
        desc->Description, _countof(desc->Description), "GetDesc2", caller);
    return hr;
}

// Target only the system DXGI methods, discovered through a temporary DXGI
// factory/adapter object. We do not replace DXGI objects or alter the driver.
DWORD WINAPI InstallDxgiHooks(LPVOID) {
    HMODULE dxgi = LoadLibraryW(L"dxgi.dll");
    if (!dxgi) { Log("[dxgi] missing system dxgi.dll\r\n"); return 0; }
    using CreateFactoryFn = HRESULT (WINAPI*)(REFIID, void**);
    auto factoryFn = reinterpret_cast<CreateFactoryFn>(GetProcAddress(dxgi, "CreateDXGIFactory1"));
    if (!factoryFn) { Log("[dxgi] CreateDXGIFactory1 missing\r\n"); return 0; }
    IDXGIFactory1* factory = nullptr;
    HRESULT hr = factoryFn(__uuidof(IDXGIFactory1), reinterpret_cast<void**>(&factory));
    if (FAILED(hr) || !factory) { Log("[dxgi] factory failed hr=0x%08X\r\n", (unsigned int)hr); return 0; }
    IDXGIAdapter1* adapter = nullptr;
    hr = factory->EnumAdapters1(0, &adapter);
    if (FAILED(hr) || !adapter) {
        Log("[dxgi] EnumAdapters1 failed hr=0x%08X\r\n", (unsigned int)hr);
        factory->Release(); return 0;
    }
    // Derive concrete method addresses from interface vtables (COM ABI).
    void** methods = *reinterpret_cast<void***>(adapter);
    void* desc = methods[8];
    void* desc1 = methods[10];
    IDXGIAdapter2* adapter2 = nullptr;
    if (SUCCEEDED(adapter->QueryInterface(__uuidof(IDXGIAdapter2),
        reinterpret_cast<void**>(&adapter2))) && adapter2) {
        void** methods2 = *reinterpret_cast<void***>(adapter2);
        void* desc2 = methods2[11];
        MH_STATUS rc = MH_CreateHook(desc2, reinterpret_cast<void*>(&HookGetDesc2),
                                      reinterpret_cast<void**>(&g_original_desc2));
        if (rc == MH_OK) {
            rc = MH_EnableHook(desc2);
            Log("[dxgi] GetDesc2 hook enable=%d\r\n", (int)rc);
        } else Log("[dxgi] GetDesc2 create failed=%d\r\n", (int)rc);
        adapter2->Release();
    }
    MH_STATUS rc = MH_CreateHook(desc, reinterpret_cast<void*>(&HookGetDesc),
                                 reinterpret_cast<void**>(&g_original_desc));
    if (rc == MH_OK) { rc = MH_EnableHook(desc); Log("[dxgi] GetDesc hook enable=%d\r\n", (int)rc); }
    else Log("[dxgi] GetDesc create failed=%d\r\n", (int)rc);
    rc = MH_CreateHook(desc1, reinterpret_cast<void*>(&HookGetDesc1),
                       reinterpret_cast<void**>(&g_original_desc1));
    if (rc == MH_OK) { rc = MH_EnableHook(desc1); Log("[dxgi] GetDesc1 hook enable=%d\r\n", (int)rc); }
    else Log("[dxgi] GetDesc1 create failed=%d\r\n", (int)rc);
    adapter->Release();
    factory->Release();
    return 0;
}

// Bounded copy of a UNICODE_STRING, valid even if the source lacks a NUL.
void CopyProbeString(const ProbeUnicodeString* from, wchar_t* to, size_t cap) {
    if (!to || !cap) return;
    to[0] = 0;
    if (!from || !from->Buffer) return;
    size_t count = static_cast<size_t>(from->Length / sizeof(wchar_t));
    if (count >= cap) count = cap - 1;
    for (size_t i = 0; i < count; ++i) to[i] = from->Buffer[i];
    to[count] = 0;
}

bool RelevantModule(const wchar_t* input) {
    wchar_t lowercase[112] = {};
    size_t i = 0;
    while (input[i] && i + 1 < _countof(lowercase)) {
        wchar_t c = input[i];
        lowercase[i] = (c >= L'A' && c <= L'Z') ? c + 32 : c;
        ++i;
    }
    return wcsstr(lowercase, L"ngx") != nullptr ||
           wcsstr(lowercase, L"dlss") != nullptr ||
           wcsstr(lowercase, L"nvapi") != nullptr ||
           wcsstr(lowercase, L"d3d12") != nullptr ||
           wcsstr(lowercase, L"d3d11") != nullptr ||
           wcsstr(lowercase, L"dxgi") != nullptr ||
           wcsstr(lowercase, L"metro") != nullptr;
}

// No logging or heap allocation here: callbacks run under the loader lock.
void CALLBACK OnModuleEvent(ULONG reason, const ProbeNotificationData* data, void*) {
    if (!data || (reason != 1 && reason != 2)) return;
    const ProbeModuleNotification& entry = (reason == 1) ? data->Loaded : data->Unloaded;
    wchar_t name[112] = {};
    CopyProbeString(entry.BaseDllName, name, _countof(name));
    if (!RelevantModule(name)) return;
    const LONG index = InterlockedIncrement(&g_probeCount) - 1;
    if (index < 0 || index >= kMaxProbeEvents) return;
    ProbeEvent& target = g_probeEvents[index];
    target.reason = reason;
    target.address = entry.DllBase;
    CopyProbeString(entry.BaseDllName, target.name, _countof(target.name));
    CopyProbeString(entry.FullDllName, target.path, _countof(target.path));
    InterlockedExchange(&target.ready, 1);
}

void RegisterModuleProbe() {
    HMODULE ntdll = GetModuleHandleW(L"ntdll.dll");
    auto reg = ntdll ? reinterpret_cast<ProbeRegisterFn>(
        GetProcAddress(ntdll, "LdrRegisterDllNotification")) : nullptr;
    if (!reg) {
        Log("[loader] notification API unavailable; polling only\r\n");
        return;
    }
    LONG result = reg(0, &OnModuleEvent, nullptr, &g_probeCookie);
    Log("[loader] registered result=0x%08X enabled=%d\r\n",
        static_cast<unsigned int>(result), result >= 0);
}


// Functions are in the original DLL game directory only. Safe fail-closed:
// never pretend the NR feature was created on any error.
bool DirectSnippetEnabled() {
    wchar_t path[MAX_PATH] = {};
    if (!UnhookedGetModuleFileNameW(g_self, path, MAX_PATH)) return false;
    auto* last = wcsrchr(path, L'\\');
    if (!last) return false;
    *(last + 1) = 0;
    if (wcslen(path) + wcslen(L"MetroNRDirectSnippet.on") + 1 >= MAX_PATH) return false;
    wcscat_s(path, MAX_PATH, L"MetroNRDirectSnippet.on");
    const auto attr = GetFileAttributesW(path);
    return attr != INVALID_FILE_ATTRIBUTES && !(attr & FILE_ATTRIBUTE_DIRECTORY);
}

// Read optional diagnostic marker once, before hooks are installed.
// Reduces disk I/O on every frame when NR is active.
bool VerboseMarkerPresent() {
    wchar_t path[MAX_PATH] = {};
    if (!UnhookedGetModuleFileNameW(g_self, path, MAX_PATH)) return false;
    auto* separator = wcsrchr(path, L'\\');
    if (!separator) return false;
    *(separator + 1) = 0;
    if (wcslen(path) + wcslen(L"MetroNRVerbose.on") + 1 >= MAX_PATH) return false;
    wcscat_s(path, MAX_PATH, L"MetroNRVerbose.on");
    const DWORD attr = GetFileAttributesW(path);
    return attr != INVALID_FILE_ATTRIBUTES && !(attr & FILE_ATTRIBUTE_DIRECTORY);
}

DWORD WINAPI HookGetModuleFileNameW(HMODULE hModule, LPWSTR output, DWORD size) {
    if (!g_original_modulefilename) return 0;
    char caller[128] = {};
    CallerModuleName(_ReturnAddress(), caller, sizeof(caller));
    const DWORD written = g_original_modulefilename(hModule, output, size);
    // The NR snippet checks the module identity of its direct caller. This
    // local game proxy presents the expected nvngx.dll basename, ONLY to
    // calls originating in nvngx_dlssnr.dll that ask about this proxy.
    if (g_verbose_logging && _stricmp(caller, "nvngx_dlssnr.dll") == 0) {
        Log("[direct] snippet GetModuleFileNameW module=%p self=%p result=%lu\r\n",
            hModule, g_self, written);
    }
    if (written && output && size && hModule == g_self &&
        _stricmp(caller, "nvngx_dlssnr.dll") == 0) {
        wchar_t* last = wcsrchr(output, L'\\');
        if (last && (size_t)(last - output + 1) + wcslen(L"nvngx.dll") < size) {
            wcscpy_s(last + 1, size - (last - output + 1), L"nvngx.dll");
            const auto n = (DWORD)wcslen(output);
            const LONG compatCount = InterlockedIncrement(&g_caller_compat_spoofs);
            if (g_verbose_logging || compatCount <= 3)
                Log("[direct] snippet caller compatibility: returned nvngx.dll (call=%ld)\r\n", compatCount);
            return n;
        }
    }
    return written;
}

unsigned int __cdecl HookCoreEvaluate(void* context, void* handle, void* params, void* callback) {
    if (handle && handle == g_nr_feature_handle && g_direct_evaluate) {
        const auto result = g_direct_evaluate(context, handle, params, callback);
        const LONG n = InterlockedIncrement(&g_nr_evaluate_calls);
        // Summary on first frames and occasional heartbeat; full logging is opt-in.
        if (g_verbose_logging || n <= 5 || n % 1000 == 0 || result != 1)
            Log("[direct-evaluate] call=%ld result=0x%08X\r\n", n, result);
        return result;
    }
    return g_original_core_eval ? g_original_core_eval(context, handle, params, callback) : 0xBAD00000;
}

unsigned int __cdecl HookCoreRelease(void* handle) {
    if (handle && handle == g_nr_feature_handle && g_direct_release) {
        auto result = g_direct_release(handle);
        Log("[direct-release] result=0x%08X\r\n", result);
        g_nr_feature_handle = nullptr;
        return result;
    }
    return g_original_core_release ? g_original_core_release(handle) : 0xBAD00000;
}

unsigned int AttemptDirectSnippet(void* cmdList, int feature, void* params, void** handle) {
    if (!cmdList || !handle || feature != kNRFeature) return 0xBAD00005;
    if (!g_core_eval_hooked || !g_core_release_hooked) {
        Log("[direct] unsafe: Evaluate/Release hooks not both installed; refusing bridge\r\n");
        return 0xBAD00007;
    }
    auto* list = static_cast<ID3D12GraphicsCommandList*>(cmdList);
    ID3D12Device* device = nullptr;
    HRESULT hr = list->GetDevice(__uuidof(ID3D12Device), reinterpret_cast<void**>(&device));
    if (FAILED(hr) || !device) {
        Log("[direct] GetDevice failed HRESULT=0x%08X\r\n", (unsigned)hr);
        return 0xBAD00002;
    }
    if (!g_nr_module) {
        wchar_t gameDir[MAX_PATH] = {};
        UnhookedGetModuleFileNameW(g_self, gameDir, MAX_PATH);
        auto* sep = wcsrchr(gameDir, L'\\');
        if (!sep) { device->Release(); return 0xBAD00000; }
        *(sep + 1) = 0;
        wchar_t modelFile[MAX_PATH] = {};
        wcscpy_s(modelFile, gameDir);
        wcscat_s(modelFile, L"nvngx_dlssnr.dll");
        g_nr_module = LoadLibraryExW(modelFile, nullptr,
                                    LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_DEFAULT_DIRS);
        if (!g_nr_module) {
            Log("[direct] loading patched nvngx_dlssnr.dll failed Win32=%lu\r\n", GetLastError());
            device->Release(); return 0xBAD0000B;
        }
        g_direct_init = reinterpret_cast<SnippetInitFn>(GetProcAddress(g_nr_module, "NVSDK_NGX_D3D12_Init_Ext"));
        g_direct_create = reinterpret_cast<SnippetCreateFn>(GetProcAddress(g_nr_module, "NVSDK_NGX_D3D12_CreateFeature"));
        g_direct_evaluate = reinterpret_cast<SnippetEvaluateFn>(GetProcAddress(g_nr_module, "NVSDK_NGX_D3D12_EvaluateFeature"));
        g_direct_release = reinterpret_cast<SnippetReleaseFn>(GetProcAddress(g_nr_module, "NVSDK_NGX_D3D12_ReleaseFeature"));
        Log("[direct] DLL loaded=%p init=%p create=%p evaluate=%p release=%p\r\n",
            g_nr_module, (void*)g_direct_init, (void*)g_direct_create,
            (void*)g_direct_evaluate, (void*)g_direct_release);
        if (!g_direct_init || !g_direct_create || !g_direct_evaluate || !g_direct_release) {
            device->Release(); return 0xBAD0000B;
        }
        const unsigned initResult = g_direct_init(kNRAppID, gameDir, device, kNGXAPIVersion, nullptr);
        Log("[direct-init] result=0x%08X sdk=0x%X callerCompatSpoofs=%ld\r\n",
            initResult, kNGXAPIVersion, g_caller_compat_spoofs);
        g_direct_init_result = initResult;
        g_direct_initialized = initResult == 1;
        if (!g_direct_initialized) { device->Release(); return initResult; }
    }
    device->Release();
    if (!g_direct_initialized) return g_direct_init_result;
    if (!g_direct_create) return 0xBAD0000B;
    const unsigned result = g_direct_create(cmdList, feature, params, handle);
    Log("[direct-create] feature=%d result=0x%08X handle=%p\r\n", feature,
        result, (result == 1 && handle) ? *handle : nullptr);
    if (result == 1 && handle && *handle) g_nr_feature_handle = *handle;
    return result;
}

template <int Index>
unsigned int __cdecl HookCreate(void* context, int feature, void* params, void** handle) {
    auto original = g_creates[Index].original;
    if (!original) return 0xBAD00000;
    if (Index == 1 && feature == kNRFeature && DirectSnippetEnabled()) {
        const unsigned int directResult = AttemptDirectSnippet(context, feature, params, handle);
        if (directResult == 1) return directResult;
        Log("[direct] failed result=0x%08X; core fallback may return 0xBAD0000B\r\n", directResult);
    }
    const unsigned int result = original(context, feature, params, handle);
    const LONG n = InterlockedIncrement(&g_ngx_calls);
    if (feature == kNRFeature || n <= 32) {
        // Never dereference the output handle if feature creation failed.
        void* created = (result == 1 && handle) ? *handle : nullptr;
        Log("[ngx-create] module=%s call=%ld feature=%d result=0x%08X success=%d handle=%p\r\n",
            g_creates[Index].display, n, feature, result, result == 1, created);
    }
    return result;
}

using CreateHookPtr = CreateFeatureFn;
CreateHookPtr kCreateHooks[6] = {
    &HookCreate<0>, &HookCreate<1>, &HookCreate<2>,
    &HookCreate<3>, &HookCreate<4>, &HookCreate<5>
};

template <int Index>
unsigned int __cdecl HookInitExt(unsigned long long appId, const wchar_t* dataPath,
                                 void* device, unsigned int sdkVersion, const void* params) {
    auto original = g_nrInits[Index].original;
    if (!original) return 0xBAD00000;
    Log("[nr-init] ENTER module=%s appId=0x%llX sdkVersion=0x%X device=%p\r\n",
        g_nrInits[Index].label, appId, sdkVersion, device);
    const unsigned int result = original(appId, dataPath, device, sdkVersion, params);
    Log("[nr-init] RETURN module=%s result=0x%08X success=%d\r\n",
        g_nrInits[Index].label, result, result == 1);
    return result;
}

InitExtFn kInitHooks[2] = { &HookInitExt<0>, &HookInitExt<1> };

// Diagnostic opt-in. This does NOT make the driver or GPU implement feature 18.
// A file in the game's folder enables one narrowly scoped discovery response,
// letting us learn whether Metro subsequently attempts to load nvngx_dlssnr.dll.
// The real NGX result is still collected and recorded before the override.
bool Feature18ProbeEnabled() {
    wchar_t file[MAX_PATH] = {};
    if (!UnhookedGetModuleFileNameW(g_self, file, MAX_PATH)) return false;
    wchar_t* slash = wcsrchr(file, L'\\');
    if (!slash) return false;
    *(slash + 1) = L'\0';
    if (wcslen(file) + wcslen(L"MetroNRFeature18Probe.on") + 1 >= MAX_PATH) return false;
    wcscat_s(file, MAX_PATH, L"MetroNRFeature18Probe.on");
    DWORD attrs = GetFileAttributesW(file);
    return attrs != INVALID_FILE_ATTRIBUTES && !(attrs & FILE_ATTRIBUTE_DIRECTORY);
}

// Observe feature availability, and optionally test ONE caller/feature/result.
// An opt-in query override is NOT equivalent to functional NR support.
template <int Index>
unsigned int __cdecl HookRequirements(void* adapter, const void* discovery, void* supported) {
    auto original = g_requirements[Index].original;
    if (!original) return 0xBAD00000;
    const int feature = discovery ?
        static_cast<const FeatureDiscoveryPrefix*>(discovery)->featureId : -1;
    void* caller = _ReturnAddress();
    char callerName[128] = {};
    CallerModuleName(caller, callerName, sizeof(callerName));
    const unsigned int result = original(adapter, discovery, supported);
    const LONG n = InterlockedIncrement(&g_requirements_calls);
    // Only for the real Metro 2033 executable, D3D12 NGX core, feature 18,
    // and precisely FAIL_NotImplemented. Unrelated calls stay unmodified.
    const bool mayProbe = Index == 1 && feature == kNRFeature &&
        IsMetroCaller(callerName) && supported && result == 0xBAD00012u &&
        Feature18ProbeEnabled();
    if (mayProbe) {
        auto* requirements = static_cast<FeatureRequirementPrefix*>(supported);
        requirements->featureSupported = 0u; // NVSDK_NGX_FeatureSupportResult_Supported
        requirements->minHWArchitecture = kBlackwellGB2Arch;
        // NVIDIA's struct also contains char MinOSVersion[255] immediately
        // after these two fields. Set the first byte to an empty string.
        reinterpret_cast<char*>(requirements)[8] = '\0';
        Log("[feature18-probe] caller=%s original=0x%08X returned=0x00000001 flags=0 minArch=0x%X (NOT real support)\r\n",
            callerName, result, kBlackwellGB2Arch);
    }
    if (feature == kNRFeature || n <= 48) {
        if ((result == 1 || mayProbe) && supported) {
            const auto& req = *static_cast<const FeatureRequirementPrefix*>(supported);
            Log("[ngx-require] module=%s caller=%s call=%ld feature=%d result=0x%08X supportedFlags=0x%X minArchitecture=0x%X\r\n",
                g_requirements[Index].label, callerName, n, feature, result,
                req.featureSupported, req.minHWArchitecture);
        } else {
            Log("[ngx-require] module=%s caller=%s call=%ld feature=%d result=0x%08X supported=%p\r\n",
                g_requirements[Index].label, callerName, n, feature, result, supported);
        }
    }
    return mayProbe ? 1u : result;
}
GetFeatureRequirementsFn kRequirementsHooks[4] = {
    &HookRequirements<0>, &HookRequirements<1>,
    &HookRequirements<2>, &HookRequirements<3>
};

// Capability parameters can also drive availability flags in Metro's
// internal logic. Log acquisition, not the undocumented parameter contents.
template <int Index>
unsigned int __cdecl HookCapabilities(void** out) {
    auto original = g_capabilities[Index].original;
    if (!original) return 0xBAD00000;
    const unsigned int result = original(out);
    const LONG n = InterlockedIncrement(&g_capability_calls);
    if (n <= 32) {
        Log("[ngx-capability] module=%s call=%ld result=0x%08X params=%p\r\n",
            g_capabilities[Index].label, n, result, out && result == 1 ? *out : nullptr);
    }
    return result;
}
GetCapabilityParametersFn kCapabilityHooks[4] = {
    &HookCapabilities<0>, &HookCapabilities<1>,
    &HookCapabilities<2>, &HookCapabilities<3>
};

// Never stop watching after discovering _nvngx.dll: DLSS NR may load later and
// call nvngx_dlssnr.dll's signed snippet exports directly rather than core.
DWORD WINAPI ObserveNGX(LPVOID) {
    LONG nextEvent = 0;
    const wchar_t* names[] = { L"_nvngx.dll", L"nvngx.dll", L"nvngx_dlssnr.dll" };
    bool seen[3] = {false, false, false};
    bool createAttempted[6] = {};
    bool initAttempted[2] = {};
    bool reqAttempted[4] = {};
    bool capabilityAttempted[4] = {};
    for (int tick = 0; tick < 3600; ++tick) {
        const LONG last = InterlockedCompareExchange(&g_probeCount, 0, 0);
        while (nextEvent < last && nextEvent < kMaxProbeEvents) {
            ProbeEvent& event = g_probeEvents[nextEvent];
            if (InterlockedCompareExchange(&event.ready, 0, 0) != 1) break;
            // Windows %ls handles native wide paths without a conversion library.
            Log("[loader] action=%s module=%ls base=%p path=%ls\r\n",
                event.reason == 1 ? "load" : "unload",
                event.name, event.address, event.path);
            ++nextEvent;
        }
        for (int m = 0; m < 3; ++m) {
            HMODULE mod = GetModuleHandleW(names[m]);
            if (!mod) continue;
            if (!seen[m]) {
                char label[128] = {};
                WideCharToMultiByte(CP_UTF8, 0, names[m], -1, label, sizeof(label), nullptr, nullptr);
                Log("[ngx] observed module=%s base=%p\r\n", label, mod);
                seen[m] = true;
            }
            for (int i = 0; i < 6; ++i) {
                auto& slot = g_creates[i];
                if (createAttempted[i] || _wcsicmp(slot.module, names[m]) != 0) continue;
                void* target = reinterpret_cast<void*>(GetProcAddress(mod, slot.exportName));
                if (!target) continue;
                createAttempted[i] = true;
                const MH_STATUS rc = MH_CreateHook(target,
                    reinterpret_cast<void*>(kCreateHooks[i]),
                    reinterpret_cast<void**>(&slot.original));
                if (rc == MH_OK) {
                    const MH_STATUS enabled = MH_EnableHook(target);
                    if (enabled == MH_OK || enabled == MH_ERROR_ENABLED) {
                        slot.target = target;
                        Log("[ngx] hooked module=%s export=%s address=%p\r\n",
                            slot.display, slot.exportName, target);
                    } else {
                        Log("[ngx] enable failed module=%s rc=%d\r\n",
                            slot.display, static_cast<int>(enabled));
                    }
                } else {
                    Log("[ngx] create failed module=%s rc=%d\r\n",
                        slot.display, static_cast<int>(rc));
                }
            }
            // Hook the core's requirements and capabilities if exported.
            // Log failures: a missing export is not proof the query was absent.
            for (int i = 0; i < 4; ++i) {
                auto& slot = g_requirements[i];
                if (reqAttempted[i] || _wcsicmp(slot.module, names[m]) != 0) continue;
                reqAttempted[i] = true;
                void* target = reinterpret_cast<void*>(GetProcAddress(mod, slot.exportName));
                if (!target) {
                    Log("[ngx] requirements export absent module=%s\r\n", slot.label);
                    continue;
                }
                const MH_STATUS rc = MH_CreateHook(target,
                    reinterpret_cast<void*>(kRequirementsHooks[i]),
                    reinterpret_cast<void**>(&slot.original));
                if (rc == MH_OK) {
                    const MH_STATUS enabled = MH_EnableHook(target);
                    if (enabled == MH_OK || enabled == MH_ERROR_ENABLED) {
                        slot.target = target;
                        Log("[ngx] hooked requirements module=%s address=%p\r\n", slot.label, target);
                    } else {
                        Log("[ngx] requirements enable failed module=%s rc=%d\r\n",
                            slot.label, static_cast<int>(enabled));
                    }
                } else {
                    Log("[ngx] requirements create failed module=%s rc=%d\r\n",
                        slot.label, static_cast<int>(rc));
                }
            }
            for (int i = 0; i < 4; ++i) {
                auto& slot = g_capabilities[i];
                if (capabilityAttempted[i] || _wcsicmp(slot.module, names[m]) != 0) continue;
                capabilityAttempted[i] = true;
                void* target = reinterpret_cast<void*>(GetProcAddress(mod, slot.exportName));
                if (!target) continue;
                const MH_STATUS rc = MH_CreateHook(target,
                    reinterpret_cast<void*>(kCapabilityHooks[i]),
                    reinterpret_cast<void**>(&slot.original));
                if (rc == MH_OK) {
                    const MH_STATUS enabled = MH_EnableHook(target);
                    if (enabled == MH_OK || enabled == MH_ERROR_ENABLED) {
                        slot.target = target;
                        Log("[ngx] hooked capability module=%s address=%p\r\n", slot.label, target);
                    } else {
                        Log("[ngx] capability enable failed module=%s rc=%d\r\n",
                            slot.label, static_cast<int>(enabled));
                    }
                } else {
                    Log("[ngx] capability create failed module=%s rc=%d\r\n",
                        slot.label, static_cast<int>(rc));
                }
            }

            if (m == 0 && DirectSnippetEnabled()) {
                if (!g_core_eval_hooked) {
                    auto* addr = reinterpret_cast<void*>(GetProcAddress(mod, "NVSDK_NGX_D3D12_EvaluateFeature"));
                    if (addr && MH_CreateHook(addr, (void*)&HookCoreEvaluate,
                                              reinterpret_cast<void**>(&g_original_core_eval)) == MH_OK) {
                        auto rc = MH_EnableHook(addr);
                        g_core_eval_hooked = (rc == MH_OK || rc == MH_ERROR_ENABLED);
                        Log("[direct-hook] EvaluateFeature enabled=%d\r\n", g_core_eval_hooked);
                    }
                }
                if (!g_core_release_hooked) {
                    auto* addr = reinterpret_cast<void*>(GetProcAddress(mod, "NVSDK_NGX_D3D12_ReleaseFeature"));
                    if (addr && MH_CreateHook(addr, (void*)&HookCoreRelease,
                                              reinterpret_cast<void**>(&g_original_core_release)) == MH_OK) {
                        auto rc = MH_EnableHook(addr);
                        g_core_release_hooked = (rc == MH_OK || rc == MH_ERROR_ENABLED);
                        Log("[direct-hook] ReleaseFeature enabled=%d\r\n", g_core_release_hooked);
                    }
                }
            }
            if (m == 2) {
                for (int i = 0; i < 2; ++i) {
                    auto& slot = g_nrInits[i];
                    if (initAttempted[i]) continue;
                    void* target = reinterpret_cast<void*>(GetProcAddress(mod, slot.exportName));
                    if (!target) continue;
                    initAttempted[i] = true;
                    const MH_STATUS rc = MH_CreateHook(target,
                        reinterpret_cast<void*>(kInitHooks[i]),
                        reinterpret_cast<void**>(&slot.original));
                    if (rc == MH_OK) {
                        const MH_STATUS enabled = MH_EnableHook(target);
                        if (enabled == MH_OK || enabled == MH_ERROR_ENABLED) {
                            slot.target = target;
                            Log("[ngx] hooked module=%s export=%s address=%p\r\n",
                                slot.label, slot.exportName, target);
                        } else {
                            Log("[ngx] enable failed module=%s rc=%d\r\n",
                                slot.label, static_cast<int>(enabled));
                        }
                    } else {
                        Log("[ngx] create failed module=%s rc=%d\r\n",
                            slot.label, static_cast<int>(rc));
                    }
                }
            }
        }
        if (tick == 100 || tick == 300) {
            Log("[ngx] checkpoint seconds=%d core=%d nvngx=%d nr-snippet=%d requirementCalls=%ld capabilityCalls=%ld\r\n",
                (tick + 1) / 20, seen[0], seen[1], seen[2],
                g_requirements_calls, g_capability_calls);
        }
        Sleep(50);
    }
    Log("[ngx] observer stopped after 180 seconds; modules core=%d nvngx=%d nr-snippet=%d\r\n",
        seen[0], seen[1], seen[2]);
    return 0;
}

int __cdecl HookGetArchInfo(void* gpu, ArchInfo* info) {
    if (!g_original_get_arch) return -1;
    void* caller = _ReturnAddress();
    char callerName[128] = {};
    CallerModuleName(caller, callerName, sizeof(callerName));
    const int status = g_original_get_arch(gpu, info);
    const LONG n = InterlockedIncrement(&g_arch_calls);
    if (status == 0 && info) {
        const auto actual = info->architecture;
        if (actual == kAdaArch) {
            info->architecture = kBlackwellGB2Arch;
        }
        if (n <= 32) {
            Log("[arch] call=%ld caller=%s status=%d original=0x%X returned=0x%X version=0x%X\r\n",
                n, callerName, status, actual, info->architecture, info->version);
        }
    } else if (n <= 32) {
        Log("[arch] call=%ld caller=%s status=%d info=%p (not rewritten)\r\n", n, callerName, status, info);
    }
    return status;
}

void* SystemDll(const wchar_t* name) {
    wchar_t folder[MAX_PATH] = {};
    const UINT len = GetSystemDirectoryW(folder, MAX_PATH);
    if (len == 0 || len >= MAX_PATH) return nullptr;
    if (wcslen(folder) + 1 + wcslen(name) + 1 >= MAX_PATH) return nullptr;
    wcscat_s(folder, MAX_PATH, L"\\");
    wcscat_s(folder, MAX_PATH, name);
    return LoadLibraryW(folder);
}

// Only called from DirectInput8Create, *not* from DllMain (loader lock).
BOOL CALLBACK Initialize(PINIT_ONCE, PVOID, PVOID*) {
    Log("[init] Metro NR GPU Spoof v1.0.0 release candidate, process=%lu\r\n", GetCurrentProcessId());
    g_verbose_logging = VerboseMarkerPresent();
    Log("[startup] verbose logging=%d (MetroNRVerbose.on)\r\n", g_verbose_logging ? 1 : 0);
    Log("[startup] loading real dinput8.dll\r\n");
    g_real_dinput = static_cast<HMODULE>(SystemDll(L"dinput8.dll"));
    if (!g_real_dinput) {
        Log("[error] Loading genuine System32 dinput8.dll failed: %lu\r\n", GetLastError());
        return TRUE;
    }

    Log("[startup] real dinput8.dll loaded\r\n");
    // Load the genuine NVIDIA driver interface, never a game-local replacement.
    g_nvapi = static_cast<HMODULE>(SystemDll(L"nvapi64.dll"));
    if (!g_nvapi) {
        Log("[error] Loading genuine System32 nvapi64.dll failed: %lu\r\n", GetLastError());
        return TRUE;
    }
    auto query = reinterpret_cast<QueryInterfaceFn>(GetProcAddress(g_nvapi, "nvapi_QueryInterface"));
    if (!query) {
        Log("[error] nvapi_QueryInterface export missing\r\n");
        return TRUE;
    }
    void* arch_fn = query(kGetArchInfoId);
    if (!arch_fn) {
        Log("[error] NvAPI_GPU_GetArchInfo ID was not found\r\n");
        return TRUE;
    }

    Log("[startup] NVAPI interface resolved; initializing MinHook\r\n");
    const MH_STATUS init = MH_Initialize();
    if (init != MH_OK && init != MH_ERROR_ALREADY_INITIALIZED) {
        Log("[error] MH_Initialize returned %d\r\n", static_cast<int>(init));
        return TRUE;
    }

    Log("[startup] MinHook ready; direct=%d\r\n", (int)DirectSnippetEnabled());
    if (DirectSnippetEnabled()) {
        auto* filenameAddress = reinterpret_cast<void*>(GetProcAddress(GetModuleHandleW(L"kernel32.dll"),
                                                                       "GetModuleFileNameW"));
        if (filenameAddress) {
            const auto create = MH_CreateHook(filenameAddress, (void*)&HookGetModuleFileNameW,
                reinterpret_cast<void**>(&g_original_modulefilename));
            if (create == MH_OK) {
                Log("[startup] enabling GetModuleFileNameW hook\r\n");
                auto enable = MH_EnableHook(filenameAddress);
                Log("[direct-hook] GetModuleFileNameW enabled=%d\r\n", enable == MH_OK);
            } else Log("[direct-hook] module-file-name create error=%d\r\n", (int)create);
        }
    }
    Log("[startup] installing NVAPI architecture hook\r\n");
    const MH_STATUS hook = MH_CreateHook(arch_fn, reinterpret_cast<void*>(&HookGetArchInfo),
                                       reinterpret_cast<void**>(&g_original_get_arch));
    if (hook != MH_OK) {
        Log("[error] MH_CreateHook returned %d\r\n", static_cast<int>(hook));
        return TRUE;
    }
    const MH_STATUS enable = MH_EnableHook(arch_fn);
    if (enable != MH_OK) {
        Log("[error] MH_EnableHook returned %d\r\n", static_cast<int>(enable));
        return TRUE;
    }
    Log("[hook] NvAPI_GPU_GetArchInfo active at %p; Ada 0x190 -> GB200 0x1B0\r\n", arch_fn);
    // QueryInterface IDs are from NVIDIA's public nvapi_interface.h.
    void* pciFn = query(kGetPCIIdentifiersId);
    if (pciFn) {
        MH_STATUS rc = MH_CreateHook(pciFn, reinterpret_cast<void*>(&HookGetPCIIdentifiers),
                                     reinterpret_cast<void**>(&g_original_get_pci));
        if (rc == MH_OK) {
            rc = MH_EnableHook(pciFn);
            Log("[hook] NvAPI_GPU_GetPCIIdentifiers enabled=%d\r\n", (int)rc);
        } else Log("[hook] NVAPI PCI hook error=%d\r\n", (int)rc);
    }
    void* fullNameFn = query(kGetFullNameId);
    if (fullNameFn) {
        MH_STATUS rc = MH_CreateHook(fullNameFn, reinterpret_cast<void*>(&HookGetFullName),
                                     reinterpret_cast<void**>(&g_original_get_name));
        if (rc == MH_OK) {
            rc = MH_EnableHook(fullNameFn);
            Log("[hook] NvAPI_GPU_GetFullName enabled=%d\r\n", (int)rc);
        } else Log("[hook] NVAPI name hook error=%d\r\n", (int)rc);
    }
    HANDLE dxgiWorker = CreateThread(nullptr, 0, InstallDxgiHooks, nullptr, 0, nullptr);
    if (dxgiWorker) CloseHandle(dxgiWorker);
    else Log("[dxgi] worker start failed err=%lu\r\n", GetLastError());
    RegisterModuleProbe();
    HANDLE watcher = CreateThread(nullptr, 0, ObserveNGX, nullptr, 0, nullptr);
    if (watcher) {
        CloseHandle(watcher);
    } else {
        Log("[ngx] Failed to start NGX observer thread (Windows error=%lu)\r\n", GetLastError());
    }
    return TRUE;
}

HMODULE RealDinput() {
    InitOnceExecuteOnce(&g_init, Initialize, nullptr, nullptr);
    return g_real_dinput;
}

FARPROC ResolveDinput(const char* name) {
    HMODULE mod = RealDinput();
    return mod ? GetProcAddress(mod, name) : nullptr;
}
}

extern "C" HRESULT WINAPI DirectInput8Create(HINSTANCE inst, DWORD version, REFIID riid,
                                                LPVOID* result, LPUNKNOWN outer) {
    using Fn = HRESULT(WINAPI*)(HINSTANCE,DWORD,REFIID,LPVOID*,LPUNKNOWN);
    auto real = reinterpret_cast<Fn>(ResolveDinput("DirectInput8Create"));
    if (!real) return E_FAIL;
    return real(inst, version, riid, result, outer);
}

extern "C" HRESULT WINAPI DllCanUnloadNow() {
    using Fn = HRESULT(WINAPI*)();
    auto real = reinterpret_cast<Fn>(ResolveDinput("DllCanUnloadNow"));
    return real ? real() : S_FALSE;
}
extern "C" HRESULT WINAPI DllGetClassObject(REFCLSID rclsid, REFIID riid, LPVOID* result) {
    using Fn = HRESULT(WINAPI*)(REFCLSID,REFIID,LPVOID*);
    auto real = reinterpret_cast<Fn>(ResolveDinput("DllGetClassObject"));
    return real ? real(rclsid, riid, result) : CLASS_E_CLASSNOTAVAILABLE;
}
extern "C" HRESULT WINAPI DllRegisterServer() {
    using Fn = HRESULT(WINAPI*)();
    auto real = reinterpret_cast<Fn>(ResolveDinput("DllRegisterServer"));
    return real ? real() : E_NOTIMPL;
}
extern "C" HRESULT WINAPI DllUnregisterServer() {
    using Fn = HRESULT(WINAPI*)();
    auto real = reinterpret_cast<Fn>(ResolveDinput("DllUnregisterServer"));
    return real ? real() : E_NOTIMPL;
}
// Some Windows builds export this as a function; unused in Metro's reported path.
extern "C" void* WINAPI GetdfDIJoystick() {
    using Fn = void*(WINAPI*)();
    auto real = reinterpret_cast<Fn>(ResolveDinput("GetdfDIJoystick"));
    return real ? real() : nullptr;
}

extern "C" BOOL WINAPI DllMain(HINSTANCE dll, DWORD reason, LPVOID) {
    if (reason == DLL_PROCESS_ATTACH) {
        g_self = dll;
        DisableThreadLibraryCalls(dll);
    }
    return TRUE;
}
