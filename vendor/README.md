# Vendor Folder

Third-party source checkouts live here locally and are intentionally ignored by git.

Current optional native UI experiments may use:

- `vendor/RE-UE4SS`
- `vendor/UE4SSCPPTemplate`
- `vendor/NirnLabUIPlatform`

`vendor/NirnLabUIPlatform` is a Git submodule pointing at the F02K fork:

```text
https://github.com/F02K/NirnLabUIPlatform
```

The submodule currently tracks the `oblivion-remastered-host` branch. That fork
was created from upstream:

```text
https://github.com/kkEngine/NirnLabUIPlatform
```

Upstream license: MIT. Keep the upstream `LICENSE` file and credit intact in
the fork.
Oblivion Remastered-specific changes should be documented in
`vendor/NirnLabUIPlatform/OBLIVION_REMASTERED.md`.

The RE-UE4SS-based paths currently depend on the Unreal pseudo-source submodule at `deps/first/Unreal`.
At the time of writing, the submodule URL in upstream metadata is:

```text
git@github.com:Re-UE4SS/UEPseudo.git
```

That repository is not publicly reachable from this machine, so the UE4SS C++ GameHost path cannot finish building until a working replacement or populated checkout is provided.
