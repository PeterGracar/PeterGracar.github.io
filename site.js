(() => {
  const body = document.body;
  if (!body) {
    return;
  }

  const sections = document.querySelectorAll('.page-section');
  if (sections.length && 'IntersectionObserver' in window) {
    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          entry.target.classList.add('is-visible');
          observer.unobserve(entry.target);
        }
      });
    }, { threshold: 0.1 });
    sections.forEach(s => observer.observe(s));
  } else {
    sections.forEach(s => s.classList.add('is-visible'));
  }

  const emailSlot = document.getElementById('e9');
  if (emailSlot) {
    const email = atob('UC5HcmFjYXJAbGVlZHMuYWMudWs=');
    const link = document.createElement('a');
    link.href = `${atob('bWFpbHRvOg==')}${email}`;
    link.textContent = email;
    emailSlot.append(link);
  }

  const page = body.dataset.page;
  if (page) {
    document.querySelectorAll("[data-page-link]").forEach((link) => {
      if (link.dataset.pageLink === page) {
        link.setAttribute("aria-current", "page");
      }
    });
  }

  const yearNode = document.querySelector("[data-year]");
  if (yearNode) {
    yearNode.textContent = String(new Date().getFullYear());
  }

  const tooltipButtons = Array.from(document.querySelectorAll(".hover-image"));
  if (!tooltipButtons.length) {
    return;
  }

  const desktopHover = window.matchMedia("(hover: hover) and (pointer: fine)").matches;
  let activeButton = null;

  const closeTooltip = (button) => {
    if (!button) {
      return;
    }
    const img = button._hoverImg;
    if (img) {
      img.classList.remove("is-open");
      if (img.parentNode === body) {
        button.append(img);
      }
    }
    button.classList.remove("is-open");
    button.setAttribute("aria-expanded", "false");
  };

  const openTooltip = (button) => {
    if (activeButton && activeButton !== button) {
      closeTooltip(activeButton);
    }
    const img = button._hoverImg;
    if (img) {
      body.append(img);
      img.classList.add("is-open");
    }
    button.classList.add("is-open");
    button.setAttribute("aria-expanded", "true");
    activeButton = button;
  };

  tooltipButtons.forEach((button, index) => {
    const tooltip = button.querySelector(".hover-img");
    if (!tooltip) {
      return;
    }

    button._hoverImg = tooltip;
    const tooltipId = tooltip.id || `tooltip-${index + 1}`;
    tooltip.id = tooltipId;
    tooltip.setAttribute("role", "tooltip");
    button.setAttribute("aria-describedby", tooltipId);
    button.setAttribute("aria-expanded", "false");

    if (desktopHover) {
      button.addEventListener("mouseenter", () => openTooltip(button));
      button.addEventListener("mouseleave", () => {
        closeTooltip(button);
        if (activeButton === button) {
          activeButton = null;
        }
      });

      // On pointer-hover devices, previews should vanish as soon as the cursor leaves the trigger text.
      button.addEventListener("click", (event) => {
        event.preventDefault();
        event.stopPropagation();
        closeTooltip(button);
        if (activeButton === button) {
          activeButton = null;
        }
      });
    } else {
      button.addEventListener("click", (event) => {
        event.stopPropagation();
        if (button.classList.contains("is-open")) {
          closeTooltip(button);
          if (activeButton === button) {
            activeButton = null;
          }
          return;
        }
        openTooltip(button);
      });
    }

    button.addEventListener("keydown", (event) => {
      if (event.key === "Escape") {
        closeTooltip(button);
        if (activeButton === button) {
          activeButton = null;
        }
      }

      if (event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        if (desktopHover) {
          if (button.classList.contains("is-open")) {
            closeTooltip(button);
            if (activeButton === button) {
              activeButton = null;
            }
          } else {
            openTooltip(button);
          }
        } else {
          button.click();
        }
      }
    });
  });

  document.addEventListener("click", (event) => {
    if (!event.target.closest(".hover-image")) {
      closeTooltip(activeButton);
      activeButton = null;
    }
  });

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") {
      closeTooltip(activeButton);
      activeButton = null;
    }
  });

})();
