# Vendor Folder

Third-party source checkouts live here locally and are intentionally ignored by git.

Current optional native UI and research experiments may use:

- `vendor/NirnLabUIPlatformOR`
- `vendor/vcpkg` for the F02K vcpkg fork used to build/package NirnLabUIPlatformOR
- `vendor/RE-UE4SS` for historical/research-only UE4SS C++ investigation
- `vendor/UE4SSCPPTemplate` for historical UE4SS C++ template investigation

`vendor/NirnLabUIPlatformOR` is a Git submodule pointing at the F02K Oblivion
Remastered fork:

```text
https://github.com/F02K/NirnLabUIPlatformOR
```

The submodule currently tracks the `oblivion-remastered-host` branch. That fork
was created from upstream:

```text
https://github.com/kkEngine/NirnLabUIPlatform
```

Upstream license: MIT. Keep the upstream `LICENSE` file and credit intact in
the fork.
The fork repository is named `NirnLabUIPlatformOR`, where `OR` means Oblivion
Remastered. It is an Oblivion Remastered-only porting target; Skyrim/SKSE
compatibility does not need to be preserved. Oblivion Remastered-specific
changes should be documented in `vendor/NirnLabUIPlatformOR/OBLIVION_REMASTERED.md`.

`vendor/vcpkg` is a Git submodule pointing at:

```text
https://github.com/F02K/vcpkg
```

The NirnLabUIPlatformOR build script uses this vendored checkout by default and
bootstraps `vcpkg.exe` automatically when needed.

The RE-UE4SS-based paths currently depend on the Unreal pseudo-source submodule at `deps/first/Unreal`.
At the time of writing, the submodule URL in upstream metadata is:

```text
git@github.com:Re-UE4SS/UEPseudo.git
```

That repository is not publicly reachable from this machine. CyrodiilMP no longer uses an RE-UE4SS C++ runtime path, so keep this checkout only for historical research.
