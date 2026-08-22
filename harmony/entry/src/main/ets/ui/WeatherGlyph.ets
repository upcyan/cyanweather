import { SkyKind } from './SkyKind';

/**
 * 自定义天气图标组件
 * 使用 Canvas 绘制扁平化矢量图标，精确移植自 Android WeatherIcon.kt
 */

// 图标颜色（与 Android 保持一致）
const SUN_COLOR: string = '#F6A821';
const CLOUD_COLOR: string = '#7C97AB';
const RAIN_COLOR: string = '#3FA3F0';
const BOLT_COLOR: string = '#F2A93B';
const SNOW_COLOR: string = '#90CAF9';
const FOG_COLOR: string = '#B0BEC5';

// 各类型图标归一化缩放因子（与 Android 一致）
function normOf(kind: SkyKind): number {
  switch (kind) {
    case SkyKind.SUN: return 0.80;
    case SkyKind.PARTLY: return 0.68;
    case SkyKind.MOON: return 1.08;
    case SkyKind.CLOUD: return 0.98;
    case SkyKind.RAIN: return 1.06;
    case SkyKind.SNOW: return 1.06;
    case SkyKind.THUNDER: return 0.94;
    case SkyKind.SLEET: return 1.06;
    case SkyKind.FOG: return 1.22;
    case SkyKind.HAZE: return 1.22;
    case SkyKind.WIND: return 0.98;
    default: return 1.10;
  }
}

@Component
export struct WeatherGlyph {
  @Prop kind: SkyKind = SkyKind.UNKNOWN;
  @Prop iconSize: number = 88;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  build() {
    Canvas(this.context)
      .width(this.iconSize)
      .height(this.iconSize)
      .onReady(() => {
        this.draw(this.context);
      })
  }

  private draw(ctx: CanvasRenderingContext2D): void {
    const s: number = this.iconSize;
    const norm: number = normOf(this.kind);
    const size: number = Math.min(s, s) * norm;
    const cx: number = s / 2;
    const cy: number = s / 2;

    ctx.clearRect(0, 0, s, s);

    switch (this.kind) {
      case SkyKind.SUN:
        this.drawSun(ctx, cx, cy, size);
        break;
      case SkyKind.MOON:
        this.drawMoon(ctx, cx, cy, size);
        break;
      case SkyKind.CLOUD:
        this.drawCloudBody(ctx, cx, cy + size * 0.08, size * 0.72);
        break;
      case SkyKind.PARTLY:
        this.drawSun(ctx, cx - size * 0.30, cy - size * 0.30, size * 0.42);
        this.drawCloudBody(ctx, cx + size * 0.16, cy + size * 0.22, size * 0.58);
        break;
      case SkyKind.RAIN:
        this.drawCloudBody(ctx, cx, cy - size * 0.16, size * 0.66);
        this.drawRaindrops(ctx, cx, cy, size);
        break;
      case SkyKind.SNOW:
        this.drawCloudBody(ctx, cx, cy - size * 0.16, size * 0.66);
        this.drawSnowflakes(ctx, cx, cy, size);
        break;
      case SkyKind.THUNDER:
        this.drawCloudBody(ctx, cx, cy - size * 0.22, size * 0.64);
        this.drawBolt(ctx, cx, cy, size);
        break;
      case SkyKind.SLEET:
        this.drawCloudBody(ctx, cx, cy - size * 0.16, size * 0.66);
        this.drawSleet(ctx, cx, cy, size);
        break;
      case SkyKind.FOG:
        this.drawCloudBody(ctx, cx, cy - size * 0.20, size * 0.52);
        this.drawFogLines(ctx, cx, cy, size);
        break;
      case SkyKind.HAZE:
        this.drawCloudBody(ctx, cx, cy - size * 0.20, size * 0.52);
        this.drawFogLines(ctx, cx, cy, size);
        break;
      case SkyKind.WIND:
        this.drawWind(ctx, cx, cy, size);
        break;
      default:
        this.drawCloudBody(ctx, cx, cy + size * 0.06, size * 0.60);
        break;
    }
  }

  // ========= 基本图形元素 =========

  /** 绘制云体：三个圆 + 圆角矩形底部 */
  private drawCloudBody(ctx: CanvasRenderingContext2D, cx: number, cy: number, s: number): void {
    ctx.fillStyle = CLOUD_COLOR;
    // 左圆
    ctx.beginPath();
    ctx.arc(cx - s * 0.30, cy - s * 0.15, s * 0.27, 0, Math.PI * 2);
    ctx.fill();
    // 中圆
    ctx.beginPath();
    ctx.arc(cx, cy - s * 0.30, s * 0.34, 0, Math.PI * 2);
    ctx.fill();
    // 右圆
    ctx.beginPath();
    ctx.arc(cx + s * 0.32, cy - s * 0.13, s * 0.27, 0, Math.PI * 2);
    ctx.fill();
    // 圆角矩形底部
    const rx: number = cx - s * 0.50;
    const ry: number = cy - s * 0.08;
    const rw: number = s * 1.0;
    const rh: number = s * 0.40;
    const cr: number = s * 0.20;
    this.drawRoundRect(ctx, rx, ry, rw, rh, cr);
    ctx.fill();
  }

  /** 绘制圆角矩形路径（辅助） */
  private drawRoundRect(ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, r: number): void {
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.lineTo(x + w - r, y);
    ctx.arcTo(x + w, y, x + w, y + r, r);
    ctx.lineTo(x + w, y + h - r);
    ctx.arcTo(x + w, y + h, x + w - r, y + h, r);
    ctx.lineTo(x + r, y + h);
    ctx.arcTo(x, y + h, x, y + h - r, r);
    ctx.lineTo(x, y + r);
    ctx.arcTo(x, y, x + r, y, r);
    ctx.closePath();
  }

  /** 绘制太阳：圆 + 8条光线 */
  private drawSun(ctx: CanvasRenderingContext2D, cx: number, cy: number, s: number): void {
    // 中心圆
    ctx.fillStyle = SUN_COLOR;
    ctx.beginPath();
    ctx.arc(cx, cy, s * 0.30, 0, Math.PI * 2);
    ctx.fill();

    // 8条光线
    const r1: number = s * 0.42;
    const r2: number = s * 0.60;
    ctx.strokeStyle = SUN_COLOR;
    ctx.lineWidth = s * 0.09;
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

  /** 绘制月亮：两个圆重叠产生月牙 */
  private drawMoon(ctx: CanvasRenderingContext2D, cx: number, cy: number, s: number): void {
    ctx.fillStyle = SUN_COLOR;
    ctx.beginPath();
    ctx.arc(cx - s * 0.08, cy, s * 0.36, 0, Math.PI * 2);
    ctx.fill();

    // 使用 globalCompositeOperation 替代 BlendMode.Clear
    ctx.globalCompositeOperation = 'destination-out';
    ctx.fillStyle = 'rgba(0,0,0,1)';
    ctx.beginPath();
    ctx.arc(cx + s * 0.12, cy - s * 0.12, s * 0.30, 0, Math.PI * 2);
    ctx.fill();
    ctx.globalCompositeOperation = 'source-over';
  }

  /** 绘制雨滴：3条斜线段 */
  private drawRaindrops(ctx: CanvasRenderingContext2D, cx: number, cy: number, s: number): void {
    ctx.strokeStyle = RAIN_COLOR;
    ctx.lineWidth = s * 0.10;
    ctx.lineCap = 'round';
    const xs: number[] = [-s * 0.22, 0, s * 0.22];
    for (const x of xs) {
      ctx.beginPath();
      ctx.moveTo(cx + x - s * 0.03, cy + s * 0.18);
      ctx.lineTo(cx + x + s * 0.03, cy + s * 0.40);
      ctx.stroke();
    }
  }

  /** 绘制雪花：3个星形雪花 */
  private drawSnowflakes(ctx: CanvasRenderingContext2D, cx: number, cy: number, s: number): void {
    const xs: number[] = [-s * 0.24, 0, s * 0.24];
    for (const x of xs) {
      this.drawSnowflake(ctx, cx + x, cy + s * 0.28, s * 0.10, s * 0.03);
    }
  }

  /** 绘制单个雪花（六角星形） */
  private drawSnowflake(ctx: CanvasRenderingContext2D, cx: number, cy: number, r: number, strokeW: number): void {
    ctx.strokeStyle = SNOW_COLOR;
    ctx.lineWidth = strokeW;
    ctx.lineCap = 'round';
    for (let i = 0; i < 3; i++) {
      const ang: number = i * Math.PI / 3;
      const dx: number = Math.cos(ang);
      const dy: number = Math.sin(ang);
      ctx.beginPath();
      ctx.moveTo(cx + dx * r, cy + dy * r);
      ctx.lineTo(cx - dx * r, cy - dy * r);
      ctx.stroke();
    }
    // 中心点
    ctx.fillStyle = SNOW_COLOR;
    ctx.beginPath();
    ctx.arc(cx, cy, r * 0.22, 0, Math.PI * 2);
    ctx.fill();
  }

  /** 绘制闪电（折线路径） */
  private drawBolt(ctx: CanvasRenderingContext2D, cx: number, cy: number, s: number): void {
    ctx.fillStyle = BOLT_COLOR;
    ctx.beginPath();
    ctx.moveTo(cx - s * 0.06, cy + s * 0.08);
    ctx.lineTo(cx + s * 0.12, cy + s * 0.08);
    ctx.lineTo(cx - s * 0.02, cy + s * 0.28);
    ctx.lineTo(cx + s * 0.12, cy + s * 0.28);
    ctx.lineTo(cx - s * 0.14, cy + s * 0.50);
    ctx.lineTo(cx - s * 0.04, cy + s * 0.30);
    ctx.lineTo(cx - s * 0.12, cy + s * 0.30);
    ctx.closePath();
    ctx.fill();
  }

  /** 绘制雨夹雪 */
  private drawSleet(ctx: CanvasRenderingContext2D, cx: number, cy: number, s: number): void {
    // 雨滴
    ctx.strokeStyle = RAIN_COLOR;
    ctx.lineWidth = s * 0.09;
    ctx.lineCap = 'round';
    ctx.beginPath();
    ctx.moveTo(cx - s * 0.18, cy + s * 0.18);
    ctx.lineTo(cx - s * 0.12, cy + s * 0.36);
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(cx + s * 0.18, cy + s * 0.18);
    ctx.lineTo(cx + s * 0.24, cy + s * 0.36);
    ctx.stroke();
    // 雪花
    this.drawSnowflake(ctx, cx, cy + s * 0.34, s * 0.09, s * 0.025);
  }

  /** 绘制雾线：3条横线 */
  private drawFogLines(ctx: CanvasRenderingContext2D, cx: number, cy: number, s: number): void {
    ctx.strokeStyle = FOG_COLOR;
    ctx.lineWidth = s * 0.10;
    ctx.lineCap = 'round';
    for (let i = 0; i < 3; i++) {
      const y: number = cy + s * (0.05 + i * 0.16);
      const half: number = s * (0.34 - i * 0.05);
      ctx.beginPath();
      ctx.moveTo(cx - half, y);
      ctx.lineTo(cx + half, y);
      ctx.stroke();
    }
  }

  /** 绘制风：线 + 弧线 */
  private drawWind(ctx: CanvasRenderingContext2D, cx: number, cy: number, s: number): void {
    ctx.strokeStyle = CLOUD_COLOR;
    ctx.lineWidth = s * 0.10;
    ctx.lineCap = 'round';

    // 上横线
    ctx.beginPath();
    ctx.moveTo(cx - s * 0.38, cy - s * 0.18);
    ctx.lineTo(cx + s * 0.38, cy - s * 0.18);
    ctx.stroke();

    // 中弧线
    ctx.beginPath();
    ctx.arc(cx - s * 0.08, cy - s * 0.02, s * 0.30, Math.PI * 1.0, Math.PI * 1.5);
    ctx.stroke();

    // 下弧线
    ctx.beginPath();
    ctx.arc(cx + s * 0.12, cy + s * 0.32, s * 0.30, Math.PI * 0.22, Math.PI * 0.78);
    ctx.stroke();
  }
}
