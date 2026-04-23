{
  lib,
  stdenvNoCC,
  fetchurl,
  installShellFiles,
  versionCheckHook,
  writableTmpDirAsHomeHook,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "chainctl";
  version = "0.2.260";

  # Upstream distributes bare, statically-linked Go binaries under
  # https://dl.enforce.dev/chainctl/<version>/<file>.  The installer documented
  # at https://edu.chainguard.dev/chainguard/chainctl-usage/how-to-install-chainctl/
  # just curls the matching file for the host's uname output.
  src =
    finalAttrs.passthru.sources.${stdenvNoCC.hostPlatform.system}
      or (throw "chainctl: no binary available for ${stdenvNoCC.hostPlatform.system}");

  __structuredAttrs = true;
  strictDeps = true;

  dontUnpack = true;

  nativeBuildInputs = [ installShellFiles ];

  installPhase = ''
    runHook preInstall
    install -Dm0755 "$src" "$out/bin/chainctl"

    # chainctl doubles as a Docker credential helper when invoked as
    # "docker-credential-cgr" (it inspects argv[0]).  Expose the symlink so
    # Docker/podman can find it on $PATH without needing the mutable
    # `chainctl auth configure-docker` step.
    ln -s chainctl "$out/bin/docker-credential-cgr"

    runHook postInstall
  '';

  # chainctl reads XDG config on startup, so both the completion generator
  # here and the install-check version probe below need a writable $HOME;
  # the latter gets one from writableTmpDirAsHomeHook.
  postInstall = lib.optionalString (stdenvNoCC.buildPlatform.canExecute stdenvNoCC.hostPlatform) ''
    export HOME=$TMPDIR
    installShellCompletion --cmd chainctl \
      --bash <($out/bin/chainctl completion bash) \
      --fish <($out/bin/chainctl completion fish) \
      --zsh  <($out/bin/chainctl completion zsh)
  '';

  # Upstream already ships a stripped binary (built with `-s -w`); there is
  # nothing for us to strip, and skipping the phase avoids potential issues
  # on darwin where restripping can invalidate code signatures.
  dontStrip = true;

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    writableTmpDirAsHomeHook
    versionCheckHook
  ];
  versionCheckKeepEnvironment = [ "HOME" ];
  versionCheckProgramArg = "version";

  passthru = {
    # Per-platform fetchurl derivations live in passthru so update-source-version
    # can address them individually via --source-key=sources.<system>.
    sources =
      let
        base = "https://dl.enforce.dev/chainctl/${finalAttrs.version}";
      in
      {
        x86_64-linux = fetchurl {
          url = "${base}/chainctl_linux_x86_64";
          hash = "sha256-fkKzm40mFEFkPI6fUi5vgziJ9N6BO34cEX28+Yf3tbQ=";
        };
        aarch64-linux = fetchurl {
          url = "${base}/chainctl_linux_arm64";
          hash = "sha256-X0ytQUKEGbVaalklXzYjIBd7cBEOtFyi6OSPZONPRGk=";
        };
        x86_64-darwin = fetchurl {
          url = "${base}/chainctl_darwin_x86_64";
          hash = "sha256-cqwAHw/DpC50hvQqSF+Y1l1iEmltNeWDfbMqmMpwS1g=";
        };
        aarch64-darwin = fetchurl {
          url = "${base}/chainctl_darwin_arm64";
          hash = "sha256-A1zWFvnqbQ/2F9deIttu4MHGRxLHuYHpWYo6LCeuxMU=";
        };
      };

    updateScript = ./update.sh;
  };

  meta = {
    description = "Command-line interface for the Chainguard platform";
    homepage = "https://edu.chainguard.dev/chainguard/chainctl/";
    downloadPage = "https://dl.enforce.dev/chainctl/";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = with lib.maintainers; [ CodeCorrupt ];
    mainProgram = "chainctl";
    platforms = lib.attrNames finalAttrs.passthru.sources;
  };
})
