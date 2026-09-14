(() => {
  const en = document.documentElement.lang === "en";
  const tasks = en
    ? [
        {
          id: 1,
          title: "Build the design system",
          state: "Running",
          tone: "blue",
        },
        { id: 2, title: "Refine sync logic", state: "Done", tone: "green" },
        { id: 3, title: "Review the release", state: "STOP", tone: "green" },
      ]
    : [
        { id: 1, title: "设计组件库", state: "运行中", tone: "blue" },
        { id: 2, title: "优化同步逻辑", state: "已完成", tone: "green" },
        { id: 3, title: "检查发布流程", state: "STOP", tone: "green" },
      ];
  let visible = tasks.slice(0, 2),
    focused = 1;
  const deck = document.querySelector("#demo-keys");
  const title = document.querySelector("#focused-title");
  const status = document.querySelector("#response-state");
  function render() {
    deck.replaceChildren();
    deck.dataset.size = visible.length;
    document
      .querySelectorAll("[data-count]")
      .forEach((b) =>
        b.setAttribute(
          "aria-pressed",
          String(Number(b.dataset.count) === visible.length),
        ),
      );
    if (!visible.length) {
      const empty = document.createElement("div");
      empty.className = "empty-deck";
      empty.textContent = en
        ? "A little space for your next task."
        : "为下一个任务留点位置。";
      deck.append(empty);
      return;
    }
    visible.forEach((task, index) => {
      const wrap = document.createElement("div");
      wrap.className = "demo-key-wrap";
      const button = document.createElement("button");
      button.type = "button";
      button.className = `demo-key ${task.tone}`;
      button.setAttribute("aria-label", `${task.title}, ${task.state}`);
      button.setAttribute("aria-pressed", String(focused === task.id));
      const number = document.createElement("span");
      number.className = "number";
      number.textContent = String(index + 1).padStart(2, "0");
      const content = document.createElement("span");
      const name = document.createElement("span");
      name.className = "demo-title";
      name.textContent = task.title;
      const label = document.createElement("span");
      label.className = "demo-label";
      label.textContent = task.state;
      const arrow = document.createElement("span");
      arrow.textContent = "↗";
      arrow.setAttribute("aria-hidden", "true");
      label.append(arrow);
      content.append(name, label);
      button.append(number, content);
      button.addEventListener("click", () => {
        focused = task.id;
        title.textContent = task.title;
        status.textContent = en ? "Switched · demo" : "已切换 · 演示";
        deck.querySelectorAll(".demo-key").forEach((b) => {
          b.classList.remove("is-focused");
          b.setAttribute("aria-pressed", "false");
        });
        button.classList.add("is-focused");
        button.setAttribute("aria-pressed", "true");
      });
      wrap.append(button);
      if (task.tone === "green") {
        const hide = document.createElement("button");
        hide.type = "button";
        hide.className = "hide-key";
        hide.textContent = en ? "Hide" : "不看";
        hide.setAttribute("aria-label", (en ? "Hide " : "隐藏 ") + task.title);
        hide.addEventListener("click", () => {
          visible = visible.filter((t) => t.id !== task.id);
          render();
          const target =
            deck.querySelector("button") ||
            document.querySelector(".reset-demo");
          target.focus();
        });
        wrap.append(hide);
      }
      deck.append(wrap);
    });
  }
  document.querySelectorAll("[data-count]").forEach((b) =>
    b.addEventListener("click", () => {
      visible = tasks.slice(0, Number(b.dataset.count));
      render();
    }),
  );
  document.querySelector(".reset-demo").addEventListener("click", () => {
    visible = tasks.slice(0, 2);
    focused = 1;
    title.textContent = tasks[0].title;
    status.textContent = en ? "Tap a key" : "等待点击";
    render();
  });
  render();
})();

(() => {
  const scene = document.querySelector('.workspace-visual');
  if (!scene) return;
  const en = document.documentElement.lang === 'en';
  const keys = [...scene.querySelectorAll('[data-scene-session]')];
  const tabs = [...scene.querySelectorAll('[data-scene-tab]')];
  const touch = scene.querySelector('.scene-touch');
  const motion = scene.querySelector('.scene-motion');
  const reduced = matchMedia('(prefers-reduced-motion: reduce)');
  const answers = en ? ['The components are taking shape. Refining spacing and typography…', 'Sync is up to date. The changes are ready for your review.', 'Release review paused. Pick up right where you left off.'] : ['组件已逐步成形，正在统一间距与排版…', '同步逻辑已更新，修改已完成，等你检查。', '发布检查已停止，随时可以从这里继续。'];
  const prompts = en ? ['Make every detail feel consistent.', 'Keep my sessions in sync.', 'Check the release before shipping.'] : ['让每一个界面细节保持一致。', '让我的会话始终保持同步。', '发布前，再检查一遍。'];
  let selected = 0, paused = reduced.matches, visible = true, cycle, press, release;
  const cancel = () => { clearTimeout(cycle); clearTimeout(press); clearTimeout(release); touch.classList.remove('visible'); keys.forEach(k => k.classList.remove('pressing')); };
  function render(index) {
    selected = index;
    keys.forEach((key, i) => key.setAttribute('aria-pressed', String(i === index)));
    tabs.forEach((tab, i) => tab.classList.toggle('selected', i === index));
    scene.querySelector('#scene-title').textContent = keys[index].querySelector('b').textContent;
    scene.querySelector('#scene-answer').textContent = answers[index];
    scene.querySelector('.scene-prompt').textContent = prompts[index];
    scene.querySelector('.scene-project').textContent = ['STUDIO / DESIGN', 'APP / CORE', 'SHIP / REVIEW'][index];
    scene.querySelector('#scene-caption').textContent = (en ? 'Mac switched to: ' : 'Mac 已切换：') + keys[index].querySelector('b').textContent;
  }
  function schedule() {
    if (paused || !visible || document.hidden) return;
    cycle = setTimeout(() => activate((selected + 1) % keys.length, true), 3400);
  }
  function activate(index, automatic) {
    cancel();
    const key = keys[index];
    if (!reduced.matches) {
      touch.style.top = `${key.offsetTop + key.offsetHeight / 2}px`;
      // offsetTop is relative to the positioned phone, matching the touch marker.
      touch.classList.add('visible');
    }
    const perform = () => { key.classList.add('pressing'); render(index); release = setTimeout(() => { key.classList.remove('pressing'); touch.classList.remove('visible'); schedule(); }, 650); };
    if (automatic) press = setTimeout(perform, 650); else perform();
  }
  function label() { motion.textContent = paused ? '▶' : 'Ⅱ'; motion.setAttribute('aria-label', en ? (paused ? 'Play animation' : 'Pause animation') : (paused ? '播放动画' : '暂停动画')); }
  keys.forEach((key, index) => key.addEventListener('click', () => activate(index, false)));
  motion.addEventListener('click', () => { paused = !paused; cancel(); label(); schedule(); });
  reduced.addEventListener('change', () => { paused = reduced.matches; cancel(); label(); schedule(); });
  document.addEventListener('visibilitychange', () => { cancel(); schedule(); });
  new IntersectionObserver(entries => { visible = entries[0].isIntersecting; cancel(); schedule(); }, {threshold: .15}).observe(scene);
  label();
})();
