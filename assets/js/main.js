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
    const serverAddress = button.dataset.copyIp;
    if (!serverAddress) return;

    button.addEventListener("click", async () => {
      try {
        await copyText(serverAddress);
        button.classList.add("copied");
        announce(`Server address copied: ${serverAddress}`);
        window.setTimeout(() => button.classList.remove("copied"), 2000);
      } catch (error) {
        console.error("Failed to copy server address", error);
        announce(`Could not copy automatically. Server address: ${serverAddress}`);
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
    document.body.classList.toggle("menu-open", open && window.innerWidth <= 768);
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
      setMenuOpen(false, true);
    } else if (menuButton.getAttribute("aria-expanded") === "true") {
      document.body.classList.toggle("menu-open", window.innerWidth <= 768);
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
  const preciseInput = window.matchMedia(
    "(min-width: 769px) and (any-hover: hover) and (any-pointer: fine)",
  );
  let keyboardNavigation = false;

  document.addEventListener(
    "keydown",
    (event) => {
      if (event.key === "Tab") keyboardNavigation = true;
    },
    true,
  );
  document.addEventListener(
    "pointerdown",
    () => {
      keyboardNavigation = false;
    },
    true,
  );

  const cards = Array.from(document.querySelectorAll("[data-flip-card]"))
    .map((card) => {
      const front = card.querySelector(".flip-card-front");
      const back = card.querySelector(".flip-card-back");
      const openButton = card.querySelector(".flip-card-toggle");
      const closeButton = card.querySelector(".flip-card-back-toggle");
      if (!front || !back || !openButton || !closeButton) return null;

      const cardTitle = card.querySelector(".flip-card-title")?.textContent.trim();

      function setFlipped(flipped, moveFocus = false) {
        card.classList.toggle("is-flipped", flipped);
        openButton.setAttribute("aria-expanded", String(flipped));
        front.toggleAttribute("inert", flipped);
        back.toggleAttribute("inert", !flipped);
        front.setAttribute("aria-hidden", String(flipped));
        back.setAttribute("aria-hidden", String(!flipped));
        if (moveFocus) (flipped ? closeButton : openButton).focus();
      }

      function setPreciseMode(enabled) {
        card.classList.toggle("precise-interaction", enabled);
        if (enabled) {
          openButton.setAttribute("tabindex", "-1");
          openButton.setAttribute("aria-hidden", "true");
        } else {
          openButton.removeAttribute("tabindex");
          openButton.removeAttribute("aria-hidden");
        }
        closeButton.disabled = enabled;
        closeButton.hidden = enabled;
        closeButton.setAttribute("aria-hidden", String(enabled));
      }

      function configureKeyboardAccess() {
        if (preciseInput.matches) {
          card.tabIndex = 0;
          card.setAttribute("role", "group");
          card.setAttribute("aria-label", `${cardTitle || "Join option"} details`);
          card.setAttribute("aria-controls", back.id);
        } else {
          card.removeAttribute("tabindex");
          card.removeAttribute("role");
          card.removeAttribute("aria-label");
          card.removeAttribute("aria-controls");
        }
        setPreciseMode(preciseInput.matches);
        setFlipped(false);
      }

      openButton.addEventListener("click", () => setFlipped(true, true));
      closeButton.addEventListener("click", () => setFlipped(false, true));

      card.addEventListener("pointerenter", (event) => {
        if (event.pointerType === "mouse") {
          setPreciseMode(true);
          setFlipped(true);
        }
      });

      card.addEventListener("pointerdown", (event) => {
        if (event.pointerType !== "mouse") setPreciseMode(false);
      });

      card.addEventListener("pointerleave", (event) => {
        if (event.pointerType === "mouse" && !card.contains(document.activeElement)) {
          setFlipped(false);
          setPreciseMode(preciseInput.matches);
        }
      });

      card.addEventListener("focusin", () => {
        if (keyboardNavigation && preciseInput.matches) {
          setPreciseMode(true);
          setFlipped(true);
        }
      });

      card.addEventListener("focusout", () => {
        window.requestAnimationFrame(() => {
          if (!card.contains(document.activeElement)) {
            setFlipped(false);
            setPreciseMode(preciseInput.matches);
          }
        });
      });

      card.addEventListener("keydown", (event) => {
        if (card.classList.contains("precise-interaction") && event.key === "Escape") {
          event.preventDefault();
          setFlipped(false);
        }
      });

      return { configureKeyboardAccess };
    })
    .filter(Boolean);

  function configureCards() {
    cards.forEach(({ configureKeyboardAccess }) => configureKeyboardAccess());
  }

  preciseInput.addEventListener("change", configureCards);
  configureCards();
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

function setupLanguageSelect() {
  const select = document.querySelector("[data-language-select]");
  if (!select) return;

  select.addEventListener("change", () => {
    if (select.value) window.location.assign(select.value);
  });
}

function setupDebris() {
  const debrisElements = document.querySelectorAll("[data-debris]");
  if (!debrisElements.length) return;

  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
  const startY = 20;
  const travelDistance = 140;

  function updateDebris() {
    debrisElements.forEach((debris) => {
      const scaleValue = Number.parseFloat(debris.dataset.scale);
      const scale = Number.isFinite(scaleValue) && scaleValue > 0 ? scaleValue : 1;

      if (reduceMotion.matches) {
        debris.style.transform = `scale(${scale})`;
        return;
      }

      const card = debris.closest(".games-content-part");
      if (!card) return;

      const rect = card.getBoundingClientRect();
      const progress = Math.min(
        1,
        Math.max(0, (window.innerHeight - rect.top) / (window.innerHeight + rect.height)),
      );
      const translateY = startY - travelDistance * progress;

      debris.style.transform = `translateY(${translateY}%) scale(${scale})`;
    });
  }

  let ticking = false;
  function onScroll() {
    if (reduceMotion.matches || ticking) return;

    window.requestAnimationFrame(() => {
      updateDebris();
      ticking = false;
    });
    ticking = true;
  }

  window.addEventListener("scroll", onScroll);
  window.addEventListener("resize", updateDebris);
  window.addEventListener("load", updateDebris);
  reduceMotion.addEventListener("change", updateDebris);
  updateDebris();
}

function setupReadMore() {
  const grid = document.getElementById("readMoreGrid");
  const button = document.getElementById("readMoreBtn");
  if (!grid || !button) return;

  const step = Number.parseInt(button.dataset.step, 10) || 16;

  function revealNext() {
    const hidden = Array.from(grid.querySelectorAll(".read-more-item.is-hidden"));
    hidden.slice(0, step).forEach((item) => item.classList.remove("is-hidden"));

    if (!grid.querySelector(".read-more-item.is-hidden")) {
      button.hidden = true;
    }
  }

  button.addEventListener("click", revealNext);
}

function setupBackToTop() {
  const button = document.getElementById("backToTopBtn");
  if (!button) return;

  function toggleVisibility() {
    button.classList.toggle("is-visible", window.scrollY > 400);
  }

  button.addEventListener("click", () => {
    window.scrollTo({ top: 0, behavior: "smooth" });
  });

  window.addEventListener("scroll", toggleVisibility);
  toggleVisibility();
}

document.addEventListener("DOMContentLoaded", () => {
  setupMenu();
  setupCopyButtons();
  setupAnchorScrolling();
  setupFlipCards();
  setupArticleSorting();
  setupLanguageSelect();
  setupReadMore();
  setupBackToTop();
  setupDebris();
});
