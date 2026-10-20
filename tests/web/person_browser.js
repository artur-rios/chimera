// Test-only observations executed unchanged by Playwright and native Safari.
function personProbe(action, value) {
  const normalize = (text) => text.replace(/\s+/g, " ").trim();
  const label = (node) =>
    normalize(node.getAttribute("aria-label") || node.textContent);
  const button = (name) =>
    [...document.querySelectorAll('[role="button"]')].find(
      (node) =>
        label(node) === name && node.getAttribute("aria-disabled") !== "true",
    );
  const result = () =>
    [...document.querySelectorAll('[role="region"][tabindex="0"]')].find(
      (node) =>
        label(node).startsWith(
          "Generated synthetic people Synthetic people generated.",
        ),
    );
  if (action === "setup") {
    window.__chimeraPersonCopied = null;
    window.__chimeraPersonCopyFailure = false;
    Object.defineProperty(navigator, "clipboard", {
      configurable: true,
      value: {
        writeText: async (text) => {
          if (window.__chimeraPersonCopyFailure) throw Error("PRIVATE PERSON");
          window.__chimeraPersonCopied = text;
        },
      },
    });
    performance.clearResourceTimings();
    return true;
  }
  if (action === "result") return result() ? label(result()) : null;
  if (action === "openSelect") {
    const node = [...document.querySelectorAll('[role="button"]')].find(
      (item) =>
        label(item).startsWith(`${value} `) &&
        item.getAttribute("aria-disabled") !== "true",
    );
    if (!node) return false;
    node.click();
    return true;
  }
  if (action === "option") {
    const node = [...document.querySelectorAll('[role="menuitem"]')].find(
      (item) => label(item) === value,
    );
    if (!node) return false;
    node.click();
    return true;
  }
  if (action === "button") {
    const node = button(value);
    if (!node) return false;
    node.click();
    return true;
  }
  if (action === "copy") {
    const node = button("Copy labeled person data");
    if (!node) return false;
    node.click();
    return true;
  }
  if (action === "copied") return window.__chimeraPersonCopied;
  if (action === "saved")
    return (
      window.__chimeraSavedName === "chimera-synthetic-people.txt" &&
      JSON.stringify(window.__chimeraSavedBytes) === JSON.stringify(value) &&
      window.__chimeraSaveCount === 1 &&
      window.__chimeraLiveDownloadUrlCount === 0
    );
  if (action === "noResult")
    return (
      !result() &&
      !button("Copy labeled person data") &&
      !button("Save labeled person data")
    );
  if (action === "copyFailure") {
    window.__chimeraPersonCopyFailure = true;
    return true;
  }
  if (action === "saveFailure") {
    URL.createObjectURL = () => {
      throw Error("PRIVATE PERSON");
    };
    return true;
  }
  if (action === "entropyFailure") {
    Object.defineProperty(window.crypto, "getRandomValues", {
      configurable: true,
      value: () => {
        throw Error("PRIVATE PERSON");
      },
    });
    return true;
  }
  throw Error("Unknown person probe action");
}
