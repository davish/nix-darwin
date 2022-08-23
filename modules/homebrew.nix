# Created by: https://github.com/malob
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.homebrew;

  brewfileFile = pkgs.writeText "Brewfile" cfg.brewfile;

  brew-bundle-command = concatStringsSep " " (
    optional (!cfg.autoUpdate) "HOMEBREW_NO_AUTO_UPDATE=1"
    ++ [ "brew bundle --file='${brewfileFile}' --no-lock" ]
    ++ optional (cfg.cleanup == "uninstall" || cfg.cleanup == "zap") "--cleanup"
    ++ optional (cfg.cleanup == "zap") "--zap"
  );

  # Brewfile creation helper functions -------------------------------------------------------------

  mkBrewfileSectionString = heading: entries: optionalString (entries != [ ]) ''
    # ${heading}
    ${concatMapStringsSep "\n" (v: v.brewfileLine or v) entries}

  '';

  mkBrewfileLineValueString = v:
    if isInt v then toString v
    else if isFloat v then strings.floatToString v
    else if isBool v then boolToString v
    else if isString v then ''"${v}"''
    else if isAttrs v then "{ ${concatStringsSep ", " (mapAttrsToList (n: v': "${n}: ${mkBrewfileLineValueString v'}") v)} }"
    else if isList v then "[${concatMapStringsSep ", " mkBrewfileLineValueString v}]"
    else abort "The value: ${generators.toPretty v} is not a valid Brewfile value.";

  mkBrewfileLineOptionsListString = attrs:
    concatStringsSep ", " (mapAttrsToList (n: v: "${n}: ${v}") attrs);


  # Submodule helper functions ---------------------------------------------------------------------

  mkNullOrBoolOption = args: mkOption (args // {
    type = types.nullOr types.bool;
    default = null;
  });

  mkNullOrStrOption = args: mkOption (args // {
    type = types.nullOr types.str;
    default = null;
  });

  mkBrewfileLineOption = mkOption {
    type = types.nullOr types.str;
    visible = false;
    internal = true;
    readOnly = true;
  };

  mkProcessedSubmodConfig = attrs: mapAttrs (_: mkBrewfileLineValueString)
    (filterAttrsRecursive (n: v: n != "_module" && n != "brewfileLine" && v != null) attrs);


  # Submodules -------------------------------------------------------------------------------------
  # Option values and descriptions of Brewfile entries are sourced/derived from:
  #   * `brew` manpage: https://docs.brew.sh/Manpage
  #   * `brew bundle` source files (at https://github.com/Homebrew/homebrew-bundle/tree/9fffe077f1a5a722ed5bd26a87ed622e8cb64e0c):
  #     * lib/bundle/dsl.rb
  #     * lib/bundle/{brew,cask,tap}_installer.rb
  #     * spec/bundle/{brew,cask,tap}_installer_spec.rb

  tapOptions = { config, ... }: {
    options = {
      name = mkOption {
        type = types.str;
        example = "homebrew/cask-fonts";
        description = ''
          When <option>clone_target</option> is unspecified, this is the name of a formula
          repository to tap from GitHub using HTTPS. For example, <literal>"user/repo"</literal>
          will tap https://github.com/user/homebrew-repo.
        '';
      };
      clone_target = mkNullOrStrOption {
        description = ''
          Use this option to tap a formula repository from anywhere, using any transport protocol
          that <command>git</command> handles. When <option>clone_target</option> is specified, taps
          can be cloned from places other than GitHub and using protocols other than HTTPS, e.g.,
          SSH, git, HTTP, FTP(S), rsync.
        '';
      };
      force_auto_update = mkNullOrBoolOption {
        description = ''
          Whether to auto-update the tap even if it is not hosted on GitHub. By default, only taps
          hosted on GitHub are auto-updated (for performance reasons).
        '';
      };

      brewfileLine = mkBrewfileLineOption;
    };

    config =
      let
        sCfg = mkProcessedSubmodConfig config;
      in
      {
        brewfileLine =
          "tap ${sCfg.name}"
          + optionalString (sCfg ? clone_target) ", ${sCfg.clone_target}"
          + optionalString (sCfg ? force_auto_update)
            ", force_auto_update: ${sCfg.force_auto_update}";
      };
  };

  # Sourced from https://docs.brew.sh/Manpage#global-cask-options
  # and valid values for `HOMEBREW_CASK_OPTS`.
  caskArgsOptions = { config, ... }: {
    options = {
      appdir = mkNullOrStrOption {
        description = ''
          Target location for Applications.

          Homebrew's default is <filename class='directory'>/Applications</filename>.
        '';
      };
      colorpickerdir = mkNullOrStrOption {
        description = ''
          Target location for Color Pickers.

          Homebrew's default is <filename class='directory'>~/Library/ColorPickers</filename>.
        '';
      };
      prefpanedir = mkNullOrStrOption {
        description = ''
          Target location for Preference Panes.

          Homebrew's default is <filename class='directory'>~/Library/PreferencePanes</filename>.
        '';
      };
      qlplugindir = mkNullOrStrOption {
        description = ''
          Target location for QuickLook Plugins.

          Homebrew's default is <filename class='directory'>~/Library/QuickLook</filename>.
        '';
      };
      mdimporterdir = mkNullOrStrOption {
        description = ''
          Target location for Spotlight Plugins.

          Homebrew's default is <filename class='directory'>~/Library/Spotlight</filename>.
        '';
      };
      dictionarydir = mkNullOrStrOption {
        description = ''
          Target location for Dictionaries.

          Homebrew's default is <filename class='directory'>~/Library/Dictionaries</filename>.
        '';
      };
      fontdir = mkNullOrStrOption {
        description = ''
          Target location for Fonts.

          Homebrew's default is <filename class='directory'>~/Library/Fonts</filename>.
        '';
      };
      servicedir = mkNullOrStrOption {
        description = ''
          Target location for Services.

          Homebrew's default is <filename class='directory'>~/Library/Services</filename>.
        '';
      };
      input_methoddir = mkNullOrStrOption {
        description = ''
          Target location for Input Methods.

          Homebrew's default is <filename class='directory'>~/Library/Input Methods</filename>.
        '';
      };
      internet_plugindir = mkNullOrStrOption {
        description = ''
          Target location for Internet Plugins.

          Homebrew's default is <filename class='directory'>~/Library/Internet Plug-Ins</filename>.
        '';
      };
      audio_unit_plugindir = mkNullOrStrOption {
        description = ''
          Target location for Audio Unit Plugins.

          Homebrew's default is <filename class='directory'>~/Library/Audio/Plug-Ins/Components</filename>.
        '';
      };
      vst_plugindir = mkNullOrStrOption {
        description = ''
          Target location for VST Plugins.

          Homebrew's default is <filename class='directory'>~/Library/Audio/Plug-Ins/VST</filename>.
        '';
      };
      vst3_plugindir = mkNullOrStrOption {
        description = ''
          Target location for VST3 Plugins.

          Homebrew's default is <filename class='directory'>~/Library/Audio/Plug-Ins/VST3</filename>.
        '';
      };
      screen_saverdir = mkNullOrStrOption {
        description = ''
          Target location for Screen Savers.

          Homebrew's default is <filename class='directory'>~/Library/Screen Savers</filename>.
        '';
      };
      language = mkNullOrStrOption {
        description = ''
          Comma-separated list of language codes to prefer for cask installation. The first matching
          language is used, otherwise it reverts to the cask’s default language. The default value
          is the language of your system.
        '';
        example = "zh-TW";
      };
      require_sha = mkNullOrBoolOption {
        description = "Whether to require cask(s) to have a checksum.";
      };
      no_quarantine = mkNullOrBoolOption {
        description = "Whether to disable quarantining of downloads.";
      };
      no_binaries = mkNullOrBoolOption {
        description = "Whether to disable linking of helper executables.";
      };

      brewfileLine = mkBrewfileLineOption;
    };

    config =
      let
        sCfg = mkProcessedSubmodConfig config;
      in
      {
        brewfileLine = if sCfg == { } then null else "cask_args ${mkBrewfileLineOptionsListString sCfg}";
      };
  };

  brewOptions = { config, ... }: {
    options = {
      name = mkOption {
        type = types.str;
        description = "The name of the formula to install.";
      };
      args = mkOption {
        type = with types; nullOr (listOf str);
        default = null;
        description = ''
          Arguments flags to pass to <command>brew install</command>. Values should not include the
          leading <literal>"--"</literal>.
        '';
      };
      conflicts_with = mkOption {
        type = with types; nullOr (listOf str);
        default = null;
        description = ''
          List of formulae that should be unlinked and their services stopped (if they are
          installed).
        '';
      };
      restart_service = mkOption {
        type = with types; nullOr (either bool (enum [ "changed" ]));
        default = null;
        description = ''
          Whether to run <command>brew services restart</command> for the formula and register it to
          launch at login (or boot). If set to <literal>"changed"</literal>, the service will only
          be restarted on version changes.

          Homebrew's default is <literal>false</literal>.
        '';
      };
      start_service = mkNullOrBoolOption {
        description = ''
          Whether to run <command>brew services start</command> for the formula and register it to
          launch at login (or boot).

          Homebrew's default is <literal>false</literal>.
        '';
      };
      link = mkNullOrBoolOption {
        description = ''
          Whether to link the formula to the Homebrew prefix. When this option is
          <literal>null</literal>, Homebrew will use it's default behavior which is to link the
          formula if it's currently unlinked and not keg-only, and to unlink the formula if it's
          currently linked and keg-only.
        '';
      };

      brewfileLine = mkBrewfileLineOption;
    };

    config =
      let
        sCfg = mkProcessedSubmodConfig config;
        sCfgSubset = removeAttrs sCfg [ "name" "restart_service" ];
      in
      {
        brewfileLine =
          "brew ${sCfg.name}"
          + optionalString (sCfgSubset != { }) ", ${mkBrewfileLineOptionsListString sCfgSubset}"
          # We need to handle the `restart_service` option seperately since it can be either bool
          # or the string value "changed".
          + optionalString (sCfg ? restart_service) (
            ", restart_service: " + (
              if isBool config.restart_service then sCfg.restart_service
              else ":${config.restart_service}"
            )
          );
      };
  };

  caskOptions = { config, ... }: {
    options = {
      name = mkOption {
        type = types.str;
        description = "The name of the cask to install.";
      };
      args = mkOption {
        type = types.nullOr (types.submodule caskArgsOptions);
        default = null;
      };
      greedy = mkNullOrBoolOption {
        description = ''
          Whether to always upgrade auto-updated or unversioned cask to the latest version even if
          it's already installed.
        '';
      };

      brewfileLine = mkBrewfileLineOption;
    };

    config =
      let
        sCfg = mkProcessedSubmodConfig config;
        sCfgSubset = removeAttrs sCfg [ "name" ];
      in
      {
        brewfileLine =
          "cask ${sCfg.name}"
          + optionalString (sCfgSubset != { }) ", ${mkBrewfileLineOptionsListString sCfgSubset}";
      };
  };
in

{
  # Interface --------------------------------------------------------------------------------------

  options.homebrew = {
    enable = mkEnableOption ''
      configuring your Brewfile, and installing/updating the formulas therein via
      the <command>brew bundle</command> command, using <command>nix-darwin</command>.

      Note that enabling this option does not install Homebrew. See the Homebrew
      <link xlink:href="https://brew.sh">website</link> for installation instructions
    '';

    autoUpdate = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to enable Homebrew to auto-update during <command>nix-darwin</command>
        activation. The default is <literal>false</literal> so that repeated invocations of
        <command>darwin-rebuild switch</command> are idempotent.
      '';
    };

    brewPrefix = mkOption {
      type = types.str;
      default = if pkgs.stdenv.hostPlatform.isAarch64 then "/opt/homebrew/bin" else "/usr/local/bin";
      defaultText = literalExpression ''
        if pkgs.stdenv.hostPlatform.isAarch64 then "/opt/homebrew/bin"
        else "/usr/local/bin"
      '';
      description = ''
        The path prefix where the <command>brew</command> executable is located. This will be set to
        the correct value based on your system's platform, and should only need to be changed if you
        manually installed Homebrew in a non-standard location.
      '';
    };

    cleanup = mkOption {
      type = types.enum [ "none" "uninstall" "zap" ];
      default = "none";
      example = "uninstall";
      description = ''
        This option manages what happens to formulas installed by Homebrew, that aren't present in
        the Brewfile generated by this module.

        When set to <literal>"none"</literal> (the default), formulas not present in the generated
        Brewfile are left installed.

        When set to <literal>"uninstall"</literal>, <command>nix-darwin</command> invokes
        <command>brew bundle [install]</command> with the <command>--cleanup</command> flag. This
        uninstalls all formulas not listed in generate Brewfile, i.e.,
        <command>brew uninstall</command> is run for those formulas.

        When set to <literal>"zap"</literal>, <command>nix-darwin</command> invokes
        <command>brew bundle [install]</command> with the <command>--cleanup --zap</command>
        flags. This uninstalls all formulas not listed in the generated Brewfile, and if the
        formula is a cask, removes all files associated with that cask. In other words,
        <command>brew uninstall --zap</command> is run for all those formulas.

        If you plan on exclusively using <command>nix-darwin</command> to manage formulas installed
        by Homebrew, you probably want to set this option to <literal>"uninstall"</literal> or
        <literal>"zap"</literal>.
      '';
    };

    global.brewfile = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to enable Homebrew to automatically use the Brewfile in the Nix store that this
        module generates, when you manually invoke <command>brew bundle</command>.

        Implementation note: when enabled, this option sets the
        <literal>HOMEBREW_BUNDLE_FILE</literal> environment variable to the path of the Brewfile in
        the Nix store that this module generates, by adding it to
        <option>environment.variables</option>.
      '';
    };

    global.noLock = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to disable lockfile generation when you manually invoke
        <command>brew bundle [install]</command>. This is often desirable when
        <option>homebrew.global.brewfile</option> is enabled, since
        <command>brew bundle [install]</command> will try to write the lockfile in the Nix store,
        and complain that it can't (though the command will run successfully regardless).

        Implementation note: when enabled, this option sets the
        <literal>HOMEBREW_BUNDLE_NO_LOCK</literal> environment variable, by adding it to
        <option>environment.variables</option>.
      '';
    };

    taps = mkOption {
      type = with types; listOf (coercedTo str (name: { inherit name; }) (submodule tapOptions));
      default = [ ];
      example = literalExpression ''
        # Adapted examples from https://github.com/Homebrew/homebrew-bundle#usage
        [
          # `brew tap`
          "homebrew/cask"

          # `brew tap` with custom Git URL and arguments
          {
            name = "user/tap-repo";
            clone_target = "https://user@bitbucket.org/user/homebrew-tap-repo.git";
            force_auto_update = true;
          }
        ]
      '';
      description = ''
        Homebrew formula repositories to tap.

        Taps defined as strings, e.g., <literal>"user/repo"</literal>, are a shorthand for:

        <code>{ name = "user/repo"; }</code>
      '';
    };

    caskArgs = mkOption {
      type = types.submodule caskArgsOptions;
      default = { };
      example = literalExpression ''
        {
          appdir = "~/Applications";
          require_sha = true;
        }
      '';
      description = "Arguments to apply to all <option>homebrew.casks</option>.";
    };

    brews = mkOption {
      type = with types; listOf (coercedTo str (name: { inherit name; }) (submodule brewOptions));
      default = [ ];
      example = literalExpression ''
        # Adapted examples from https://github.com/Homebrew/homebrew-bundle#usage
        [
          # `brew install`
          "imagemagick"

          # `brew install --with-rmtp`, `brew services restart` on version changes
          {
            name = "denji/nginx/nginx-full";
            args = [ "with-rmtp" ];
            restart_service = "changed";
          }

          # `brew install`, always `brew services restart`, `brew link`, `brew unlink mysql` (if it is installed)
          {
            name = "mysql@5.6";
            restart_service = true;
            link = true;
            conflicts_with = [ "mysql" ];
          }
        ]
      '';
      description = ''
        Homebrew brews to install.

        Brews defined as strings, e.g., <literal>"imagemagick"</literal>, are a shorthand for:

        <code>{ name = "imagemagick"; }</code>
      '';
    };

    casks = mkOption {
      type = with types; listOf (coercedTo str (name: { inherit name; }) (submodule caskOptions));
      default = [ ];
      example = literalExpression ''
        # Adapted examples from https://github.com/Homebrew/homebrew-bundle#usage
        [
          # `brew install --cask`
          "google-chrome"

          # `brew install --cask --appdir=~/my-apps/Applications`
          {
            name = "firefox";
            args = { appdir = "~/my-apps/Applications"; };
          }

          # always upgrade auto-updated or unversioned cask to latest version even if already installed
          {
            name = "opera";
            greedy = true;
          }
        ]
      '';
      description = ''
        Homebrew casks to install.

        Casks defined as strings, e.g., <literal>"google-chrome"</literal>, are a shorthand for:

        <code>{ name = "google-chrome"; }</code>
      '';
    };

    masApps = mkOption {
      type = types.attrsOf types.ints.positive;
      default = { };
      example = literalExpression ''
        {
          "1Password for Safari" = 1569813296;
          Xcode = 497799835;
        }
      '';
      description = ''
        Applications to install from Mac App Store using <command>mas</command>.

        When this option is used, <literal>"mas"</literal> is automatically added to
        <option>homebrew.brews</option>.

        Note that you need to be signed into the Mac App Store for <command>mas</command> to
        successfully install and upgrade applications, and that unfortunately apps removed from this
        option will not be uninstalled automatically even if
        <option>homebrew.cleanup</option> is set to <literal>"uninstall"</literal>
        or <literal>"zap"</literal> (this is currently a limitation of Homebrew Bundle).

        For more information on <command>mas</command> see:
        <link xlink:href="https://github.com/mas-cli/mas">github.com/mas-cli/mas</link>.
      '';
    };

    whalebrews = mkOption {
      type = with types; listOf str;
      default = [ ];
      example = [ "whalebrew/wget" ];
      description = ''
        Docker images to install using <command>whalebrew</command>.

        When this option is used, <literal>"whalebrew"</literal> is automatically added to
        <option>homebrew.brews</option>.

        For more information on <command>whalebrew</command> see:
        <link xlink:href="https://github.com/whalebrew/whalebrew">github.com/whalebrew/whalebrew</link>.
      '';
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      example = ''
        # 'brew cask install' only if '/usr/libexec/java_home --failfast' fails
        cask "java" unless system "/usr/libexec/java_home --failfast"
      '';
      description = "Extra lines to be added verbatim to bottom of the generated Brewfile.";
    };

    brewfile = mkOption {
      type = types.str;
      visible = false;
      internal = true;
      readOnly = true;
      description = "String reprensentation of the generated Brewfile useful for debugging.";
    };
  };


  # Implementation ---------------------------------------------------------------------------------

  config = {
    homebrew.brews =
      optional (cfg.masApps != { }) "mas"
      ++ optional (cfg.whalebrews != [ ]) "whalebrew";

    homebrew.brewfile =
      "# Created by `nix-darwin`'s `homebrew` module\n\n"
      + mkBrewfileSectionString "Taps" cfg.taps
      + mkBrewfileSectionString "Arguments for all casks"
        (optional (cfg.caskArgs.brewfileLine != null) cfg.caskArgs)
      + mkBrewfileSectionString "Brews" cfg.brews
      + mkBrewfileSectionString "Casks" cfg.casks
      + mkBrewfileSectionString "Mac App Store apps"
        (mapAttrsToList (n: id: ''mas "${n}", id: ${toString id}'') cfg.masApps)
      + mkBrewfileSectionString "Docker containers" (map (v: ''whalebrew "${v}"'') cfg.whalebrews)
      + optionalString (cfg.extraConfig != "") ("# Extra config\n" + cfg.extraConfig);

    environment.variables = mkIf cfg.enable (
      optionalAttrs cfg.global.brewfile { HOMEBREW_BUNDLE_FILE = "${brewfileFile}"; }
      // optionalAttrs cfg.global.noLock { HOMEBREW_BUNDLE_NO_LOCK = "1"; }
    );

    system.activationScripts.homebrew.text = mkIf cfg.enable ''
      # Homebrew Bundle
      echo >&2 "Homebrew bundle..."
      if [ -f "${cfg.brewPrefix}/brew" ]; then
        PATH="${cfg.brewPrefix}":$PATH ${brew-bundle-command}
      else
        echo -e "\e[1;31merror: Homebrew is not installed, skipping...\e[0m" >&2
      fi
    '';
  };
}
