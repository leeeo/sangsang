// Phosphor Icons (MIT) shipped as raw SVG strings by @phosphor-icons/core.
import arrowCounterClockwise from "@phosphor-icons/core/assets/regular/arrow-counter-clockwise.svg?raw";
import check from "@phosphor-icons/core/assets/regular/check.svg?raw";
import downloadSimple from "@phosphor-icons/core/assets/regular/download-simple.svg?raw";
import fileXls from "@phosphor-icons/core/assets/regular/file-xls.svg?raw";
import flask from "@phosphor-icons/core/assets/regular/flask.svg?raw";
import info from "@phosphor-icons/core/assets/regular/info.svg?raw";
import lockSimple from "@phosphor-icons/core/assets/regular/lock-simple.svg?raw";
import uploadSimple from "@phosphor-icons/core/assets/regular/upload-simple.svg?raw";
import warningCircle from "@phosphor-icons/core/assets/regular/warning-circle.svg?raw";
import x from "@phosphor-icons/core/assets/regular/x.svg?raw";

const SOURCES = {
  arrowCounterClockwise,
  check,
  downloadSimple,
  fileXls,
  flask,
  info,
  lockSimple,
  uploadSimple,
  warningCircle,
  x,
} as const;

export type IconName = keyof typeof SOURCES;

export function icon(name: IconName): HTMLSpanElement {
  const span = document.createElement("span");
  span.className = "icon";
  span.setAttribute("aria-hidden", "true");
  // Trusted static asset bundled from the icon package, never user input.
  span.innerHTML = SOURCES[name];
  return span;
}
