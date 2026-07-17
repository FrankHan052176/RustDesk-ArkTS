export interface SessionToolbarMetrics {
  fps: string;
  frames: string;
  decode: string;
  delay: string;
  codec: string;
}

export function formatSessionToolbarMetrics(
  fps: number,
  totalFrames: number,
  decodeLatencyMs: number | undefined,
  hasRenderedFrame: boolean,
  delay: string,
  codec: string,
): SessionToolbarMetrics {
  return {
    fps: hasRenderedFrame && Number.isFinite(fps) ? fps.toFixed(1) : '--',
    frames: hasRenderedFrame && Number.isFinite(totalFrames) ? Math.round(totalFrames).toString() : '--',
    decode: decodeLatencyMs !== undefined && decodeLatencyMs > 0
      ? `${Math.round(decodeLatencyMs)}ms`
      : '--',
    delay: delay.trim().length > 0 ? delay.trim() : '--',
    codec: codec.trim().length > 0 ? codec.trim() : '--',
  };
}
