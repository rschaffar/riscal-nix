// SPDX-License-Identifier: MIT
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicReference;

import javafx.application.Platform;
import javafx.scene.Scene;
import javafx.scene.control.Label;
import org.eclipse.gef.fx.swt.canvas.FXCanvasEx;
import org.eclipse.swt.SWT;
import org.eclipse.swt.browser.Browser;
import org.eclipse.swt.browser.ProgressAdapter;
import org.eclipse.swt.browser.ProgressEvent;
import org.eclipse.swt.layout.FillLayout;
import org.eclipse.swt.widgets.Display;
import org.eclipse.swt.widgets.Shell;

/** Local-content smoke test for the visualization and embedded-help runtimes. */
public final class RiscalRuntimeCheck {
  public static void main(String[] args) {
    Display display = new Display();
    try {
      Shell shell = new Shell(display);
      shell.setLayout(new FillLayout(SWT.VERTICAL));
      shell.setSize(640, 480);
      FXCanvasEx canvas = new FXCanvasEx(shell, SWT.NONE);
      AtomicBoolean javafxReady = new AtomicBoolean();
      AtomicReference<Throwable> javafxFailure = new AtomicReference<>();
      Platform.runLater(() -> {
        try {
          canvas.setScene(new Scene(new Label("RISCAL visualization runtime")));
          javafxReady.set(true);
        } catch (Throwable failure) {
          javafxFailure.set(failure);
        }
      });

      Browser browser = new Browser(shell, SWT.WEBKIT);
      AtomicBoolean webkitReady = new AtomicBoolean();
      browser.addProgressListener(new ProgressAdapter() {
        @Override
        public void completed(ProgressEvent event) {
          webkitReady.set(true);
        }
      });
      browser.setText("<html><body><p id='check'>RISCAL help runtime</p></body></html>");
      shell.open();

      long deadline = System.nanoTime() + 30_000_000_000L;
      while (!javafxReady.get() || !webkitReady.get()) {
        if (javafxFailure.get() != null) {
          throw new AssertionError("JavaFX scene failed", javafxFailure.get());
        }
        if (System.nanoTime() > deadline) {
          throw new AssertionError("Timed out: JavaFX=" + javafxReady + ", WebKit=" + webkitReady);
        }
        if (!display.readAndDispatch()) {
          // A bounded wait also catches a missing WebKit completion event.
          try {
            Thread.sleep(10);
          } catch (InterruptedException interrupted) {
            throw new AssertionError(interrupted);
          }
        }
      }
      Object text = browser.evaluate("return document.getElementById('check').textContent;");
      if (!"RISCAL help runtime".equals(text)) {
        throw new AssertionError("Unexpected WebKit document: " + text);
      }
      shell.dispose();
      System.out.println("JavaFX/GEF SWT scene and WebKit local HTML checks passed");
    } finally {
      Platform.exit();
      display.dispose();
    }
  }
}
