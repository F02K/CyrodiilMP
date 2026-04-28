#include "include/GameHostMod.hpp"

// ─── UE4SS C++ Mod entry points ──────────────────────────────────────────────
//
// UE4SS discovers the DLL at Mods/CyrodiilMP.GameHost/dlls/main.dll and calls
// start_mod() to instantiate the mod object.  uninstall_mod() is called on
// game shutdown.
//
// These must be exported as plain C symbols (no mangling).

extern "C" {

__declspec(dllexport)
RC::CppUserModBase* start_mod()
{
    return new CyrodiilMP::GameHostMod();
}

__declspec(dllexport)
void uninstall_mod(RC::CppUserModBase* mod)
{
    delete mod;
}

} // extern "C"
