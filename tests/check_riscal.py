# SPDX-License-Identifier: MIT
"""Exercise the packaged launcher and solvers without activating a NixOS system."""

from pathlib import Path
import shutil
import subprocess
import sys
import time


package = Path(sys.argv[1])
launcher = package / "bin/riscal"


def run(*args):
    result = subprocess.run(
        [str(arg) for arg in args],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        timeout=90,
    )
    print(result.stdout, flush=True)
    assert result.returncode == 0, (args, result.returncode)
    return result.stdout


assert (package / "bin/RISCAL").resolve() == launcher.resolve()
assert (package / "share/applications/riscal.desktop").is_file()
assert (package / "share/riscal/doc/main.pdf").is_file()

# The caller's directory and paths containing spaces must survive the wrapper.
workspace = Path("course work")
workspace.mkdir()
example = workspace / "gcd example.txt"
shutil.copyfile(package / "share/riscal/spec/gcd.txt", example)
output = run(launcher, "-nogui", "-opt-dv", "3", "-e", "gcdp", example)
assert "SUCCESS termination." in output

for solver in ("boolector", "cvc4", "cvc5", "vampire", "yices-smt2", "z3"):
    run(package / "libexec/riscal" / solver, "--version")

# Exercise the legacy SMT default-directory fix from outside the package.
spec = workspace / "solver check.txt"
spec.write_text("theorem reflexive(x:ℕ[3]) ⇔ x=x;\n")
for solver in ("yices", "z3", "cvc4", "boolector"):
    output = run(launcher, "-nogui", "-smt", "-smt-solver", solver, "-e", "reflexive", spec)
    assert "ERROR" not in output and "Exception" not in output, output
    assert "The SMT solver" in output and "Theorem is valid" in output, output
    assert "SUCCESS termination." in output, output

# An actual visible SWT top-level window proves the packaged JNI can load.
# Physical GPU rendering and the online manual need interactive acceptance testing.
with Path("gui.log").open("w+") as log:
    app = subprocess.Popen(
        [str(launcher), str(example)],
        stdin=subprocess.DEVNULL,
        stdout=log,
        stderr=subprocess.STDOUT,
        start_new_session=True,
    )
    try:
        deadline = time.monotonic() + 40
        while time.monotonic() < deadline:
            assert app.poll() is None, f"RISCAL GUI exited with {app.returncode}"
            found = subprocess.run(
                ["xdotool", "search", "--onlyvisible", "--name", "RISCAL"],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                timeout=5,
            )
            if found.returncode == 0 and found.stdout.strip():
                print("Visible RISCAL SWT window found", flush=True)
                break
            time.sleep(0.25)
        else:
            raise AssertionError("No visible RISCAL window before timeout")
    finally:
        if app.poll() is None:
            app.terminate()
        try:
            app.wait(timeout=10)
        except subprocess.TimeoutExpired:
            app.kill()
            app.wait(timeout=5)
        log.seek(0)
        diagnostics = log.read()
        print(diagnostics, flush=True)
        assert "UnsatisfiedLinkError" not in diagnostics, diagnostics
        assert "Exception in thread" not in diagnostics, diagnostics

print("RISCAL CLI, bundled solvers, SMT and virtual-display startup checks passed")
