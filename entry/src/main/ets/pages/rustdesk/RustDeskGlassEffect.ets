import { hdsEffect } from '@kit.UIDesignKit';

export class RustDeskGlassEffect {
  public static featherReceiver(): VisualEffect {
    return new hdsEffect.HdsEffectBuilder()
      .pointLight({
        illuminatedType: hdsEffect.PointLightIlluminatedType.DEFAULT_FEATHERING_BORDER,
      })
      .buildEffect();
  }

  public static contentReceiver(): VisualEffect {
    return new hdsEffect.HdsEffectBuilder()
      .pointLight({
        illuminatedType: hdsEffect.PointLightIlluminatedType.CONTENT,
      })
      .buildEffect();
  }

  // FrankHanUI point-light-source: touch-action
  public static movableContentSource(
    color: ResourceColor,
    intensity: number,
  ): VisualEffect {
    return new hdsEffect.HdsEffectBuilder()
      .pointLight({
        illuminatedType: hdsEffect.PointLightIlluminatedType.CONTENT,
        options: {
          color,
          intensity,
          height: 68,
          bloom: Math.min(0.14, intensity * 0.22),
        },
      })
      .buildEffect();
  }

  // FrankHanUI point-light-source: special-button
  public static interactiveContent(
    active: boolean,
    color: ResourceColor,
    peakIntensity: number = 0.62,
  ): VisualEffect {
    return new hdsEffect.HdsEffectBuilder()
      .pointLight({
        illuminatedType: hdsEffect.PointLightIlluminatedType.CONTENT,
        options: {
          color,
          intensity: active ? peakIntensity : 0,
          height: active ? 84 : 40,
          bloom: active ? Math.min(0.32, peakIntensity * 0.46) : 0,
        },
      })
      .buildEffect();
  }
}
