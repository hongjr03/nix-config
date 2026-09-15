{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  gitUpdater,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "rime-frost";
  version = "1.0.4";

  strictDeps = true;
  __structuredAttrs = true;

  src = fetchFromGitHub {
    owner = "gaboolic";
    repo = "rime-frost";
    tag = finalAttrs.version;
    hash = "sha256-1yxbLuVcCqgHGS14AecbVL7AQFGC/wbFO7US3Onz/R0=";
  };

  installPhase = ''
    runHook preInstall

    rm -rf others README.md .git*

    mv default.yaml rime_frost_suggestion.yaml

    mkdir -p $out/share
    cp -r . $out/share/rime-data

    runHook postInstall
  '';

  passthru.updateScript = gitUpdater { ignoredVersions = "nightly"; };

  meta = {
    description = "Simplified Chinese Rime schema with retrained word frequencies";
    homepage = "https://github.com/gaboolic/rime-frost";
    license = lib.licenses.gpl3Only;
  };
})
