#pragma once

namespace CyrodiilMP::ButtonInjector {

// Attempt to relabel the existing Credits button to MULTIPLAYER.
// Returns true on success; false if the menu widget tree is not ready yet.
// Once it returns true, further calls are no-ops.
bool TryInject();

} // namespace CyrodiilMP::ButtonInjector
