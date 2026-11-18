type Child = Node | string | null | undefined | false;

type Attributes = Readonly<Record<string, string | boolean | undefined>>;

export function h<K extends keyof HTMLElementTagNameMap>(
  tag: K,
  attributes: Attributes = {},
  ...children: readonly Child[]
): HTMLElementTagNameMap[K] {
  const element = document.createElement(tag);
  for (const [name, value] of Object.entries(attributes)) {
    if (value === undefined || value === false) continue;
    if (name === "className") {
      element.className = String(value);
    } else if (value === true) {
      element.setAttribute(name, "");
    } else {
      element.setAttribute(name, value);
    }
  }
  append(element, children);
  return element;
}

export function append(parent: Node, children: readonly Child[]): void {
  for (const child of children) {
    if (child === null || child === undefined || child === false) continue;
    parent.appendChild(typeof child === "string" ? document.createTextNode(child) : child);
  }
}

export function replace(parent: Element, children: readonly Child[]): void {
  parent.replaceChildren();
  append(parent, children);
}
