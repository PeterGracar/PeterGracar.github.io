(() => {
  const body = document.body;
  if (!body) {
    return;
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

  // About page: a paragraph that starts beside the floated photo moves over as
  // a whole block, unless it would then run more than two lines past the photo,
  // in which case it wraps around the photo as ordinary text.
  const aboutBody = document.querySelector(".about-body");
  const aboutPhoto = aboutBody && aboutBody.querySelector(".portrait");
  if (aboutPhoto) {
    const maxLinesPastPhoto = 2;
    const paragraphs = aboutBody.querySelectorAll("p");
    const fitParagraphs = () => {
      paragraphs.forEach((p) => p.classList.remove("about-wrap"));
      const photoStyle = getComputedStyle(aboutPhoto);
      if (photoStyle.float === "none") {
        return;
      }
      const photoBottom = aboutPhoto.getBoundingClientRect().bottom + parseFloat(photoStyle.marginBottom);
      // Top to bottom, since each choice moves the paragraphs below it.
      paragraphs.forEach((p) => {
        const box = p.getBoundingClientRect();
        if (box.top >= photoBottom) {
          return;
        }
        const lineHeight = parseFloat(getComputedStyle(p).lineHeight);
        if (Math.round((box.bottom - photoBottom) / lineHeight) > maxLinesPastPhoto) {
          p.classList.add("about-wrap");
        }
      });
    };
    let fitQueued = false;
    const queueFit = () => {
      if (!fitQueued) {
        fitQueued = true;
        requestAnimationFrame(() => {
          fitQueued = false;
          fitParagraphs();
        });
      }
    };
    fitParagraphs();
    window.addEventListener("resize", queueFit);
    if (document.fonts) {
      document.fonts.ready.then(queueFit);
    }
  }

  // Pride Month (June) easter egg — auto-on, with a remembered opt-out.
  const prideToggle = document.querySelector("[data-pride-toggle]");
  if (prideToggle && new Date().getMonth() === 5) {
    const prideKey = "pride-colours";
    const readPride = () => {
      try {
        return localStorage.getItem(prideKey);
      } catch (error) {
        return null;
      }
    };
    const writePride = (value) => {
      try {
        localStorage.setItem(prideKey, value);
      } catch (error) {
        /* storage unavailable (e.g. private mode) — preference simply not remembered */
      }
    };

    let prideEnabled = readPride() !== "off"; // default on during June
    const applyPride = () => {
      body.classList.toggle("pride", prideEnabled);
      prideToggle.setAttribute("aria-pressed", String(prideEnabled));
    };
    applyPride();
    prideToggle.hidden = false; // reveal the toggle only during Pride Month
    prideToggle.addEventListener("click", () => {
      prideEnabled = !prideEnabled;
      writePride(prideEnabled ? "on" : "off");
      applyPride();
    });
  }

  const upcomingTalks = document.querySelectorAll("[data-talk-date]");
  if (upcomingTalks.length) {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    upcomingTalks.forEach((item) => {
      const dateStr = item.dataset.talkDate;
      if (!dateStr) {
        return;
      }
      const talkDate = new Date(`${dateStr}T00:00:00`);
      if (Number.isNaN(talkDate.getTime())) {
        return;
      }
      if (talkDate >= today) {
        const badge = item.querySelector("[data-talk-upcoming]");
        if (badge) {
          badge.hidden = false;
        }
      }
    });
  }

  // Rewrite server-rendered (UTC) timestamps into the viewer's local time.
  // The Liquid-rendered UTC text remains as the no-JS fallback.
  document.querySelectorAll("time[data-localize]").forEach((node) => {
    const stamp = new Date(node.getAttribute("datetime"));
    if (Number.isNaN(stamp.getTime())) {
      return;
    }
    const pad = (n) => String(n).padStart(2, "0");
    let zone = "";
    try {
      const part = new Intl.DateTimeFormat("en-GB", { timeZoneName: "short" })
        .formatToParts(stamp)
        .find((p) => p.type === "timeZoneName");
      if (part) {
        zone = ` ${part.value}`;
      }
    } catch (error) {
      /* Intl unavailable — omit the timezone label */
    }
    node.textContent =
      `${stamp.getFullYear()}-${pad(stamp.getMonth() + 1)}-${pad(stamp.getDate())} ` +
      `${pad(stamp.getHours())}:${pad(stamp.getMinutes())}:${pad(stamp.getSeconds())}${zone}`;
  });

  // Short CV easter egg: below a break in the timeline, one made-up earliest
  // entry, picked at random on each visit from the <template> rendered from
  // _data/cv_origins.yml.
  const cvOrigins = document.getElementById("cv-origins");
  const timeline = document.querySelector(".timeline");
  if (cvOrigins && timeline && cvOrigins.content) {
    const origins = cvOrigins.content.querySelectorAll(".timeline-origin");
    if (origins.length) {
      const gap = document.createElement("li");
      gap.className = "timeline-gap";
      gap.setAttribute("aria-hidden", "true");
      const origin = origins[Math.floor(Math.random() * origins.length)];
      timeline.append(gap, origin.cloneNode(true));
    }
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

  const openTooltip = (button) => {
    if (activeButton && activeButton !== button) {
      closeTooltip(activeButton);
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
