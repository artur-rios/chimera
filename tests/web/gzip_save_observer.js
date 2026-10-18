// Test-only save boundary observer, executed unchanged by Playwright and Safari.
// Creating an unrelated Blob must never supply a clicked anchor's payload.
function observeGzipSaves({ suppressDownloads = false } = {}) {
  const blobs = new Map();
  const downloadUrls = new Set();
  const create = URL.createObjectURL.bind(URL);
  const revoke = URL.revokeObjectURL.bind(URL);
  const click = HTMLAnchorElement.prototype.click;
  window.__chimeraSavedName = null;
  window.__chimeraSavedHref = null;
  window.__chimeraSavedMime = null;
  window.__chimeraSavedBytes = null;
  window.__chimeraSaveCount = 0;
  window.__chimeraLiveDownloadUrlCount = 0;
  window.__chimeraGzipSaveErrors = [];
  URL.createObjectURL = function(blob) {
    const url = create(blob);
    blobs.set(url, blob);
    return url;
  };
  URL.revokeObjectURL = function(url) {
    blobs.delete(String(url));
    downloadUrls.delete(String(url));
    window.__chimeraLiveDownloadUrlCount = downloadUrls.size;
    return revoke(url);
  };
  HTMLAnchorElement.prototype.click = function() {
    if (this.download) {
      window.__chimeraSaveCount++;
      window.__chimeraSavedName = this.download;
      window.__chimeraSavedHref = this.href;
      window.__chimeraSavedMime = null;
      window.__chimeraSavedBytes = null;
      const blob = blobs.get(this.href);
      if (!blob || typeof blob.arrayBuffer !== 'function') {
        window.__chimeraGzipSaveErrors.push('unknown-or-revoked-download-url');
      } else {
        downloadUrls.add(this.href);
        window.__chimeraLiveDownloadUrlCount = downloadUrls.size;
        // Retain the clicked Blob while reading: revocation after activation
        // is valid and must not destroy the payload already being downloaded.
        window.__chimeraSavedMime = blob.type;
        blob.arrayBuffer().then(buffer => {
          window.__chimeraSavedBytes = [...new Uint8Array(buffer)];
        }, () => {
          window.__chimeraGzipSaveErrors.push('download-blob-read-failed');
        });
      }
      if (suppressDownloads) return;
    }
    return click.call(this);
  };
}
