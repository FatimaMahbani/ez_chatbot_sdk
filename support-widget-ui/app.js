/**
 * EZ Insurance — Arabic support chat widget (UI only, no backend).
 */
(function () {
  "use strict";

  var root = document.getElementById("ez-chat-widget");
  var launcher = document.getElementById("ez-chat-launcher");
  var panel = document.getElementById("ez-chat-panel");
  var closeBtn = document.getElementById("ez-chat-close");
  var messagesEl = document.getElementById("ez-chat-messages");
  var input = document.getElementById("ez-chat-input");
  var sendBtn = document.getElementById("ez-chat-send");
  var typingWrap = document.getElementById("ez-chat-typing-wrap");
  var waitingEl = document.getElementById("ez-chat-waiting");

  var initialMessage =
    "الرجاء إدخال رقم الجوال";

  function pad2(n) {
    return n < 10 ? "0" + n : String(n);
  }

  function formatTime(d) {
    return pad2(d.getHours()) + ":" + pad2(d.getMinutes());
  }

  function scrollToBottom() {
    requestAnimationFrame(function () {
      messagesEl.scrollTo({
        top: messagesEl.scrollHeight,
        behavior: "smooth",
      });
    });
  }

  /**
   * @param {"bot" | "user"} role
   * @param {string} text
   */
  function appendMessage(role, text) {
    var row = document.createElement("div");
    row.className =
      "ez-chat__row " +
      (role === "user" ? "ez-chat__row--user" : "ez-chat__row--bot");

    var bubble = document.createElement("div");
    bubble.className = "ez-chat__bubble";
    bubble.textContent = text;

    var time = document.createElement("span");
    time.className = "ez-chat__time";
    time.textContent = formatTime(new Date());

    row.appendChild(bubble);
    row.appendChild(time);
    messagesEl.appendChild(row);
    scrollToBottom();
  }

  function setPanelOpen(open) {
    panel.hidden = !open;
    panel.setAttribute("aria-hidden", open ? "false" : "true");
    launcher.setAttribute("aria-expanded", open ? "true" : "false");
    if (open) {
      root.classList.add("ez-chat--open");
      panel.removeAttribute("hidden");
      requestAnimationFrame(function () {
        panel.classList.add("is-open");
      });
      input.focus();
    } else {
      root.classList.remove("ez-chat--open");
      panel.classList.remove("is-open");
      setTimeout(function () {
        if (!panel.classList.contains("is-open")) {
          panel.setAttribute("hidden", "");
        }
      }, 320);
    }
  }

  function showLoadingState(show) {
    typingWrap.hidden = !show;
    waitingEl.hidden = !show;
    sendBtn.disabled = show;
    input.readOnly = show;
  }

  function onSend() {
    var text = input.value.trim();
    if (!text) return;

    appendMessage("user", text);
    input.value = "";
    showLoadingState(true);
    scrollToBottom();

    // UI-only: simulate end of "waiting" (replace with real API later)
    window.setTimeout(function () {
      showLoadingState(false);
    }, 2200);
  }

  launcher.addEventListener("click", function () {
    setPanelOpen(true);
  });

  closeBtn.addEventListener("click", function () {
    setPanelOpen(false);
  });

  sendBtn.addEventListener("click", onSend);

  input.addEventListener("keydown", function (e) {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      onSend();
    }
  });

  // Initial bot prompt
  appendMessage("bot", initialMessage);
})();
