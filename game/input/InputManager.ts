export type InputAction = "up" | "down" | "left" | "right" | "jump" | "skill" | "item";

export type InputHandlers = {
  onAction?: (action: InputAction) => void;
  onJump?: () => void;
  onSkill?: () => void;
  onItem?: () => void;
};

const KEY_TO_ACTION: Record<string, InputAction> = {
  w: "up",
  arrowup: "up",
  s: "down",
  arrowdown: "down",
  a: "left",
  arrowleft: "left",
  d: "right",
  arrowright: "right",
  " ": "jump",
  spacebar: "jump",
  e: "skill",
  q: "item",
};

const PREVENT_DEFAULT_ACTIONS = new Set<InputAction>([
  "up",
  "down",
  "left",
  "right",
  "jump",
]);

function actionFromKeyboardEvent(event: KeyboardEvent): InputAction | undefined {
  if (event.code === "Space") return "jump";
  return KEY_TO_ACTION[event.key.toLowerCase()];
}

type ActiveContext = {
  id: string;
  token: symbol;
  handlers: InputHandlers;
};

/**
 * Central input state for keyboard, touch controls, and future gamepad adapters.
 * React screens activate exactly one context while they need gameplay input.
 */
export class InputManager {
  private activeContext: ActiveContext | null = null;
  private keyboardPressed = new Set<InputAction>();
  private externalPressed = new Map<string, Set<InputAction>>();
  private listening = false;

  activate(id: string, handlers: InputHandlers = {}): () => void {
    const token = Symbol(id);
    this.releaseAll();
    this.activeContext = { id, token, handlers };
    this.attachKeyboard();

    return () => {
      if (this.activeContext?.token !== token) return;
      this.activeContext = null;
      this.releaseAll();
      this.detachKeyboard();
    };
  }

  isPressed(action: InputAction): boolean {
    if (this.keyboardPressed.has(action)) return true;
    for (const actions of this.externalPressed.values()) {
      if (actions.has(action)) return true;
    }
    return false;
  }

  /**
   * Sets movement/action state from non-keyboard sources such as touch controls.
   * A future Gamepad adapter can use a source id like `gamepad:0`.
   */
  setExternalAction(source: string, action: InputAction, pressed: boolean): void {
    let actions = this.externalPressed.get(source);
    if (!actions) {
      actions = new Set<InputAction>();
      this.externalPressed.set(source, actions);
    }

    if (pressed) actions.add(action);
    else actions.delete(action);

    if (actions.size === 0) this.externalPressed.delete(source);
  }

  releaseSource(source: string): void {
    this.externalPressed.delete(source);
  }

  trigger(action: InputAction): void {
    if (!this.activeContext) return;
    this.dispatch(action);
  }

  getActiveContextId(): string | null {
    return this.activeContext?.id ?? null;
  }

  reset(): void {
    this.activeContext = null;
    this.releaseAll();
    this.detachKeyboard();
  }

  private dispatch(action: InputAction): void {
    const handlers = this.activeContext?.handlers;
    if (!handlers) return;

    handlers.onAction?.(action);
    if (action === "jump") handlers.onJump?.();
    if (action === "skill") handlers.onSkill?.();
    if (action === "item") handlers.onItem?.();
  }

  private handleKeyDown = (event: KeyboardEvent): void => {
    if (!this.activeContext) return;
    const action = actionFromKeyboardEvent(event);
    if (!action) return;

    if (PREVENT_DEFAULT_ACTIONS.has(action)) event.preventDefault();

    const isFirstPress = !this.keyboardPressed.has(action);
    this.keyboardPressed.add(action);
    if (isFirstPress) this.dispatch(action);
  };

  private handleKeyUp = (event: KeyboardEvent): void => {
    const action = actionFromKeyboardEvent(event);
    if (!action) return;
    if (PREVENT_DEFAULT_ACTIONS.has(action)) event.preventDefault();
    this.keyboardPressed.delete(action);
  };

  private attachKeyboard(): void {
    if (this.listening || typeof window === "undefined") return;
    window.addEventListener("keydown", this.handleKeyDown);
    window.addEventListener("keyup", this.handleKeyUp);
    this.listening = true;
  }

  private detachKeyboard(): void {
    if (!this.listening || typeof window === "undefined") return;
    window.removeEventListener("keydown", this.handleKeyDown);
    window.removeEventListener("keyup", this.handleKeyUp);
    this.listening = false;
  }

  private releaseAll(): void {
    this.keyboardPressed.clear();
    this.externalPressed.clear();
  }
}

export const inputManager = new InputManager();
