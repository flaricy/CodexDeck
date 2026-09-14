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
