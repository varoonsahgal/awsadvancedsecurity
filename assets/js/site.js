/* =====================================================================
   OPERATION SKYFORTRESS — site runtime
   - injects nav + footer (pages provide <header id="site-nav"> and <footer id="site-footer">)
   - starfield, scroll reveal, copy buttons, tabs, auto TOC
   - gamification: step checkboxes, CTF flags (sha256), quizzes, XP, levels, badges
   All progress lives in localStorage for this browser only.
   ===================================================================== */
(function () {
  "use strict";
  document.documentElement.classList.add("js");

  const KEY = "skyfortress.v1";
  const root = document.documentElement.dataset.root || document.body.dataset.root || "";

  // ---------------------------------------------------------------- store
  function load() {
    try { return JSON.parse(localStorage.getItem(KEY)) || {}; } catch (e) { return {}; }
  }
  const state = Object.assign({ steps: {}, flags: {}, quiz: {}, badges: {} }, load());
  function save() { try { localStorage.setItem(KEY, JSON.stringify(state)); } catch (e) { /* private mode */ } }

  const LEVELS = [
    [0, "Cloud Cadet"], [300, "Packet Padawan"], [800, "IAM Illusionist"], [1500, "Threat Hunter"],
    [2500, "Crypto Knight"], [4000, "Kraken Slayer"], [6000, "Skyfortress Legend"],
  ];
  function xp() {
    let total = Object.keys(state.steps).length * 10;
    for (const k in state.flags) total += state.flags[k] || 0;
    for (const k in state.quiz) for (const q in state.quiz[k]) if (state.quiz[k][q]) total += 20;
    return total;
  }
  function level(x) { let l = LEVELS[0]; for (const L of LEVELS) if (x >= L[0]) l = L; return l[1]; }

  // ---------------------------------------------------------------- nav + footer
  const LINKS = [
    ["index.html", "Home"], ["plan.html", "Plan"], ["setup.html", "Lab 0"],
    ["day1.html", "Day 1"], ["day2.html", "Day 2"], ["day3.html", "Day 3"],
    ["day4.html", "Day 4"], ["day5.html", "Day 5"], ["gameday.html", "GameDay"], ["resources.html", "Arsenal"],
  ];
  const TIPS = { "day1.html": "Keys to the Kingdom: identity", "day2.html": "Eyes in the Sky: detection", "day3.html": "Walls & Moats: infrastructure",
    "day4.html": "Vaults & Thinking Machines: data + AI", "day5.html": "Kraken Rising: incident response" };
  const here = (location.pathname.split("/").pop() || "index.html");
  const nav = document.getElementById("site-nav");
  if (nav) {
    nav.className = "site-nav";
    nav.innerHTML =
      '<div class="container inner">' +
      '<a class="brand" href="' + root + 'index.html"><img src="' + root + 'assets/img/logo.svg" alt="">' +
      '<span>Skyfortress<small>Adv. AWS Security · 2026</small></span></a>' +
      '<button class="nav-toggle" aria-label="Menu">☰</button>' +
      '<div class="nav-links">' +
      LINKS.map(([h, t]) => '<a href="' + root + h + '"' + (TIPS[h] ? ' title="' + TIPS[h] + '"' : "") + (h === here ? ' class="active"' : "") + ">" + t + "</a>").join("") +
      '<a class="xp-pill" href="' + root + 'index.html#badges" title="Your progress (stored in this browser)">⚡ <span class="xp-val">0</span> XP · <span class="lvl">Cadet</span></a>' +
      "</div></div>";
    nav.querySelector(".nav-toggle").addEventListener("click", () => nav.querySelector(".nav-links").classList.toggle("open"));
  }
  const foot = document.getElementById("site-footer");
  if (foot) {
    foot.className = "site-footer";
    foot.innerHTML =
      '<div class="container inner"><div><b style="color:#fff;font-family:var(--display)">Operation Skyfortress</b><br>' +
      "An advanced, hands-on AWS security bootcamp · 2026 edition.<br>" +
      "Nimbus Interstellar and The Kraken Collective are fictional. Run labs only in sandbox accounts you own.</div>" +
      '<div><a href="' + root + 'plan.html">Course plan</a> · <a href="' + root + 'setup.html">Lab 0 setup</a> · ' +
      '<a href="' + root + 'resources.html">Arsenal</a> · <a href="#" id="reset-progress">Reset my progress</a></div></div>';
    foot.querySelector("#reset-progress").addEventListener("click", (e) => {
      e.preventDefault();
      if (confirm("Reset all XP, flags, and badges stored in this browser?")) { localStorage.removeItem(KEY); location.reload(); }
    });
  }
  function renderXP() {
    const x = xp();
    document.querySelectorAll(".xp-val").forEach((n) => (n.textContent = x.toLocaleString()));
    document.querySelectorAll(".xp-pill .lvl, .xp-level").forEach((n) => (n.textContent = level(x)));
    document.querySelectorAll(".xp-bar > i").forEach((n) => {
      let next = LEVELS.find((L) => L[0] > x); let prev = [...LEVELS].reverse().find((L) => L[0] <= x);
      n.style.width = next ? ((x - prev[0]) / (next[0] - prev[0])) * 100 + "%" : "100%";
    });
    document.querySelectorAll(".badge[data-badge]").forEach((b) => b.classList.toggle("earned", !!state.badges[b.dataset.badge]));
  }

  // ---------------------------------------------------------------- toast + confetti
  let toastEl;
  function toast(msg, icon) {
    if (!toastEl) { toastEl = document.createElement("div"); toastEl.className = "toast"; document.body.appendChild(toastEl); }
    toastEl.innerHTML = (icon ? '<img src="' + icon + '" alt="">' : "⚡") + "<span>" + msg + "</span>";
    toastEl.classList.add("show");
    clearTimeout(toastEl._t);
    toastEl._t = setTimeout(() => toastEl.classList.remove("show"), 3600);
  }
  function confetti(n) {
    const colors = ["#ff9900", "#22d3ee", "#a78bfa", "#f472b6", "#34d399", "#fbbf24"];
    for (let i = 0; i < (n || 90); i++) {
      const c = document.createElement("i");
      c.className = "confetti";
      c.style.left = Math.random() * 100 + "vw";
      c.style.background = colors[i % colors.length];
      c.style.animationDuration = 2 + Math.random() * 2.5 + "s";
      c.style.animationDelay = Math.random() * 0.4 + "s";
      c.style.borderRadius = Math.random() > 0.5 ? "50%" : "2px";
      document.body.appendChild(c);
      setTimeout(() => c.remove(), 5200);
    }
  }
  window.Skyfortress = { toast, confetti, state, xp, level };

  // ---------------------------------------------------------------- starfield
  const cvs = document.createElement("canvas");
  cvs.id = "stars";
  document.body.prepend(cvs);
  const ctx = cvs.getContext("2d");
  let stars = [], W, H;
  function resize() {
    W = cvs.width = innerWidth * devicePixelRatio; H = cvs.height = innerHeight * devicePixelRatio;
    cvs.style.width = innerWidth + "px"; cvs.style.height = innerHeight + "px";
    stars = Array.from({ length: Math.min(260, Math.floor((innerWidth * innerHeight) / 6000)) }, () => ({
      x: Math.random() * W, y: Math.random() * H, r: Math.random() * 1.3 + 0.2, t: Math.random() * 6.28, s: Math.random() * 0.02 + 0.004,
    }));
  }
  resize(); addEventListener("resize", resize);
  const still = matchMedia("(prefers-reduced-motion: reduce)").matches;
  let shoot = null;
  (function frame() {
    ctx.clearRect(0, 0, W, H);
    for (const s of stars) {
      s.t += s.s;
      ctx.globalAlpha = 0.35 + Math.sin(s.t) * 0.3 + 0.3;
      ctx.fillStyle = "#cfd8ff";
      ctx.beginPath(); ctx.arc(s.x, s.y, s.r * devicePixelRatio, 0, 6.28); ctx.fill();
    }
    if (!shoot && Math.random() < 0.003) shoot = { x: Math.random() * W, y: Math.random() * H * 0.4, l: 0 };
    if (shoot) {
      shoot.l += 18;
      const g = ctx.createLinearGradient(shoot.x + shoot.l, shoot.y + shoot.l * 0.4, shoot.x + shoot.l - 160, shoot.y + shoot.l * 0.4 - 64);
      g.addColorStop(0, "rgba(255,255,255,0.9)"); g.addColorStop(1, "rgba(255,255,255,0)");
      ctx.globalAlpha = 1; ctx.strokeStyle = g; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(shoot.x + shoot.l, shoot.y + shoot.l * 0.4); ctx.lineTo(shoot.x + shoot.l - 160, shoot.y + shoot.l * 0.4 - 64); ctx.stroke();
      if (shoot.l > 700) shoot = null;
    }
    if (!still) requestAnimationFrame(frame);
  })();

  // ---------------------------------------------------------------- reveal
  const io = new IntersectionObserver((es) => es.forEach((e) => { if (e.isIntersecting) { e.target.classList.add("in"); io.unobserve(e.target); } }), { threshold: 0.08 });
  document.querySelectorAll(".reveal").forEach((el) => io.observe(el));

  // ---------------------------------------------------------------- copy buttons
  document.querySelectorAll("pre").forEach((pre) => {
    if (pre.closest(".term")) return; // terminal screenshots are expected output, not commands
    const b = document.createElement("button");
    b.className = "copy-btn"; b.type = "button"; b.textContent = "copy";
    b.addEventListener("click", () => {
      const text = (pre.querySelector("code") || pre).innerText;
      navigator.clipboard.writeText(text).then(() => {
        b.textContent = "copied ✓"; b.classList.add("ok");
        setTimeout(() => { b.textContent = "copy"; b.classList.remove("ok"); }, 1600);
      });
    });
    pre.appendChild(b);
  });

  // ---------------------------------------------------------------- tabs
  document.querySelectorAll(".tabs").forEach((t, ti) => {
    const btns = t.querySelectorAll(":scope > .tab-list > button");
    const panels = t.querySelectorAll(":scope > .tab-panel");
    btns.forEach((b, i) => {
      b.type = "button";
      b.setAttribute("aria-selected", i === 0 ? "true" : "false");
      b.addEventListener("click", () => {
        btns.forEach((x) => x.setAttribute("aria-selected", "false"));
        panels.forEach((p) => p.classList.remove("active"));
        b.setAttribute("aria-selected", "true");
        panels[i] && panels[i].classList.add("active");
      });
    });
    panels[0] && panels[0].classList.add("active");
  });

  // ---------------------------------------------------------------- auto TOC
  const toc = document.querySelector("nav.toc[data-auto]");
  if (toc) {
    const items = document.querySelectorAll(".day-content > section[id], .day-content .lab[id], .day-content .module[id]");
    let html = '<div class="toc-title">On this page</div>';
    items.forEach((el) => {
      const h = el.querySelector("h2, h3");
      if (!h) return;
      const isLab = el.classList.contains("lab");
      const isSub = isLab || el.classList.contains("module");
      const label = el.dataset.toc || h.textContent.replace(/\s+/g, " ").trim();
      html += '<a href="#' + el.id + '" class="' + (isSub ? "sub " : "") + (isLab ? "lab-link" : "") + '">' + label + "</a>";
    });
    html += '<div class="progress"><div class="toc-title">Day progress <span class="day-pct">0%</span></div><div class="bar day-bar"><i></i></div></div>';
    toc.innerHTML = html;
    const links = [...toc.querySelectorAll("a")];
    const spy = new IntersectionObserver((es) => {
      es.forEach((e) => {
        if (e.isIntersecting) {
          links.forEach((l) => l.classList.toggle("active", l.getAttribute("href") === "#" + e.target.id));
        }
      });
    }, { rootMargin: "-30% 0px -60% 0px" });
    items.forEach((el) => spy.observe(el));
  }

  // ---------------------------------------------------------------- steps
  function labProgress() {
    let total = 0, done = 0;
    document.querySelectorAll("ol.steps[data-lab]").forEach((ol) => {
      const lis = ol.querySelectorAll(":scope > li");
      const d = ol.querySelectorAll(":scope > li.done").length;
      total += lis.length; done += d;
      const lab = ol.closest(".lab");
      if (lab) {
        let t = 0, dn = 0;
        lab.querySelectorAll("ol.steps[data-lab] > li").forEach((li) => { t++; if (li.classList.contains("done")) dn++; });
        const bar = lab.querySelector(".lab-progress");
        if (bar) { bar.querySelector(".lp-txt").textContent = dn + "/" + t + " steps"; bar.querySelector(".bar > i").style.width = (t ? (dn / t) * 100 : 0) + "%"; }
      }
    });
    const pct = total ? Math.round((done / total) * 100) : 0;
    document.querySelectorAll(".day-pct").forEach((n) => (n.textContent = pct + "%"));
    document.querySelectorAll(".day-bar > i").forEach((n) => (n.style.width = pct + "%"));
  }
  document.querySelectorAll(".lab").forEach((lab) => {
    const head = lab.querySelector(".lab-head");
    if (head && !head.querySelector(".lab-progress") && lab.querySelector("ol.steps[data-lab]")) {
      const p = document.createElement("div");
      p.className = "lab-progress";
      p.innerHTML = '<span class="lp-txt">0 steps</span><div class="bar"><i></i></div>';
      head.appendChild(p);
    }
  });
  document.querySelectorAll("ol.steps[data-lab]").forEach((ol) => {
    ol.querySelectorAll(":scope > li").forEach((li, i) => {
      const id = ol.dataset.lab + "-s" + (i + 1);
      const b = document.createElement("button");
      b.type = "button"; b.className = "step-check";
      const paint = () => { const d = !!state.steps[id]; li.classList.toggle("done", d); b.textContent = d ? "done ✓" : "mark done"; };
      b.addEventListener("click", () => {
        if (state.steps[id]) delete state.steps[id];
        else { state.steps[id] = 1; toast("+10 XP · step complete"); }
        save(); paint(); renderXP(); labProgress();
      });
      li.appendChild(b); paint();
    });
  });
  labProgress();

  // ---------------------------------------------------------------- sha256 (fallback for non-secure contexts)
  function sha256Fallback(ascii) {
    function rr(v, a) { return (v >>> a) | (v << (32 - a)); }
    const maxWord = Math.pow(2, 32); let result = ""; const words = []; const bitLen = ascii.length * 8;
    let hash = [], k = []; let primeCounter = 0; const isComposite = {};
    for (let c = 2; primeCounter < 64; c++) {
      if (!isComposite[c]) {
        for (let i = 0; i < 313; i += c) isComposite[i] = c;
        hash[primeCounter] = (Math.pow(c, 0.5) * maxWord) | 0;
        k[primeCounter++] = (Math.pow(c, 1 / 3) * maxWord) | 0;
      }
    }
    hash = hash.slice(0, 8);
    ascii += "\x80";
    while ((ascii.length % 64) - 56) ascii += "\x00";
    for (let i = 0; i < ascii.length; i++) { const j = ascii.charCodeAt(i); words[i >> 2] |= j << (((3 - i) % 4) * 8); }
    words[words.length] = (bitLen / maxWord) | 0; words[words.length] = bitLen;
    for (let j = 0; j < words.length;) {
      const w = words.slice(j, (j += 16)); const old = hash; hash = hash.slice(0, 8);
      for (let i = 0; i < 64; i++) {
        const w15 = w[i - 15], w2 = w[i - 2]; const a = hash[0], e = hash[4];
        const t1 = hash[7] + (rr(e, 6) ^ rr(e, 11) ^ rr(e, 25)) + ((e & hash[5]) ^ (~e & hash[6])) + k[i] +
          (w[i] = i < 16 ? w[i] : (w[i - 16] + (rr(w15, 7) ^ rr(w15, 18) ^ (w15 >>> 3)) + w[i - 7] + (rr(w2, 17) ^ rr(w2, 19) ^ (w2 >>> 10))) | 0);
        const t2 = (rr(a, 2) ^ rr(a, 13) ^ rr(a, 22)) + ((a & hash[1]) ^ (a & hash[2]) ^ (hash[1] & hash[2]));
        hash = [(t1 + t2) | 0].concat(hash); hash[4] = (hash[4] + t1) | 0;
      }
      for (let i = 0; i < 8; i++) hash[i] = (hash[i] + old[i]) | 0;
    }
    for (let i = 0; i < 8; i++) for (let j = 3; j + 1; j--) { const b = (hash[i] >> (j * 8)) & 255; result += (b < 16 ? "0" : "") + b.toString(16); }
    return result;
  }
  async function sha256(s) {
    if (window.crypto && crypto.subtle) {
      const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
      return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
    }
    return sha256Fallback(unescape(encodeURIComponent(s)));
  }

  // ---------------------------------------------------------------- flags
  function bossCheck() {
    document.querySelectorAll(".boss[data-flag]").forEach((b) => b.classList.toggle("defeated", !!state.flags[b.dataset.flag]));
  }
  document.querySelectorAll("form.flag").forEach((f) => {
    const id = f.dataset.id, hash = (f.dataset.hash || "").toLowerCase(), pts = parseInt(f.dataset.xp || "100", 10);
    if (!f.querySelector("input")) {
      f.innerHTML = '<span class="flag-ico">🚩</span><div><label>' + (f.dataset.label || "Capture the flag") + " · " + pts + " XP</label>" +
        '<input type="text" placeholder="SKY{...}" autocomplete="off" spellcheck="false"></div><button type="submit">Submit</button><div class="msg"></div>';
    }
    const input = f.querySelector("input"), msg = f.querySelector(".msg");
    if (state.flags[id] !== undefined) { f.classList.add("captured"); input.value = "✓ captured"; input.disabled = true; msg.textContent = "Flag captured. Nice work, operator."; }
    f.addEventListener("submit", async (e) => {
      e.preventDefault();
      if (state.flags[id] !== undefined) return;
      const h = await sha256(input.value.trim());
      if (h === hash) {
        state.flags[id] = pts;
        if (f.dataset.badge) state.badges[f.dataset.badge] = 1;
        save();
        f.classList.add("captured"); input.disabled = true; msg.textContent = "✓ Correct! +" + pts + " XP";
        toast("🚩 Flag captured · +" + pts + " XP" + (f.dataset.badge ? " · badge unlocked!" : ""), f.dataset.badge ? root + "assets/img/badges/" + f.dataset.badge + ".svg" : null);
        confetti(f.dataset.badge ? 160 : 70);
        renderXP(); bossCheck();
      } else {
        msg.textContent = "✗ Not quite. Check the exact casing and braces — flags look like SKY{...}";
        f.classList.remove("shake"); void f.offsetWidth; f.classList.add("shake");
      }
    });
  });
  bossCheck();

  // ---------------------------------------------------------------- quizzes
  document.querySelectorAll(".quiz[data-id]").forEach((quiz) => {
    const qid = quiz.dataset.id;
    state.quiz[qid] = state.quiz[qid] || {};
    const qs = quiz.querySelectorAll(".q");
    const scoreEl = quiz.parentElement.querySelector(".quiz-score");
    const paintScore = () => {
      if (!scoreEl) return;
      const s = state.quiz[qid]; const answered = Object.keys(s).length; const right = Object.values(s).filter(Boolean).length;
      scoreEl.textContent = right + " / " + qs.length + " correct" + (answered < qs.length ? " · " + (qs.length - answered) + " to go" : " · complete!");
    };
    qs.forEach((q, i) => {
      const first = q.querySelector("p");
      if (first) first.dataset.n = "Q" + (i + 1) + ". ";
      const ans = q.dataset.answer;
      const btns = q.querySelectorAll(".opts button");
      const lock = (picked) => {
        q.classList.add("answered");
        btns.forEach((b) => {
          b.disabled = true;
          if (b.dataset.k === ans) b.classList.add("right");
          else if (b.dataset.k === picked) b.classList.add("wrong");
        });
      };
      btns.forEach((b) => {
        b.type = "button";
        b.addEventListener("click", () => {
          const ok = b.dataset.k === ans;
          state.quiz[qid][i] = ok; save(); lock(b.dataset.k); paintScore(); renderXP();
          toast(ok ? "+20 XP · correct!" : "Not this time — read the explanation 👀");
          if (ok && Object.values(state.quiz[qid]).filter(Boolean).length === qs.length) confetti(60);
        });
      });
      if (q.dataset.k === undefined && state.quiz[qid][i] !== undefined) lock(state.quiz[qid][i] ? ans : "__");
    });
    paintScore();
  });

  // ---------------------------------------------------------------- lightbox
  const lb = document.createElement("div");
  lb.className = "lightbox"; lb.setAttribute("role", "dialog"); lb.setAttribute("aria-label", "Enlarged image");
  lb.innerHTML = '<div><img alt=""><div class="cap"></div></div>';
  document.body.appendChild(lb);
  const closeLb = () => lb.classList.remove("open");
  lb.addEventListener("click", closeLb);
  addEventListener("keydown", (e) => { if (e.key === "Escape") closeLb(); });
  document.querySelectorAll(".figure img, figure.shot img, img.zoomable").forEach((img) => {
    if (img.closest("a")) { img.style.cursor = "pointer"; return; } // linked images navigate instead
    img.addEventListener("click", () => {
      lb.querySelector("img").src = img.currentSrc || img.src;
      lb.querySelector("img").alt = img.alt || "";
      const cap = img.closest("figure") && img.closest("figure").querySelector("figcaption");
      lb.querySelector(".cap").textContent = cap ? cap.textContent : img.alt || "";
      lb.classList.add("open");
    });
  });

  // ---------------------------------------------------------------- back to top + reading progress
  const top = document.createElement("button");
  top.className = "to-top"; top.type = "button"; top.setAttribute("aria-label", "Back to top"); top.textContent = "↑";
  top.addEventListener("click", () => scrollTo({ top: 0, behavior: "smooth" }));
  document.body.appendChild(top);
  const rp = document.createElement("div"); rp.className = "read-progress"; document.body.appendChild(rp);
  const onScroll = () => {
    const h = document.documentElement.scrollHeight - innerHeight;
    rp.style.width = (h > 0 ? (scrollY / h) * 100 : 0) + "%";
    top.classList.toggle("show", scrollY > 900);
  };
  addEventListener("scroll", onScroll, { passive: true }); onScroll();

  renderXP();
})();
