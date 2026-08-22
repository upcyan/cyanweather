/**
 * 扁平化矢量图标组件
 * 使用 Canvas 绘制 Material Design 风格图标，替代 Unicode 字符
 */

@Component
export struct AppBarIcon {
  @Prop icon: string = 'settings'; // 'settings' | 'refresh' | 'back' | 'location' | 'search' | 'close'
  @Prop iconSize: number = 28;
  @Prop color: string = '#333333';
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
    const cx: number = s / 2;
    const cy: number = s / 2;

    ctx.clearRect(0, 0, s, s);
    ctx.strokeStyle = this.color;
    ctx.fillStyle = this.color;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';

    switch (this.icon) {
      case 'settings':
        this.drawGear(ctx, cx, cy, s);
        break;
      case 'refresh':
        this.drawRefresh(ctx, cx, cy, s);
        break;
      case 'back':
        this.drawBack(ctx, cx, cy, s);
        break;
      case 'location':
        this.drawLocation(ctx, cx, cy, s);
        break;
      case 'search':
        this.drawSearch(ctx, cx, cy, s);
        break;
      case 'close':
        this.drawClose(ctx, cx, cy, s);
        break;
      default:
        break;
    }
  }

  /** 齿轮图标 (Material Settings) */
  private drawGear(ctx: CanvasRenderingContext2D, cx: number, cy: number, s: number): void {
    const outerR: number = s * 0.42;
    const innerR: number = s * 0.28;
    const holeR: number = s * 0.14;
    const teeth: number = 8;
    const toothW: number = s * 0.07;

    ctx.beginPath();
    for (let i = 0; i < teeth; i++) {
      const ang: number = (i / teeth) * Math.PI * 2;
      const angNext: number = ((i + 0.5) / teeth) * Math.PI * 2;
      // 外齿顶
      const x1: number = cx + Math.cos(ang - toothW / outerR) * outerR;
      const y1: number = cy + Math.sin(ang - toothW / outerR) * outerR;
      const x2: number = cx + Math.cos(ang + toothW / outerR) * outerR;
      const y2: number = cy + Math.sin(ang + toothW / outerR) * outerR;
      // 内齿根
      const x3: number = cx + Math.cos(angNext) * innerR;
      const y3: number = cy + Math.sin(angNext) * innerR;

      if (i === 0) {
        ctx.moveTo(x1, y1);
      } else {
        ctx.lineTo(x1, y1);
      }
      ctx.lineTo(x2, y2);
      ctx.lineTo(x3, y3);
    }
    ctx.closePath();
    ctx.fill();

    // 中心孔
    ctx.globalCompositeOperation = 'destination-out';
    ctx.beginPath();
    ctx.arc(cx, cy, holeR, 0, Math.PI * 2);
    ctx.fill();
    ctx.globalCompositeOperation = 'source-over';
  }

  /** 刷新图标 (Material Refresh) */
  private drawRefresh(ctx: CanvasRenderingContext2D, cx: number, cy: number, s: number): void {
    const r: number = s * 0.34;
    ctx.lineWidth = s * 0.08;

    // 画约 270° 的圆弧（从右上缺口开始，顺时针）
    const startAng: number = -Math.PI * 0.15;
    const endAng: number = Math.PI * 1.35;
    ctx.beginPath();
    ctx.arc(cx, cy, r, startAng, endAng);
    ctx.stroke();

    // 箭头在弧的起点（右上），沿顺时针切线方向
    const ax: number = cx + Math.cos(startAng) * r;
    const ay: number = cy + Math.sin(startAng) * r;
    const arrowSize: number = s * 0.16;

    // 顺时针切线方向（角度增大方向）
    const tangentAng: number = startAng + Math.PI / 2;
    const tx: number = Math.cos(tangentAng);
    const ty: number = Math.sin(tangentAng);
    // 法线方向（垂直切线）
    const nx: number = -ty;
    const ny: number = tx;

    // 箭头尖端：沿切线方向前进
    const tipX: number = ax + tx * arrowSize;
    const tipY: number = ay + ty * arrowSize;
    // 箭头基底中心：沿切线反方向后退
    const baseCX: number = ax - tx * arrowSize * 0.4;
    const baseCY: number = ay - ty * arrowSize * 0.4;
    // 两侧偏移
    const halfW: number = arrowSize * 0.6;
    const b1X: number = baseCX + nx * halfW;
    const b1Y: number = baseCY + ny * halfW;
    const b2X: number = baseCX - nx * halfW;
    const b2Y: number = baseCY - ny * halfW;

    ctx.beginPath();
    ctx.moveTo(b1X, b1Y);
    ctx.lineTo(tipX, tipY);
    ctx.lineTo(b2X, b2Y);
    ctx.closePath();
    ctx.fill();
  }

  /** 返回箭头 (Material ArrowBack) */
  private drawBack(ctx: CanvasRenderingContext2D, cx: number, cy: number, s: number): void {
    ctx.lineWidth = s * 0.08;
    ctx.beginPath();
    ctx.moveTo(cx + s * 0.22, cy - s * 0.22);
    ctx.lineTo(cx - s * 0.22, cy);
    ctx.lineTo(cx + s * 0.22, cy + s * 0.22);
    ctx.stroke();
  }

  /** 定位图标 (Material LocationOn) */
  private drawLocation(ctx: CanvasRenderingContext2D, cx: number, cy: number, s: number): void {
    // 水滴外形
    ctx.beginPath();
    ctx.arc(cx, cy - s * 0.08, s * 0.26, Math.PI * 0.85, Math.PI * 0.15, false);
    ctx.lineTo(cx, cy + s * 0.38);
    ctx.closePath();
    ctx.fill();

    // 中心圆孔
    ctx.globalCompositeOperation = 'destination-out';
    ctx.beginPath();
    ctx.arc(cx, cy - s * 0.08, s * 0.10, 0, Math.PI * 2);
    ctx.fill();
    ctx.globalCompositeOperation = 'source-over';
  }

  /** 搜索图标 (Material Search) */
  private drawSearch(ctx: CanvasRenderingContext2D, cx: number, cy: number, s: number): void {
    const r: number = s * 0.26;
    ctx.lineWidth = s * 0.07;
    ctx.beginPath();
    ctx.arc(cx - s * 0.08, cy - s * 0.08, r, 0, Math.PI * 2);
    ctx.stroke();
    // 手柄
    ctx.beginPath();
    ctx.moveTo(cx + s * 0.10, cy + s * 0.10);
    ctx.lineTo(cx + s * 0.28, cy + s * 0.28);
    ctx.stroke();
  }

  /** 关闭图标 (Material Close) */
  private drawClose(ctx: CanvasRenderingContext2D, cx: number, cy: number, s: number): void {
    ctx.lineWidth = s * 0.08;
    ctx.beginPath();
    ctx.moveTo(cx - s * 0.22, cy - s * 0.22);
    ctx.lineTo(cx + s * 0.22, cy + s * 0.22);
    ctx.moveTo(cx + s * 0.22, cy - s * 0.22);
    ctx.lineTo(cx - s * 0.22, cy + s * 0.22);
    ctx.stroke();
  }
}
