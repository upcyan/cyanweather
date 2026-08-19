import { SkyKind } from './SkyKind';

/**
 * 自定义天气图标组件
 * 使用 Canvas 绘制，移植自 Android WeatherIcon.kt
 */

// 图标颜色（与 Android 保持一致）
const SUN_COLOR: string = '#F6A821';
const CLOUD_COLOR: string = '#7C97AB';
const RAIN_COLOR: string = '#3FA3F0';
const BOLT_COLOR: string = '#F2A93B';
const SNOW_COLOR: string = '#90CAF9';
const FOG_COLOR: string = '#B0BEC5';

@Component
export struct WeatherGlyph {
  @Prop kind: SkyKind = SkyKind.UNKNOWN;
  @Prop size: number = 88;

  build() {
    Canvas(this.getSetting())
      .width(this.size)
      .height(this.size)
      .onReady((ctx: CanvasRenderingContext2D) => {
        this.draw(ctx);
      })
  }

  private getSetting(): RenderingContextSettings {
    const settings: RenderingContextSettings = new RenderingContextSettings(true);
    return settings;
  }

  private draw(ctx: CanvasRenderingContext2D): void {
    const s: number = this.size;
    const cx: number = s / 2;
    const cy: number = s / 2;

    ctx.clearRect(0, 0, s, s);

    // 先画云底（部分类型需要）
    if (this.kind === SkyKind.CLOUD || this.kind === SkyKind.RAIN ||
        this.kind === SkyKind.SNOW || this.kind === SkyKind.THUNDER ||
        this.kind === SkyKind.SLEET || this.kind === SkyKind.PARTLY) {
      this.drawCloud(ctx, cx, cy, s);
    }

    switch (this.kind) {
      case SkyKind.SUN:
        this.drawSun(ctx, cx, cy, s);
        break;
      case SkyKind.MOON:
        this.drawMoon(ctx, cx, cy, s);
        break;
      case SkyKind.PARTLY:
        this.drawSun(ctx, cx - s * 0.15, cy - s * 0.15, s * 0.7);
        break;
      case SkyKind.CLOUD:
        // 云已画
        break;
      case SkyKind.RAIN:
        this.drawRain(ctx, cx, cy, s);
        break;
      case SkyKind.SNOW:
        this.drawSnow(ctx, cx, cy, s);
        break;
      case SkyKind.THUNDER:
        this.drawBolt(ctx, cx, cy, s);
        break;
      case SkyKind.SLEET:
        this.drawSleet(ctx, cx, cy, s);
        break;
      case SkyKind.FOG:
        this.drawFog(ctx, cx, cy, s);
        break;
      case SkyKind.HAZE:
        this.drawHaze(ctx, cx, cy, s);
        break;
      case SkyKind.WIND:
        this.drawWind(ctx, cx, cy, s);
        break;
      default:
        this.drawSun(ctx, cx, cy, s);
        break;
    }
  }

  // 绘制太阳
  private drawSun(ctx: CanvasRenderingContext2D, cx: number, cy: number, s: number): void {
    const r: number = s * 0.18;
    // 画圆
    ctx.fillStyle = SUN_COLOR;
    ctx.beginPath();
    ctx.arc(cx, cy, r, 0, Math.PI * 2);
    ctx.fill();

    // 画光线
    const r1: number = s * 0.25;
    const r2: number = s * 0.36;
    ctx.strokeStyle = SUN_COLOR;
    ctx.lineWidth = s * 0.04;
    ctx.lineCap = 'round';
    for (let i = 0; i < 8; i++) {
      const ang: number = (i * 45) * Math.PI / 180;
      const dx: number = Math.cos(ang);
      const dy: number = Math.sin(ang);
      ctx.beginPath();
      ctx.moveTo(cx + dx * r1, cy + dy * r1);
      ctx.lineTo(cx + dx * r2, cy + dy * r2);
      ctx.stroke();
    }
  }

  // 绘制月亮
  private drawMoon(ctx: CanvasRenderingContext2D, cx: number, cy: number, s: number): void {
    const r: number = s * 0.22;
    ctx.fillStyle = SUN_COLOR;
    ctx.beginPath();
    ctx.arc(cx, cy, r, 0, Math.PI * 2);
    ctx.fill();

    // 用背景色画偏移圆制造弯月效果
    ctx.fillStyle = '#F5F9FF';
    ctx.beginPath();
    ctx.arc(cx + r * 0.5, cy - r * 0.3, r * 0.9, 0, Math.PI * 2);
    ctx.fill();
  }

  // 绘制云
  private drawCloud(ctx: CanvasRenderingContext2D, cx: number, cy: number, s: number): void {
    ctx.fillStyle = CLOUD_COLOR;
    const cloudR: number = s * 0.15;
    // 三个圆组成云
    ctx.beginPath();
    ctx.arc(cx - s * 0.12, cy + s * 0.02, cloudR * 0.9, 0, Math.PI * 2);
    ctx.fill();
    ctx.beginPath();
    ctx.arc(cx, cy - s * 0.05, cloudR * 1.1, 0, Math.PI * 2);
    ctx.fill();
    ctx.beginPath();
    ctx.arc(cx + s * 0.12, cy + s * 0.02, cloudR * 0.85, 0, Math.PI * 2);
    ctx.fill();
    // 底部矩形
    ctx.fillRect(cx - s * 0.2, cy + s * 0.02, s * 0.4, s * 0.1);
  }

  // 绘制雨滴
  private drawRain(ctx: CanvasRenderingContext2D, cx: number, cy: number, s: number): void {
    ctx.strokeStyle = RAIN_COLOR;
    ctx.lineWidth = s * 0.035;
    ctx.lineCap = 'round';
    const startY: number = cy + s * 0.12;
    const len: number = s * 0.12;
    for (let i = -1; i <= 1; i++) {
      const x: number = cx + i * s * 0.12;
      ctx.beginPath();
      ctx.moveTo(x, startY);
      ctx.lineTo(x, startY + len);
      ctx.stroke();
    }
  }

  // 绘制雪花
  private drawSnow(ctx: CanvasRenderingContext2D, cx: number, cy: number, s: number): void {
    ctx.fillStyle = SNOW_COLOR;
    const r: number = s * 0.04;
    const startY: number = cy + s * 0.15;
    for (let i = -1; i <= 1; i++) {
      const x: number = cx + i * s * 0.12;
      ctx.beginPath();
      ctx.arc(x, startY, r, 0, Math.PI * 2);
      ctx.fill();
      ctx.beginPath();
      ctx.arc(x, startY + s * 0.08, r, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  // 绘制闪电
  private drawBolt(ctx: CanvasRenderingContext2D, cx: number, cy: number, s: number): void {
    ctx.fillStyle = BOLT_COLOR;
    ctx.beginPath();
    ctx.moveTo(cx - s * 0.04, cy + s * 0.1);
    ctx.lineTo(cx + s * 0.06, cy + s * 0.1);
    ctx.lineTo(cx, cy + s * 0.18);
    ctx.lineTo(cx + s * 0.08, cy + s * 0.18);
    ctx.lineTo(cx - s * 0.02, cy + s * 0.32);
    ctx.lineTo(cx - s * 0.04, cy + s * 0.2);
    ctx.lineTo(cx - s * 0.1, cy + s * 0.2);
    ctx.closePath();
    ctx.fill();
  }

  // 绘制雨夹雪
  private drawSleet(ctx: CanvasRenderingContext2D, cx: number, cy: number, s: number): void {
    this.drawRain(ctx, cx - s * 0.06, cy, s);
    ctx.fillStyle = SNOW_COLOR;
    const r: number = s * 0.04;
    ctx.beginPath();
    ctx.arc(cx + s * 0.12, cy + s * 0.18, r, 0, Math.PI * 2);
    ctx.fill();
  }

  // 绘制雾
  private drawFog(ctx: CanvasRenderingContext2D, cx: number, cy: number, s: number): void {
    ctx.strokeStyle = FOG_COLOR;
    ctx.lineWidth = s * 0.05;
    ctx.lineCap = 'round';
    for (let i = -2; i <= 2; i++) {
      const y: number = cy + i * s * 0.1;
      ctx.beginPath();
      ctx.moveTo(cx - s * 0.2, y);
      ctx.lineTo(cx + s * 0.2, y);
      ctx.stroke();
    }
  }

  // 绘制霾
  private drawHaze(ctx: CanvasRenderingContext2D, cx: number, cy: number, s: number): void {
    this.drawSun(ctx, cx, cy - s * 0.1, s * 0.6);
    this.drawFog(ctx, cx, cy + s * 0.15, s * 0.8);
  }

  // 绘制风
  private drawWind(ctx: CanvasRenderingContext2D, cx: number, cy: number, s: number): void {
    ctx.strokeStyle = CLOUD_COLOR;
    ctx.lineWidth = s * 0.04;
    ctx.lineCap = 'round';
    // 三条风线
    for (let i = 0; i < 3; i++) {
      const y: number = cy + (i - 1) * s * 0.12;
      ctx.beginPath();
      ctx.moveTo(cx - s * 0.2, y);
      ctx.bezierCurveTo(cx - s * 0.05, y - s * 0.05, cx + s * 0.05, y + s * 0.05, cx + s * 0.15, y);
      ctx.stroke();
    }
  }
}
