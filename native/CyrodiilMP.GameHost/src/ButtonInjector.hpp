#pragma once

namespace CyrodiilMP::ButtonInjector {

// Attempt to inject a MULTIPLAYER button into the main menu layout.
// Returns true on success; false if the widget tree is not ready yet
// (caller should retry next frame).
// Once it returns true, further calls are no-ops.
bool TryInject();

} // namespace CyrodiilMP::ButtonInjector
