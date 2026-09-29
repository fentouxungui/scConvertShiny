/* Folder picker -> zip -> feed Shiny's file input.
 *
 * Browsers cannot hand a directory to Shiny's fileInput, and Shiny's upload
 * binding would drop the relative paths. So we let the user pick a folder with
 * a hidden `webkitdirectory` input, zip it in the browser with JSZip (paths
 * preserved), and inject the resulting .zip into the Shiny `folder_zip` input.
 *
 * If JSZip is unavailable (e.g. the CDN is blocked on an intranet deployment),
 * the picker simply tells the user to upload a .zip manually; that path always
 * works because the server extracts the archive.
 */
(function () {
  function byId(id) {
    return document.getElementById(id);
  }

  function innerFile(el) {
    if (!el) return null;
    return el.tagName === "INPUT" ? el : el.querySelector('input[type=file]');
  }

  function setStatus(msg) {
    var s = byId("folder_status");
    if (s) s.textContent = msg || "";
  }

  function wire() {
    var picker = byId("folder_picker");
    var target = byId("folder_zip");
    if (!picker || !target) return false;
    var fileInput = innerFile(target);
    if (!fileInput) return false;
    if (picker.dataset.wired === "1") return true;
    picker.dataset.wired = "1";

    picker.addEventListener("change", function () {
      if (!picker.files || picker.files.length === 0) return;
      if (!window.JSZip) {
        setStatus("JSZip not loaded: please zip the folder yourself and " +
                  "select the .zip in the box above.");
        return;
      }
      var files = Array.prototype.slice.call(picker.files);
      setStatus("Packing " + files.length + " files...");
      var zip = new JSZip();
      files.forEach(function (f) {
        zip.file(f.webkitRelativePath || f.name, f);
      });
      zip.generateAsync({ type: "blob" }).then(function (blob) {
        var top = (files[0].webkitRelativePath || "folder").split("/")[0];
        var name = top + ".zip";
        var file = new File([blob], name, { type: "application/zip" });
        var dt = new DataTransfer();
        dt.items.add(file);
        fileInput.files = dt.files;
        fileInput.dispatchEvent(new Event("change", { bubbles: true }));
        setStatus("Packed " + name + " (" + files.length +
                  " files). Uploading...");
      }).catch(function (err) {
        setStatus("Packing failed: " + err);
      });
    });
    return true;
  }

  function ready() {
    if (!wire()) setTimeout(wire, 500);
  }

  document.addEventListener("shiny:bound", ready);
  document.addEventListener("shiny:connected", ready);
  setTimeout(ready, 1000);
})();
