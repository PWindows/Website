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
      let touchMode = false;
      let updating = false;

      const focus = (element) => element.focus({ preventScroll: true });

      function setFlipped(flipped, moveFocus = false) {
        updating = true;
        const visibleFace = flipped ? back : front;
        const hiddenFace = flipped ? front : back;
        visibleFace.removeAttribute("inert");
        visibleFace.setAttribute("aria-hidden", "false");
        card.classList.toggle("is-flipped", flipped);
        openButton.setAttribute("aria-expanded", String(flipped));
        if (moveFocus || hiddenFace.contains(document.activeElement)) {
          focus(card.classList.contains("precise-interaction") ? card : flipped ? closeButton : openButton);
        }
        hiddenFace.setAttribute("inert", "");
        hiddenFace.setAttribute("aria-hidden", "true");
        updating = false;
      }

      function setPreciseMode(enabled) {
        updating = true;
        if (enabled) {
          card.tabIndex = 0;
          card.setAttribute("role", "group");
          card.setAttribute("aria-label", (document.body.dataset.flipCardDetails || "{title}").replaceAll("{title}", cardTitle || ""));
          if (document.activeElement === openButton || document.activeElement === closeButton) focus(card);
          openButton.setAttribute("tabindex", "-1");
          openButton.setAttribute("aria-hidden", "true");
        } else {
          openButton.removeAttribute("tabindex");
          openButton.removeAttribute("aria-hidden");
        }
        openButton.hidden = enabled;
        closeButton.disabled = enabled;
        closeButton.hidden = enabled;
        closeButton.setAttribute("aria-hidden", String(enabled));
        card.classList.toggle("precise-interaction", enabled);
        if (!enabled) {
          if (document.activeElement === card) focus(card.classList.contains("is-flipped") ? closeButton : openButton);
          card.removeAttribute("tabindex");
          card.removeAttribute("role");
          card.removeAttribute("aria-label");
        }
        updating = false;
      }

      function configureKeyboardAccess() {
        setPreciseMode(preciseInput.matches && !touchMode);
        setFlipped(false);
      }

      openButton.addEventListener("click", () => setFlipped(true, true));
      closeButton.addEventListener("click", () => setFlipped(false, true));

      card.addEventListener("pointerenter", (event) => {
        if (event.pointerType === "mouse" && preciseInput.matches) {
          touchMode = false;
          setPreciseMode(true);
          setFlipped(true);
        }
      });

      card.addEventListener("pointerdown", (event) => {
        if (event.pointerType !== "mouse") {
          touchMode = true;
          setPreciseMode(false);
        }
      });

      card.addEventListener("pointerleave", (event) => {
        if (event.pointerType === "mouse" && card.classList.contains("precise-interaction") && !card.contains(document.activeElement)) {
          setFlipped(false);
        }
      });

      card.addEventListener("focusin", () => {
        if (!updating && keyboardNavigation && preciseInput.matches && !touchMode) {
          setFlipped(true);
        }
      });

      card.addEventListener("focusout", () => {
        window.requestAnimationFrame(() => {
          if (!card.contains(document.activeElement)) {
            setFlipped(false);
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

function setupDebris() {
    const debrisElements = document.querySelectorAll("[data-debris]");
    if (!debrisElements.length) return;

    const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)");

    function updateDebris() {
        debrisElements.forEach((debris) => {
            const scale = parseFloat(debris.dataset.scale);
            const startY = parseFloat(debris.dataset.startY);
            const endY = parseFloat(debris.dataset.endY);

            if (reduceMotion.matches) {
                debris.style.transform = `scale(${scale})`;
                return;
            }

            const card = debris.closest(".games-content-part");
            if (!card) return;

            const rect = card.getBoundingClientRect();
            const scrollY = window.scrollY;
            const maxScroll = document.documentElement.scrollHeight - window.innerHeight;
            const progress = maxScroll > 0 ? scrollY / maxScroll : 0;
            const translateY = startY + (endY - startY) * (progress);

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

document.addEventListener("DOMContentLoaded", () => {
  setupFlipCards();
  setupArticleSorting();
  setupReadMore();
  setupDebris();
});
