# SPDX-License-Identifier: MIT
{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  wrapGAppsHook3,
  copyDesktopItems,
  makeDesktopItem,
  unzip,
  zip,
  jdk21,
  openjfx21,
  gtk3,
  glib,
  libglvnd,
  libGLU,
  gmp,
  webkitgtk_4_1,
}:

let
  # Use nixpkgs' cached JDK with JavaFX modules integrated, rather than treating
  # OpenJFX's intermediate modular-sdk layout as a standalone module path.
  jdk = jdk21.override { enableJavaFX = true; };
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "riscal";
  version = "4.3.7";

  src = fetchurl {
    url = "https://www3.risc.jku.at/research/formal/software/RISCAL/release/RISCAL-${finalAttrs.version}.tgz";
    hash = "sha256-/HPPfxioWp2IhnJ4DWdYDEfb+UWyKqaZhv6TPvmXhLc=";
  };
  sourceRoot = ".";

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    wrapGAppsHook3
    copyDesktopItems
    unzip
    zip
    jdk
  ];
  buildInputs = [
    stdenv.cc.cc.lib
    jdk
    gtk3
    glib
    libglvnd
    gmp
  ];

  # SWT loads these with dlopen rather than ELF DT_NEEDED entries.
  appendRunpaths = map (package: "${lib.getLib package}/lib") [
    gtk3
    glib
    libglvnd
    libGLU
    webkitgtk_4_1
  ];
  dontWrapGApps = true;

  postPatch = ''
    # Upstream intends PATH lookup, but prepends "./" to the legacy SMT solvers.
    # Keep explicit user-selected directories working and defaults upgrade-safe.
    substituteInPlace src/riscal/smt/SMT.java \
      --replace-fail 'dirBoolector+File.separator+boolectorCommandName' '(dirBoolector.equals(".") ? boolectorCommandName : dirBoolector+File.separator+boolectorCommandName)' \
      --replace-fail 'dirZ3+File.separator+z3CommandName' '(dirZ3.equals(".") ? z3CommandName : dirZ3+File.separator+z3CommandName)' \
      --replace-fail 'dirYices+File.separator+yicesCommandName' '(dirYices.equals(".") ? yicesCommandName : dirYices+File.separator+yicesCommandName)' \
      --replace-fail 'dirCVC4+File.separator+cvc4CommandName' '(dirCVC4.equals(".") ? cvc4CommandName : dirCVC4+File.separator+cvc4CommandName)'
    substituteInPlace src/riscal/swt/TopWindow.java \
      --replace-fail 'http://www.risc.jku.at/research/formal/software/RISCAL/manual' 'https://www3.risc.jku.at/research/formal/software/RISCAL/manual'
  '';

  buildPhase = ''
    runHook preBuild
    mkdir classes
    find src -name '*.java' -print0 | xargs -0 javac --release 21 \
      --add-modules javafx.controls \
      -cp 'lib/*:lib/swt64/*:${openjfx21}/modules_libs/javafx.graphics/javafx-swt.jar' \
      -d classes
    # Retain the upstream jar's resources, replacing its classes with our build.
    jar uf lib/riscal.jar -C classes .
    runHook postBuild
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "riscal";
      desktopName = "RISCAL";
      genericName = "RISC Algorithm Language";
      comment = "Specify, execute and check mathematical algorithms";
      exec = "riscal";
      icon = "applications-science";
      categories = [
        "Education"
        "Science"
        "Development"
      ];
      terminal = false;
    })
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/riscal" "$out/lib/riscal" "$out/libexec/riscal" "$out/bin"
    cp -r lib doc spec README CHANGES COPYING "$out/share/riscal/"
    cp ${openjfx21}/modules_libs/javafx.graphics/javafx-swt.jar "$out/share/riscal/lib/"
    install -m755 etc/{boolector,cvc4,cvc5,vampire,yices-smt2,z3} "$out/libexec/riscal/"

    # Extract matching JNI libraries so autoPatchelf can fix their dependencies.
    # Remove them from the jar: SWT must never extract unpatched copies at runtime.
    unzip -q "$out/share/riscal/lib/swt64/swt.jar" '*.so' -d "$out/lib/riscal"
    zip -qd "$out/share/riscal/lib/swt64/swt.jar" '*.so'
    # Upstream explicitly selects GTK3; its unused GTK4 library is not needed.
    rm "$out/lib/riscal/"libswt-pi4-*.so

    runHook postInstall
  '';

  preFixup = ''
    addAutoPatchelfSearchPath ${jdk.home}/lib
    makeWrapper ${jdk}/bin/java "$out/bin/riscal" \
      "''${gappsWrapperArgs[@]}" \
      --set SWT_GTK3 1 \
      --set GDK_BACKEND x11 \
      --set WEBKIT_DISABLE_COMPOSITING_MODE 1 \
      --prefix PATH : "$out/libexec/riscal" \
      --add-flags "-Djava.library.path=$out/lib/riscal:${jdk.home}/lib" \
      --add-flags "--add-modules javafx.controls" \
      --add-flags "-cp $out/share/riscal/lib/*:$out/share/riscal/lib/swt64/*" \
      --add-flags "-Xmx2G -Xms256m -Xss64M riscal.Main -visual"
    ln -s riscal "$out/bin/RISCAL"
  '';

  passthru = { inherit jdk; };

  meta = {
    description = "Specification, execution and validation of mathematical algorithms";
    homepage = "https://www3.risc.jku.at/research/formal/software/RISCAL/";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "riscal";
    sourceProvenance = [
      lib.sourceTypes.fromSource
      lib.sourceTypes.binaryBytecode
      lib.sourceTypes.binaryNativeCode
    ];
  };
})
