/**
 * @jest-environment jsdom
 */

/* global Elm */

const childProcess = require("child_process");
const fs = require("fs");
const path = require("path");

const ELM_COMPILER = process.env.ELM_COMPILER || "elm";

function cleanupDocument() {
  while (document.body.firstChild) {
    document.body.firstChild.remove();
  }

  document.title = "";
  history.replaceState(null, "", "/");
}

/**
 * @returns {Promise<void>}
 */
function nextFrame() {
  return new Promise((resolve) => {
    requestAnimationFrame(() => resolve());
  });
}

/**
 * @param {string} portName
 * @param {string} elementId
 * @param {{ (el: HTMLElement): void | Promise<void> }} trigger
 *
 * @returns {Promise<Array<unknown>>}
 */
async function getValuesFromEvent(portName, elementId, trigger) {
  const element = document.createElement("div");

  // @ts-ignore
  const app = Elm.AllHtmlEvents.init({ node: element });

  const values = [];
  app.ports[portName].subscribe((x) => {
    values.push(x);
  });

  await nextFrame();

  /** @type {HTMLElement?} */
  const child = element.querySelector(`#${elementId}`);

  if (child === null) {
    throw new Error("Element does not exist");
  }

  await trigger(child);

  await nextFrame();

  return values;
}

beforeAll(() => {
  const files = fs
    .readdirSync(__dirname)
    .flatMap((file) => (path.extname(file) === ".elm" ? [path.join(__dirname, file)] : []));
  const output = path.join(__dirname, "generated", "elm.js");
  const result = childProcess.spawnSync(ELM_COMPILER, ["make", ...files, "--output", output], {
    shell: true,
    cwd: __dirname,
    stdio: ["ignore", "ignore", "inherit"],
  });
  if (result.status !== 0) {
    console.error(result.stderr);

    // eslint-disable-next-line unicorn/no-process-exit
    process.exit(result.status || 1);
  }

  const code = fs.readFileSync(output, "utf8");
  const newCode = code
    .replace(/\(this\)\);\s*$/, "(window));")
    .replace(/console.warn\('[^']+'\);/, "");
  fs.writeFileSync(output, newCode);
  require(output);
}, 60 * 1000);

beforeEach(() => {
  cleanupDocument();
});

test("click", async () => {
  /**
   * @argument {HTMLElement} el
   */
  const trigger = (element) => element.click();
  expect(await getValuesFromEvent("onClick", "click-me", trigger)).toEqual([null]);
});

test("double-click", async () => {
  /**
   * @argument {HTMLElement} el
   */
  const trigger = (element) => {
    const event = new MouseEvent("dblclick");
    element.dispatchEvent(event);
  };

  expect(await getValuesFromEvent("onDoubleClick", "double-click-me", trigger)).toEqual([null]);
});

test("mousedown", async () => {
  /**
   * @argument {HTMLElement} el
   */
  const trigger = (element) => {
    const event = new MouseEvent("mousedown");
    element.dispatchEvent(event);
  };

  expect(await getValuesFromEvent("onMouseDown", "mousedown-me", trigger)).toEqual([null]);
});

test("mouseup", async () => {
  /**
   * @argument {HTMLElement} el
   */
  const trigger = (element) => {
    const event = new MouseEvent("mouseup");
    element.dispatchEvent(event);
  };

  expect(await getValuesFromEvent("onMouseUp", "mouseup-me", trigger)).toEqual([null]);
});

test("mouseenter", async () => {
  /**
   * @argument {HTMLElement} el
   */
  const trigger = (element) => {
    const event = new MouseEvent("mouseenter");
    element.dispatchEvent(event);
  };

  expect(await getValuesFromEvent("onMouseEnter", "mouseenter-me", trigger)).toEqual([null]);
});

test("mouseleave", async () => {
  /**
   * @argument {HTMLElement} el
   */
  const trigger = (element) => {
    const event = new MouseEvent("mouseleave");
    element.dispatchEvent(event);
  };

  expect(await getValuesFromEvent("onMouseLeave", "mouseleave-me", trigger)).toEqual([null]);
});

test("mouseover", async () => {
  /**
   * @argument {HTMLElement} el
   */
  const trigger = (element) => {
    const event = new MouseEvent("mouseover");
    element.dispatchEvent(event);
  };

  expect(await getValuesFromEvent("onMouseOver", "mouseover-me", trigger)).toEqual([null]);
});

test("mouseout", async () => {
  /**
   * @argument {HTMLElement} el
   */
  const trigger = (element) => {
    const event = new MouseEvent("mouseout");
    element.dispatchEvent(event);
  };

  expect(await getValuesFromEvent("onMouseOut", "mouseout-me", trigger)).toEqual([null]);
});

test("form-input", async () => {
  /**
   * @argument {HTMLElement} el
   */
  const trigger = (element) => {
    const event = new MouseEvent("input");
    element.dispatchEvent(event);
  };

  expect(await getValuesFromEvent("onInput", "form-input-me", trigger)).toEqual([
    "value of input form",
  ]);
});

test("form-check", async () => {
  /**
   * @argument {HTMLElement} el
   */
  const trigger = async (element) => {
    if (!(element instanceof HTMLInputElement)) {
      throw new TypeError("el should be input");
    }

    const event = new MouseEvent("change");
    element.checked = true;
    element.dispatchEvent(event);
    await nextFrame();
    element.checked = false;
    element.dispatchEvent(event);
  };

  expect(await getValuesFromEvent("onCheck", "form-check-me", trigger)).toEqual([true, false]);
});

test("form-submit", async () => {
  /**
   * @argument {HTMLElement} el
   */
  const trigger = (element) => {
    const event = new MouseEvent("submit");
    element.dispatchEvent(event);
  };

  expect(await getValuesFromEvent("onSubmit", "form-submit-me", trigger)).toEqual([null]);
});
