let

  formatArg =
    x:
    if x == null then
      [ ]
    else
      if (builtins.isList x) then
        x else [ x ];
in

{
  mkCljCli =
    { jdkDrv
    , java-opts ? [ ]
    , extra-args ? [ ]
    }:
    builtins.filter
      (s: builtins.stringLength s != 0)
      (
        [
          "${jdkDrv.jdk}/bin/java"
        ]
        ++ (formatArg java-opts) ++
        [
          "-jar"
          "${jdkDrv.jarPath}"
        ]
        ++ (formatArg extra-args)
      );
}
