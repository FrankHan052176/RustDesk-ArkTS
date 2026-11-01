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
  /**
   * Whether a Down for this button reached the peer.
   *
   * An entry that is not held is a press whose Down the engine refused: the peer
   * never got it, so it is not the peer's button and must not be released later.
   */
  held: boolean;

  constructor(mode: RustDeskPointerMode, held: boolean) {
    this.mode = mode;
    this.held = held;
  }
}

/**
 * What the peer's buttons are holding, and who on this page holds them.
 *
 * A held entry is the peer's own button: it is created by a Down whose send was
 * accepted and removed only by an Up the engine accepted. Its owner set is the
 * page's own presses, so an entry with no owners and a hold is a release this
 * page still owes the peer — a state that outlives the owner. A press that
 * arrives while the peer already holds the button joins that entry instead of
 * pressing the peer's button a second time, which is what keeps a retried release
 * from cancelling a press the operator has already started.
 */
export class RustDeskPressedButtonState {
  private buttons: Map<string, RustDeskPressedButton> = new Map();

  /**
   * Registers a press of `button` and answers whether the caller must send it.
   *
   * A Down is due when the peer is not known to hold the button, and also when an
   * entry is left without an owner: that entry is a release the engine has not
   * accepted yet, so the press has to re-state itself on the wire instead of
   * leaving the hold resting on a release nobody sent.
   */
  acquire(
    button: string,
    owner: RustDeskPressedButtonOwner,
    mode: RustDeskPointerMode,
  ): RustDeskPressedButtonTransition | undefined {
    const pressedButton = this.buttons.get(button);
    if (pressedButton !== undefined) {
      if (pressedButton.owners.size > 0) {
        pressedButton.owners.add(owner);
        return undefined;
      }
      pressedButton.mode = mode;
      pressedButton.owners.add(owner);
      return { type: 'down', button, mode };
    }
    const newPressedButton = new RustDeskPressedButton(mode, false);
    newPressedButton.owners.add(owner);
    this.buttons.set(button, newPressedButton);
    return { type: 'down', button, mode };
  }

  /** Records that a Down for `button` reached the peer. */
  confirmHeld(button: string): void {
    const pressedButton = this.buttons.get(button);
    if (pressedButton !== undefined) {
      pressedButton.held = true;
    }
  }

  /**
   * Drops an ownership whose Down the engine refused.
   *
   * The press holds nothing, so an entry that was never held goes with it; a hold
   * the peer already had stays, because it is still that peer's button and still
   * owes its release.
   */
  abandon(button: string, owner: RustDeskPressedButtonOwner): void {
    const pressedButton = this.buttons.get(button);
    if (pressedButton === undefined) {
      return;
    }
    pressedButton.owners.delete(owner);
    if (pressedButton.owners.size === 0 && !pressedButton.held) {
      this.buttons.delete(button);
    }
  }

  /**
   * Drops `owner`'s press and answers the Up that is due.
   *
   * The Up belongs to the last owner: while another owner still holds the button
   * the peer's button stays down, and an owner the wire never registered has
   * nothing to release. The entry stays behind after the last owner leaves —
   * that leftover is the release this page still owes, and the next press takes
   * it over rather than inheriting a stale owner.
   */
  release(button: string, owner: RustDeskPressedButtonOwner): RustDeskPressedButtonTransition | undefined {
    const pressedButton = this.buttons.get(button);
    if (pressedButton === undefined || !pressedButton.owners.has(owner)) {
      return undefined;
    }
    pressedButton.owners.delete(owner);
    if (pressedButton.owners.size > 0) {
      return undefined;
    }
    if (!pressedButton.held) {
      this.buttons.delete(button);
    }
    return { type: 'up', button, mode: pressedButton.mode };
  }

  hasOwner(button: string, owner: RustDeskPressedButtonOwner): boolean {
    const pressedButton = this.buttons.get(button);
    return pressedButton !== undefined && pressedButton.owners.has(owner);
  }

  /**
   * Lets go of every owner, answering the Up each held button owes.
   *
   * One transition per button name, however many owners held it: the peer's
   * button is one button, so a boundary release sends one Up for it — including
   * the buttons left owing one. A release the caller cannot send leaves the entry
   * behind with no owners, which is this state still owing the peer an Up.
   */
  releaseOwners(): Array<RustDeskPressedButtonTransition> {
    const transitions: Array<RustDeskPressedButtonTransition> = [];
    this.buttons.forEach((pressedButton: RustDeskPressedButton, button: string) => {
      pressedButton.owners.clear();
      transitions.push({ type: 'up', button, mode: pressedButton.mode });
    });
    return transitions;
  }

  /** The buttons the peer holds with no owner left holding them. */
  owedButtons(): Array<string> {
    const buttons: Array<string> = [];
    this.buttons.forEach((pressedButton: RustDeskPressedButton, button: string) => {
      if (pressedButton.held && pressedButton.owners.size === 0) {
        buttons.push(button);
      }
    });
    return buttons;
  }

  /** Drops a button whose Up the engine accepted. */
  confirmReleased(button: string): void {
    this.buttons.delete(button);
  }

  /** Drops every ownership without sending anything: the session is gone. */
  clear(): void {
    this.buttons.clear();
  }

  /**
   * The destructive form older callers use: one Up per held button, then empty.
   *
   * Kept as it is for the legacy controller, which owns its own release path and
   * never confirms an Up; the session page releases through `releaseOwners` and
   * commits the buttons the engine accepted.
   */
  releaseAll(): Array<RustDeskPressedButtonTransition> {
    const transitions: Array<RustDeskPressedButtonTransition> = [];
    this.buttons.forEach((pressedButton: RustDeskPressedButton, button: string) => {
      transitions.push({ type: 'up', button, mode: pressedButton.mode });
    });
    this.buttons.clear();
    return transitions;
  }
}
