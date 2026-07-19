import { hdsEffect } from '@kit.UIDesignKit';
import { RustDeskGlassEffect } from '../RustDeskGlassEffect';

@ComponentV2
struct AmbientOrbitLight {
  @Param viewportWidth: number = 390;
  @Param viewportHeight: number = 844;

  @Local lightX: number = -40;
  @Local lightY: number = -40;
  @Local lightIntensity: number = 0;

  private centerX: number = 195;
  private centerY: number = 422;
  private radiusX: number = 120;
  private radiusY: number = 180;
  private phase: number = 0;
  private step: number = 0;
  private stepCount: number = 16;
  private segmentDuration: number = 1400;
  private baseIntensity: number = 0.16;
  private startTimer: number = -1;
  private disposed: boolean = false;

  aboutToAppear(): void {
    this.disposed = false;
    this.configureOrbit();
    this.placeAtStep(0);
    this.startTimer = setTimeout(() => {
      this.startTimer = -1;
      if (!this.disposed) {
        this.animateNextStep();
      }
    }, 120);
  }

  aboutToDisappear(): void {
    this.disposed = true;
    if (this.startTimer >= 0) {
      clearTimeout(this.startTimer);
      this.startTimer = -1;
    }
    this.lightIntensity = 0;
  }

  private configureOrbit(): void {
    const width = Math.max(320, this.viewportWidth);
    const height = Math.max(640, this.viewportHeight);
    this.phase = Math.random() * Math.PI * 2;
    this.centerX = width * 0.50;
    this.centerY = height * 0.50;
    this.radiusX = width * 0.43;
    this.radiusY = height * 0.38;
  }

  private angleForStep(step: number): number {
    return this.phase + step / this.stepCount * Math.PI * 2;
  }

  private xForStep(step: number): number {
    const angle = this.angleForStep(step);
    const wobble = Math.sin(angle * 3) * this.radiusX * 0.06;
    return this.centerX + Math.cos(angle) * this.radiusX + wobble;
  }

  private yForStep(step: number): number {
    const angle = this.angleForStep(step);
    const wobble = Math.cos(angle * 2) * this.radiusY * 0.08;
    return this.centerY + Math.sin(angle) * this.radiusY + wobble;
  }

  private intensityForStep(step: number): number {
    const angle = this.angleForStep(step);
    return this.baseIntensity + (Math.sin(angle * 2) + 1) * 0.018;
  }

  private placeAtStep(step: number): void {
    this.step = step;
    this.lightX = this.xForStep(step);
    this.lightY = this.yForStep(step);
    this.lightIntensity = this.intensityForStep(step);
  }

  private animateNextStep(): void {
    if (this.disposed) {
      return;
    }
    const nextStep = (this.step + 1) % this.stepCount;
    const nextX = this.xForStep(nextStep);
    const nextY = this.yForStep(nextStep);
    const nextIntensity = this.intensityForStep(nextStep);
    this.getUIContext().animateTo({
      duration: this.segmentDuration,
      curve: Curve.Linear,
      onFinish: () => {
        this.step = nextStep;
        this.animateNextStep();
      },
    }, () => {
      this.lightX = nextX;
      this.lightY = nextY;
      this.lightIntensity = nextIntensity;
    });
  }

  // FrankHanUI point-light-source: background-decoration
  private orbitSource(): VisualEffect {
    return new hdsEffect.HdsEffectBuilder()
      .pointLight({
        illuminatedType: hdsEffect.PointLightIlluminatedType.CONTENT,
        options: {
          color: $r('app.color.point_light'),
          intensity: this.lightIntensity,
          height: 110,
          bloom: Math.min(0.10, this.lightIntensity * 0.50),
        },
      })
      .buildEffect();
  }

  build() {
    Stack()
      .width(10)
      .height(10)
      .position({ x: this.lightX - 5, y: this.lightY - 5 })
      .backgroundColor($r('app.color.point_light'))
      .borderRadius($r('app.float.radius_pill'))
      .opacity(0.07)
      .shadow({
        radius: 20,
        color: $r('app.color.point_light'),
        offsetX: 0,
        offsetY: 0,
      })
      .visualEffect(this.orbitSource())
      .hitTestBehavior(HitTestMode.None);
  }
}

@ComponentV2
export struct AmbientOrbitBackdrop {
  @Param viewportWidth: number = 390;
  @Param viewportHeight: number = 844;

  build() {
    Stack() {
      AmbientOrbitLight({
        viewportWidth: this.viewportWidth,
        viewportHeight: this.viewportHeight,
      });
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
    .clip(true)
    .visualEffect(RustDeskGlassEffect.contentReceiver())
    .hitTestBehavior(HitTestMode.None)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM]);
  }
}
