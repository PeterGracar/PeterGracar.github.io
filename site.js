(() => {
  const body = document.body;
  if (!body) {
    return;
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
    button.classList.remove("is-open");
    button.setAttribute("aria-expanded", "false");
  };

  const positionTooltip = (button) => {
    const tooltip = button.querySelector(".hover-img");
    if (!tooltip) {
      return;
    }
    button.removeAttribute("data-tip-side");

    const btnRect = button.getBoundingClientRect();
    const tipRect = tooltip.getBoundingClientRect();

    const spaceBelow = window.innerHeight - btnRect.bottom;
    const spaceAbove = btnRect.top;
    if (spaceBelow < tipRect.height + 20 && spaceAbove > spaceBelow) {
      button.dataset.tipSide = "top";
    }
  };

  const openTooltip = (button) => {
    if (activeButton && activeButton !== button) {
      closeTooltip(activeButton);
    }
    positionTooltip(button);
    button.classList.add("is-open");
    button.setAttribute("aria-expanded", "true");
    activeButton = button;
  };

  tooltipButtons.forEach((button, index) => {
    const tooltip = button.querySelector(".hover-img");
    if (!tooltip) {
      return;
    }

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

  window.addEventListener("resize", () => {
    if (activeButton) {
      positionTooltip(activeButton);
    }
  });
})();
