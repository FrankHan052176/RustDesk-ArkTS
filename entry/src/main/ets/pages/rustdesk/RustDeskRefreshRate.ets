/**
 * Refresh-rate choices for the remote session.
 *
 * The rates a device can show are a property of the device: a 60/144 panel has
 * two, an LTPO panel may have several more, and a panel may also expose
 * power-saving rates that are useless for remote control because they read as a
 * lurching picture. So the list offered to the operator is derived from what the
 * system reports, with 30 Hz always present as the low-bandwidth fallback.
 *
 * Everything here is pure so the choice logic can be tested without a device.
 */

/** Absolute bounds the peer accepts; see the session FPS setter. */
export const MIN_REFRESH_RATE = 1;
export const MAX_REFRESH_RATE = 240;

/** Always offered, whatever the panel reports, as the low-bandwidth option. */
export const FALLBACK_REFRESH_RATE = 30;

/**
 * Rates below this are panel power states, not usable picture rates. A remote
 * desktop captured at 10 or 20 Hz is a slideshow, so those are not offered.
 */
export const MIN_USEFUL_REFRESH_RATE = 24;

/** Offered when the system reports nothing usable. */
export const DEFAULT_REFRESH_RATE = 60;

/**
 * The rates to offer for a device.
 *
 * `supported` is `display.Display.supportedRefreshRates`, which is optional and
 * empty on devices that do not implement it; `current` is the rate the panel is
 * running at right now. Both are trusted only after they are range-checked,
 * because a fallback built from a nonsense value would be offered as a choice.
 */
export function resolveRefreshRateChoices(
  supported: number[] | undefined,
  current: number,
): number[] {
  const values: number[] = [];
  const push = (raw: number): void => {
    const value = Math.round(Number(raw));
    if (!Number.isFinite(value)) {
      return;
    }
    if (value < MIN_USEFUL_REFRESH_RATE || value > MAX_REFRESH_RATE) {
      return;
    }
    if (!values.includes(value)) {
      values.push(value);
    }
  };

  if (supported !== undefined && supported.length > 0) {
    supported.forEach((rate: number) => push(rate));
  } else {
    // Without the supported list the only rate the device tells us is the one
    // it is currently using, which is still a better offer than a fixed list.
    push(current);
  }
  push(FALLBACK_REFRESH_RATE);
  return values.sort((left: number, right: number) => left - right);
}

/**
 * The rate to start from: the panel's current rate when it is one of the
 * choices, otherwise the highest offered rate.
 */
export function defaultRefreshRateFor(choices: number[], current: number): number {
  if (choices.length === 0) {
    return DEFAULT_REFRESH_RATE;
  }
  const rounded = Math.round(Number(current));
  if (Number.isFinite(rounded) && choices.includes(rounded)) {
    return rounded;
  }
  return choices[choices.length - 1];
}

/**
 * Whether a rate can be requested at all. This is the peer's bound, not the
 * device's: a default stored on one device has to stay valid when the same
 * session is reopened from another.
 */
export function isValidRefreshRate(value: number): boolean {
  const rounded = Number(value);
  return Number.isFinite(rounded) && rounded >= MIN_REFRESH_RATE && rounded <= MAX_REFRESH_RATE;
}
