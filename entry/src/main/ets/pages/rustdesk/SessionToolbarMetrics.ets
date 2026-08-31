export interface SessionToolbarMetrics {
  fps: string;
  delay: string;
  codec: string;
}

export function formatSessionToolbarMetrics(
  fps: string,
  delay: string,
  codec: string,
): SessionToolbarMetrics {
  return {
    fps: fps.trim().length > 0 ? fps.trim() : '--',
    delay: delay.trim().length > 0 ? delay.trim() : '--',
    codec: codec.trim().length > 0 ? codec.trim() : '--',
  };
}
