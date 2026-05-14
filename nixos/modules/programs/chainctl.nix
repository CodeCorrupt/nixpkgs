{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.chainctl;
in
{
  options.programs.chainctl = {
    enable = lib.mkEnableOption "chainctl, the Chainguard platform CLI";

    package = lib.mkPackageOption pkgs "chainctl" { };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
  };

  meta.maintainers = with lib.maintainers; [ CodeCorrupt ];
}
