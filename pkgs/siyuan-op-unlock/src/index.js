const { Plugin, Setting, showMessage, fetchSyncPost } = require("siyuan");
const { execFile } = require("child_process");

const DIALOG_KEY_PREFIX = "encryptedNotebook-";
const INJECT_ATTR = "data-siyuan-op-unlock";
const DEFAULT_OP_REF = "op://Private/65oqfbkcvggpgjuufzn44pj5ei/password";
const STORAGE_KEY = "settings";

// `op read` prints the secret on stdout; stderr carries op's own error text.
// The 1Password desktop app handles the unlock prompt, so no tty is needed.
const readOPSecret = (ref) =>
  new Promise((resolve, reject) => {
    execFile(
      "op",
      ["read", ref],
      { timeout: 60000, maxBuffer: 1024 * 1024 },
      (error, stdout, stderr) => {
        if (error) {
          reject(new Error((stderr || "").trim() || error.message));
        } else {
          resolve(stdout.trim());
        }
      },
    );
  });

module.exports = class SiYuanOPUnlock extends Plugin {
  async onload() {
    this.savedRef = undefined;
    try {
      const saved = await this.loadData(STORAGE_KEY);
      if (saved && typeof saved.ref === "string" && saved.ref) {
        this.savedRef = saved.ref;
      }
    } catch (error) {
      console.log(`[${this.name}] load settings fail:`, error);
    }

    // The unlock dialog appends to <body> and stamps data-key only after
    // append, so watch for both additions and the attribute change.
    this.observer = new MutationObserver(() => this.injectAll());
    this.observer.observe(document.body, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ["data-key"],
    });
    this.injectAll();

    this.setting = new Setting({
      confirmCallback: async () => {
        this.savedRef = this.refInput.value.trim();
        try {
          await this.saveData(STORAGE_KEY, { ref: this.savedRef });
          showMessage(`[${this.name}] ${this.i18n?.saved || "settings saved"}`);
        } catch (error) {
          showMessage(`[${this.name}] save settings fail: ${error}`, 6000, "error");
        }
      },
    });
    this.setting.addItem({
      title: this.i18n?.refTitle || "1Password item ref",
      direction: "row",
      description:
        this.i18n?.refTip || "op:// URI for `op read`; falls back to $SIYUAN_MASTER_PASSWORD_OP",
      createActionElement: () => {
        this.refInput = document.createElement("input");
        this.refInput.className = "b3-text-field fn__block";
        this.refInput.placeholder = "op://Vault/item/password";
        this.refInput.value = this.getRef();
        return this.refInput;
      },
    });
    const testButton = document.createElement("button");
    testButton.className = "b3-button b3-button--outline fn__size200";
    testButton.textContent = this.i18n?.test || "Test";
    testButton.addEventListener("click", async () => {
      testButton.disabled = true;
      try {
        const secret = await readOPSecret(this.refInput.value.trim() || this.getRef());
        showMessage(
          `[${this.name}] ${this.i18n?.ok || "ok"}, ${secret.length} ${this.i18n?.chars || "chars"}`,
        );
      } catch (error) {
        showMessage(`[${this.name}] op read failed: ${error.message}`, 6000, "error");
      } finally {
        testButton.disabled = false;
      }
    });
    this.setting.addItem({
      title: "op read",
      description: this.i18n?.testTip || "Run `op read` against the ref above",
      actionElement: testButton,
    });

    this.addCommand({
      langKey: "openSettings",
      globalCallback: () => this.setting.open(this.displayName || this.name),
    });
  }

  onunload() {
    this.observer?.disconnect();
  }

  getRef() {
    return this.savedRef || process.env.SIYUAN_MASTER_PASSWORD_OP || DEFAULT_OP_REF;
  }

  injectAll() {
    document.querySelectorAll(`[data-key^="${DIALOG_KEY_PREFIX}"]`).forEach((element) => {
      if (!element.querySelector(`[${INJECT_ATTR}]`)) {
        this.injectButton(element);
      }
    });
  }

  injectButton(dialogElement) {
    const actionElement = dialogElement.querySelector(".b3-dialog__action");
    if (!actionElement) {
      return;
    }
    const button = document.createElement("button");
    button.className = "b3-button b3-button--text";
    button.setAttribute(INJECT_ATTR, "");
    button.setAttribute("aria-label", this.i18n?.unlockOP || "Unlock with 1Password");
    button.textContent = this.i18n?.unlockOP || "1Password";
    const separator = document.createElement("span");
    separator.className = "fn__space";
    // keep the normal confirm button as the rightmost action
    actionElement.insertBefore(separator, actionElement.lastElementChild);
    actionElement.insertBefore(button, separator);
    button.addEventListener("click", () => this.unlockWithOP(dialogElement, button));
  }

  async unlockWithOP(dialogElement, button) {
    const notebookId = dialogElement.getAttribute("data-key").slice(DIALOG_KEY_PREFIX.length);
    const ref = this.getRef();
    if (!ref) {
      showMessage(
        `[${this.name}] ${this.i18n?.noRef || "no 1Password ref configured"}`,
        6000,
        "error",
      );
      return;
    }
    button.disabled = true;
    try {
      const password = await readOPSecret(ref);
      if (!password) {
        showMessage(
          `[${this.name}] ${this.i18n?.empty || "op read returned empty"}`,
          6000,
          "error",
        );
        return;
      }
      const response = await fetchSyncPost("/api/notebook/unlockAndOpenNotebook", {
        notebook: notebookId,
        password,
      });
      if (response.code !== 0) {
        showMessage(
          `[${this.name}] ${this.i18n?.failed || "unlock failed"}: ${response.msg || response.code}`,
          6000,
          "error",
        );
        return;
      }
      this.destroyDialog(dialogElement);
    } catch (error) {
      showMessage(`[${this.name}] ${error.message}`, 6000, "error");
    } finally {
      button.disabled = false;
    }
  }

  destroyDialog(dialogElement) {
    const dialog = (window.siyuan?.dialogs || []).find((item) => item.element === dialogElement);
    if (dialog) {
      dialog.destroy();
    } else {
      dialogElement.remove();
    }
  }
};
