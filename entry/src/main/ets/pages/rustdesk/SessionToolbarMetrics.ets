/**
 * What the session toolbar's metric row shows.
 *
 * Each value is a bare number with its unit appended by the toolbar itself, or
 * `--` where the value has not been measured.
 */
export interface SessionToolbarMetrics {
  /** Successful submissions per second, not physical scanout. */
  fps: string;
  /** Network round-trip time in milliseconds. */
  delay: string;
  /** The codec this session's decoder opened with. */
  codec: string;
}

/**
 * Formats the toolbar's metric row.
 *
 * `submittedFps` is the frame snapshot's own submission rate -- a Core status
 * tick, or a direct VNC/RDP wire's successful Surface submissions -- and
 * `networkRttMs` is the peer's own measured round trip. Neither is derived from
 * the panel's refresh rate, from the requested capture rate, or from the
 * quality event's display-frame count, which this build's H.264/H.265 Surface
 * path does not measure.
 */
export function formatSessionToolbarMetrics(
  submittedFps: string,
  networkRttMs: string,
  codec: string,
): SessionToolbarMetrics {
  return {
    fps: submittedFps.trim().length > 0 ? submittedFps.trim() : '--',
    delay: networkRttMs.trim().length > 0 ? networkRttMs.trim() : '--',
    codec: codec.trim().length > 0 ? codec.trim() : '--',
  };
}
