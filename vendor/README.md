# Vendor Folder

Third-party source checkouts live here locally and are intentionally ignored by git.

Current optional native UI experiments may use:

- `vendor/RE-UE4SS`
- `vendor/UE4SSCPPTemplate`

Both currently depend on the RE-UE4SS Unreal pseudo-source submodule at `deps/first/Unreal`.
At the time of writing, the submodule URL in upstream metadata is:

```text
git@github.com:Re-UE4SS/UEPseudo.git
```

That repository is not publicly reachable from this machine, so the UE4SS C++ GameHost path cannot finish building until a working replacement or populated checkout is provided.
