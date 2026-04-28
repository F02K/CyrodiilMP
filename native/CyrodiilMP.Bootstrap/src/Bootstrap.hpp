#pragma once

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

namespace CyrodiilMP::Bootstrap {

void Start(HMODULE self_module);
void Stop();

}
