# nixpkgs ships Paseo's CLI and daemon, but its build drops node-pty's native
# addon. The daemon traces its own runtime closure and looks the addon up at
# `node_modules/node-pty/prebuilds/<plat>/`, while npm's workspace hoisting
# for this lockfile puts node-pty under `packages/server/node_modules`. The
# addon never reaches `$out`, and `paseo-server` aborts on boot with
#     Failed to load native module: pty.node ...
#
# Copy whatever prebuilt addon the trace missed from the build tree into the
# packaged tree. The addon is N-API and resolves libstdc++ through the node
# process that dlopens it, so it needs no patching.
#
# Note this rebuilds the derivation locally instead of substituting it; the
# expensive npm dependency tree is still fetched from the binary cache.
{ paseo }:

paseo.overrideAttrs (old: {
  postInstall = (old.postInstall or "") + ''
    while IFS= read -r addon; do
      install -Dm0644 "''${addon#./}" "$out/lib/paseo/''${addon#./}"
    done < <(find . -path '*/node_modules/node-pty/prebuilds/*/pty.node')
  '';
})
