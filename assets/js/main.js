// Logo click functionality with bounce animation
function goHome() {
  const logo = document.getElementById("logo");
  if (!logo) return;

  logo.style.animation = "bounce 0.6s ease-in-out";

  setTimeout(() => {
    logo.style.animation = "";
  }, 600);

  // Navigate to index page instead of #home
  // Also navigate to / instead of www.pwindows.qzz.io to enable better testing
  window.location.href = "/";
}

function aboutPage() {
  window.location.href = "/about";
}

function newsPage() {
  window.location.href = "/articles";
}

// Hamburger Menu Functionality
function toggleMenu() {
  const hamburger = document.getElementById("hamburger");
  const mobileMenu = document.getElementById("mobileMenu");
  const body = document.body;

  if (hamburger && mobileMenu) {
    hamburger.classList.toggle("active");
    mobileMenu.classList.toggle("active");
    body.classList.toggle("menu-open");
  }
}

function closeMenu() {
  const hamburger = document.getElementById("hamburger");
  const mobileMenu = document.getElementById("mobileMenu");
  const body = document.body;

  if (hamburger && mobileMenu) {
    hamburger.classList.remove("active");
    mobileMenu.classList.remove("active");
    body.classList.remove("menu-open");
  }
}

// Enhanced copy IP functionality
function copyIP() {
  const ip = "Play.PWindows.qzz.io";
  const button = document.querySelector(".server-info");
  if (!button) return;

  navigator.clipboard
    .writeText(ip)
    .then(function () {
      button.classList.add("copied");

      setTimeout(() => {
        button.classList.remove("copied");
      }, 2000);
    })
    .catch(function (err) {
      console.error("Failed to copy IP: ", err);
      const textArea = document.createElement("textarea");
      textArea.value = ip;
      document.body.appendChild(textArea);
      textArea.select();
      document.execCommand("copy");
      document.body.removeChild(textArea);

      button.classList.add("copied");
      setTimeout(() => {
        button.classList.remove("copied");
      }, 2000);
    });
}

// Copy server IP from flip card button
function copyServerIP(button) {
  const ip = "Play.PWindows.qzz.io";

  navigator.clipboard
    .writeText(ip)
    .then(function () {
      button.classList.add("copied");

      setTimeout(() => {
        button.classList.remove("copied");
      }, 2000);
    })
    .catch(function (err) {
      console.error("Failed to copy IP: ", err);
      const textArea = document.createElement("textarea");
      textArea.value = ip;
      document.body.appendChild(textArea);
      textArea.select();
      document.execCommand("copy");
      document.body.removeChild(textArea);

      button.classList.add("copied");
      setTimeout(() => {
        button.classList.remove("copied");
      }, 2000);
    });
}

// Initialize everything when DOM is ready
document.addEventListener("DOMContentLoaded", function () {
  // Setup hamburger menu
  const hamburger = document.getElementById("hamburger");
  const mobileMenu = document.getElementById("mobileMenu");

  if (hamburger) {
    hamburger.addEventListener("click", toggleMenu);
  }

  // Close menu when clicking outside
  if (mobileMenu) {
    mobileMenu.addEventListener("click", function (e) {
      if (e.target === mobileMenu) {
        closeMenu();
      }
    });
  }

  // Close menu on escape key
  document.addEventListener("keydown", function (e) {
    if (
      e.key === "Escape" &&
      mobileMenu &&
      mobileMenu.classList.contains("active")
    ) {
      closeMenu();
    }
  });

  // Handle window resize
  window.addEventListener("resize", function () {
    if (
      window.innerWidth > 768 &&
      mobileMenu &&
      mobileMenu.classList.contains("active")
    ) {
      closeMenu();
    }
  });

  // Enhanced smooth scrolling for anchor links
  document.querySelectorAll('a[href^="#"]').forEach((anchor) => {
    anchor.addEventListener("click", function (e) {
      e.preventDefault();
      const target = document.querySelector(this.getAttribute("href"));
      if (target) {
        target.scrollIntoView({
          behavior: "smooth",
          block: "start",
        });
      }
    });
  });

  // Hero card hover effects (optimized with transform only)
  // removed for more efficient css code

  // Scroll animations (optimized with IntersectionObserver)
});
