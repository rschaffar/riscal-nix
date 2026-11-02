# SPDX-License-Identifier: MIT
{ pkgs, riscal }:

pkgs.runCommand "check-riscal"
  {
    nativeBuildInputs = [
      pkgs.python3
      pkgs.xvfb-run
      pkgs.xdotool
      pkgs.dbus
      riscal.jdk
    ];
  }
  ''
    export HOME="$TMPDIR/home"
    export XDG_RUNTIME_DIR="$TMPDIR/runtime"
    mkdir -m700 "$HOME" "$XDG_RUNTIME_DIR"
    # A virtual display does not establish physical GPU behavior.
    export _JAVA_OPTIONS=-Dprism.order=sw
    dbus-run-session --config-file=${pkgs.dbus}/share/dbus-1/session.conf -- \
      xvfb-run -a python ${./check_riscal.py} ${riscal}

    classpath='${riscal}/share/riscal/lib/*:${riscal}/share/riscal/lib/swt64/*'
    cp ${./RiscalRuntimeCheck.java} RiscalRuntimeCheck.java
    javac --add-modules javafx.controls -cp "$classpath" RiscalRuntimeCheck.java
    # WebKit's nested process sandbox cannot run inside the Nix build sandbox.
    # Disable it only for this isolated local-HTML test, never in the launcher.
    SWT_GTK3=1 GDK_BACKEND=x11 WEBKIT_DISABLE_COMPOSITING_MODE=1 \
      WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1 \
      dbus-run-session --config-file=${pkgs.dbus}/share/dbus-1/session.conf -- \
      xvfb-run -a timeout 60 java --add-modules javafx.controls \
        -Djava.library.path=${riscal}/lib/riscal:${riscal.jdk.home}/lib \
        -cp ".:$classpath" RiscalRuntimeCheck
    touch "$out"
  ''
