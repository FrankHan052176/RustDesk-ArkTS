export type RustDeskPressedButtonOwner = 'physical_mouse' | 'touch_drag' | 'touch_click';
export type RustDeskPointerMode = 'absolute' | 'relative';
export type RustDeskPressedButtonTransitionType = 'down' | 'up';

export interface RustDeskPressedButtonTransition {
  type: RustDeskPressedButtonTransitionType;
  button: string;
  mode: RustDeskPointerMode;
}

class RustDeskPressedButton {
  mode: RustDeskPointerMode;
  owners: Set<RustDeskPressedButtonOwner> = new Set();

  constructor(mode: RustDeskPointerMode) {
    this.mode = mode;
  }
}

export class RustDeskPressedButtonState {
  private buttons: Map<string, RustDeskPressedButton> = new Map();

  acquire(
    button: string,
    owner: RustDeskPressedButtonOwner,
    mode: RustDeskPointerMode,
  ): RustDeskPressedButtonTransition | undefined {
    const pressedButton = this.buttons.get(button);
    if (pressedButton !== undefined) {
      if (pressedButton.owners.has(owner)) {
        return undefined;
      }
      pressedButton.owners.add(owner);
      return undefined;
    }
    const newPressedButton = new RustDeskPressedButton(mode);
    newPressedButton.owners.add(owner);
    this.buttons.set(button, newPressedButton);
    return { type: 'down', button, mode };
  }

  release(button: string, owner: RustDeskPressedButtonOwner): RustDeskPressedButtonTransition | undefined {
    const pressedButton = this.buttons.get(button);
    if (pressedButton === undefined || !pressedButton.owners.has(owner)) {
      return undefined;
    }
    pressedButton.owners.delete(owner);
    if (pressedButton.owners.size > 0) {
      return undefined;
    }
    this.buttons.delete(button);
    return { type: 'up', button, mode: pressedButton.mode };
  }

  hasOwner(button: string, owner: RustDeskPressedButtonOwner): boolean {
    const pressedButton = this.buttons.get(button);
    return pressedButton !== undefined && pressedButton.owners.has(owner);
  }

  releaseAll(): Array<RustDeskPressedButtonTransition> {
    const transitions: Array<RustDeskPressedButtonTransition> = [];
    this.buttons.forEach((pressedButton: RustDeskPressedButton, button: string) => {
      transitions.push({ type: 'up', button, mode: pressedButton.mode });
    });
    this.buttons.clear();
    return transitions;
  }
}
