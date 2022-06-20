{ stdenv, runtimeShell, jdk17_headless }:

{ jdkBase ? jdk17_headless, name ? "customJDK", version ? "DEV"
, multiReleaseTargetJdkVersion ? null, ignoreMissingDeps ? false, cljDrv ? null
  # Manually set the modules
, jdkModules ? null, locales ? null, ... }@attrs:

let

  extra-attrs = builtins.removeAttrs attrs [
    "jdkBase"
    "name"
    "version"
    "cljDrv"
    "jdkModules"
    "locales"
  ];

  template = ''
    #!${runtimeShell}

    exec "@jdk@/bin/java" \
        -jar "@jar@" "$@"
  '';

in stdenv.mkDerivation ({
  inherit locales template;
  name = if cljDrv == null then name else cljDrv.pname;
  version = if cljDrv == null then version else cljDrv.version;

  passAsFile = [ "template" ];
  stripDebugFlags = [ "--strip-unneeded" ];
  nativeBuildInputs = [ jdkBase ];

  outputs = if cljDrv == null then [ "out" ] else [ "out" "jdk" ];

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    if [[ -z "$jdkModules" ]]; then
  '' +

    (if cljDrv == null then ''
      export jdkModules="java.base"
    '' else ''
        export jarPath=$(cat ${cljDrv}/nix-support/jar-path)
        export jdkModules=$(jdeps \
            ${
              if multiReleaseTargetJdkVersion == null then
                ""
              else
                "--multi-release ${toString multiReleaseTargetJdkVersion}"
            } \
      ${if ignoreMissingDeps then "--ignore-missing-deps" else ""} \
      --print-module-deps "$jarPath")
                '') +

    ''
      fi

      if [[ -n "$locales" && "$jdkModules" != *"jdk.localedata"* ]]; then
        export jdkModules="''${jdkModules},jdk.localedata"
      fi

      jlink \
        --no-header-files \
        --no-man-pages \
        --add-modules ''${jdkModules} \
        ${if locales == null then "" else "--include-locales ${locales}"} \
        --compress 2 \
        --output ${if cljDrv == null then "$out" else "$jdk"}
    '' +

    (if cljDrv == null then
      ""
    else ''
      mkdir -p $out/bin

      binary="$out/bin/${cljDrv.pname}"

      substitute "$templatePath" "$binary" \
        --subst-var-by jar "$jarPath" \
        --subst-var-by jdk "$jdk"
      chmod +x "$binary"
    '') +

    ''
      runHook postInstall
    '';

} // extra-attrs)
