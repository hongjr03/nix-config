# Refresh pi's opencode-go model catalog from opencode's live endpoint.
#
# pi learns the catalog from two frozen sources — the snapshot baked into the
# package and the pi.dev catalog — and both lag opencode's actual lineup, which
# churns fast (stealth and free preview models come and go within weeks). So the
# models are rewritten into ~/.pi/agent/models-store.json directly. Reads a
# public endpoint, no credentials involved.

{
  writeShellApplication,
  python3,
}:

writeShellApplication {
  name = "sync-opencode-go-models";
  runtimeInputs = [ python3 ];
  text = "exec python3 ${./sync-opencode-go.py}";
}
