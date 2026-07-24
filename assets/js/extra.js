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

document.addEventListener("DOMContentLoaded", () => {
  setupFlipCards();
  setupArticleSorting();
  setupReadMore();
  setupDebris();
});
