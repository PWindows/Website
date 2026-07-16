const SERVER_IP = "play.pwindows.qzz.io";

function announce(message) {
  const status = document.getElementById("site-status");
  if (status) status.textContent = message;
}

async function copyText(text) {
  if (navigator.clipboard?.writeText) {
    await navigator.clipboard.writeText(text);
    return;
  }

  const textArea = document.createElement("textarea");
  textArea.value = text;
  textArea.setAttribute("readonly", "");
  textArea.style.position = "fixed";
  textArea.style.opacity = "0";
  document.body.appendChild(textArea);
  textArea.select();
  const copied = document.execCommand("copy");
  textArea.remove();
  if (!copied) throw new Error("Copy command was rejected");
}

function setupCopyButtons() {
  document.querySelectorAll("[data-copy-ip]").forEach((button) => {
    button.addEventListener("click", async () => {
      try {
        await copyText(SERVER_IP);
        button.classList.add("copied");
        announce(`Server address copied: ${SERVER_IP}`);
        window.setTimeout(() => button.classList.remove("copied"), 2000);
      } catch (error) {
        console.error("Failed to copy server address", error);
        announce(`Could not copy automatically. Server address: ${SERVER_IP}`);
      }
    });
  });
}

function setupMenu() {
  const menuButton = document.getElementById("hamburger");
  const menu = document.getElementById("mobileMenu");
  if (!menuButton || !menu) return;

  const menuItems = () =>
    Array.from(menu.querySelectorAll('a[href], button:not([disabled])'));

  function setMenuOpen(open, returnFocus = false) {
    menuButton.classList.toggle("active", open);
    menu.classList.toggle("active", open);
    document.body.classList.toggle("menu-open", open);
    menuButton.setAttribute("aria-expanded", String(open));
    menuButton.setAttribute("aria-label", open ? "Close site menu" : "Open site menu");
    menu.setAttribute("aria-hidden", String(!open));
    menu.toggleAttribute("inert", !open);

    if (open) menuItems()[0]?.focus();
    else if (returnFocus) menuButton.focus();
  }

  menuButton.addEventListener("click", () => {
    setMenuOpen(menuButton.getAttribute("aria-expanded") !== "true", true);
  });

  menu.addEventListener("click", (event) => {
    if (event.target === menu || event.target.closest("a")) setMenuOpen(false);
  });

  document.addEventListener("keydown", (event) => {
    if (menuButton.getAttribute("aria-expanded") !== "true") return;

    if (event.key === "Escape") {
      event.preventDefault();
      setMenuOpen(false, true);
      return;
    }

    if (event.key !== "Tab") return;
    const items = menuItems();
    const first = items[0];
    const last = items[items.length - 1];
    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault();
      last?.focus();
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault();
      first?.focus();
    }
  });

  window.addEventListener("resize", () => {
    if (window.innerWidth > 768 && menuButton.getAttribute("aria-expanded") === "true") {
      setMenuOpen(false);
    }
  });
}

function setupAnchorScrolling() {
  document.querySelectorAll('a[href^="#"]:not([href="#"])').forEach((anchor) => {
    anchor.addEventListener("click", (event) => {
      const target = document.getElementById(anchor.hash.slice(1));
      if (!target) return;
      event.preventDefault();
      const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
      target.scrollIntoView({ behavior: reduceMotion ? "auto" : "smooth", block: "start" });
      history.pushState(null, "", anchor.hash);
    });
  });
}

function setupFlipCards() {
  const precisePointer = window.matchMedia("(any-hover: hover) and (any-pointer: fine)");

  document.querySelectorAll("[data-flip-card]").forEach((card) => {
    const front = card.querySelector(".flip-card-front");
    const back = card.querySelector(".flip-card-back");
    const openButton = card.querySelector(".flip-card-toggle");
    const closeButton = card.querySelector(".flip-card-back-toggle");
    if (!front || !back || !openButton || !closeButton) return;

    const cardTitle = card.querySelector(".flip-card-title")?.textContent.trim();

    function setFlipped(flipped, moveFocus = false) {
      card.classList.toggle("is-flipped", flipped);
      openButton.setAttribute("aria-expanded", String(flipped));
      front.toggleAttribute("inert", flipped);
      back.toggleAttribute("inert", !flipped);
      if (moveFocus) (flipped ? closeButton : openButton).focus();
    }

    function configureInteractionMode() {
      if (precisePointer.matches) {
        card.tabIndex = 0;
        card.setAttribute("role", "region");
        card.setAttribute("aria-label", `${cardTitle || "Join option"} details`);
        closeButton.disabled = true;
        closeButton.hidden = true;
        closeButton.setAttribute("aria-hidden", "true");
      } else {
        card.removeAttribute("tabindex");
        card.removeAttribute("role");
        card.removeAttribute("aria-label");
        closeButton.disabled = false;
        closeButton.hidden = false;
        closeButton.removeAttribute("aria-hidden");
      }
      setFlipped(false);
    }

    openButton.addEventListener("click", () => setFlipped(true, true));
    closeButton.addEventListener("click", () => setFlipped(false, true));

    card.addEventListener("pointerenter", () => {
      if (precisePointer.matches) setFlipped(true);
    });

    card.addEventListener("pointerleave", () => {
      if (precisePointer.matches && !card.contains(document.activeElement)) {
        setFlipped(false);
      }
    });

    card.addEventListener("focusin", () => {
      if (precisePointer.matches) setFlipped(true);
    });

    card.addEventListener("focusout", () => {
      window.requestAnimationFrame(() => {
        if (precisePointer.matches && !card.contains(document.activeElement)) {
          setFlipped(false);
        }
      });
    });

    card.addEventListener("keydown", (event) => {
      if (precisePointer.matches && event.key === "Escape") {
        event.preventDefault();
        card.focus();
        setFlipped(false);
      } else if (
        precisePointer.matches &&
        document.activeElement === card &&
        (event.key === "Enter" || event.key === " ")
      ) {
        event.preventDefault();
        setFlipped(true);
      }
    });

    precisePointer.addEventListener("change", configureInteractionMode);
    configureInteractionMode();
  });
}

function setupArticleSorting() {
  const select = document.getElementById("sort-select");
  const grid = document.getElementById("articleGrid");
  if (!select || !grid) return;

  const comparators = {
    "date-desc": (a, b) => b.dataset.date.localeCompare(a.dataset.date),
    "date-asc": (a, b) => a.dataset.date.localeCompare(b.dataset.date),
    type: (a, b) => a.dataset.type.localeCompare(b.dataset.type),
    title: (a, b) => a.dataset.title.localeCompare(b.dataset.title),
  };

  function sortArticles() {
    const cards = Array.from(grid.querySelectorAll(".article-card"));
    cards.sort(comparators[select.value] || comparators["date-desc"]);
    cards.forEach((card) => grid.appendChild(card));
  }

  select.addEventListener("change", sortArticles);
  sortArticles();
}

document.addEventListener("DOMContentLoaded", () => {
  setupMenu();
  setupCopyButtons();
  setupAnchorScrolling();
  setupFlipCards();
  setupArticleSorting();
});
