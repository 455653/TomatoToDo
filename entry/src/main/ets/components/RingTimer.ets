// ===== components/RingTimer.ets =====
// Canvas 圆环计时器组件

import { TimerState } from '../viewmodel/TimerViewModel';

/** 圆弧宽度 */
const ARC_WIDTH = 12;

/** 颜色常量 */
const COLOR_BG = '#E8E8E8';
const COLOR_FOCUS = '#FF6347';
const COLOR_BREAK = '#4CAF50';
const COLOR_PAUSE = '#FF9800';
const COLOR_IDLE = '#E8E8E8';

/**
 * RingTimer —— Canvas 绘制的倒计时圆环
 * - 背景灰圆弧 + 前景色进度圆弧（顺时针从顶部）
 * - 中心显示 MM:SS + 状态文字
 * - 圆环上方显示 "第 N 个番茄"
 */
@Component
export struct RingTimer {
  /** 进度 0~1 */
  @Prop progress: number = 0;
  /** 剩余秒数（当此值变化时自动重绘圆环） */
  @Prop @Watch('onPropChange') remainSeconds: number = 0;
  /** 当前状态 */
  @Prop state: TimerState = TimerState.IDLE;
  /** 今日已累计专注分钟数 */
  @Prop todayFocusMinutes: number = 0;

  /** Canvas 渲染上下文 */
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  /** Canvas 是否已就绪（onReady 已触发） */
  private canvasReady: boolean = false;

  build() {
    Column() {
      // 圆环上方状态文字
      if (this.state === TimerState.FOCUSING) {
        Text('专注中')
          .fontSize(14)
          .fontColor('#FF6347')
          .margin({ bottom: 8 })
      } else if (this.state === TimerState.PAUSED) {
        Text('已暂停')
          .fontSize(14)
          .fontColor('#FF9800')
          .margin({ bottom: 8 })
      } else if (this.state === TimerState.RESTING) {
        Text('休息中')
          .fontSize(14)
          .fontColor('#4CAF50')
          .margin({ bottom: 8 })
      } else {
        Text('准备开始')
          .fontSize(14)
          .fontColor('#999999')
          .margin({ bottom: 8 })
      }

      // Canvas 圆环
      Canvas(this.ctx)
        .width('100%')
        .height('100%')
        .layoutWeight(1)
        .onReady(() => {
          this.canvasReady = true;
          this.drawRing();
        })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
  }

  /**
   * @Prop 值变化时触发重绘（由 @Watch 驱动）
   */
  private onPropChange(): void {
    if (this.canvasReady) {
      this.drawRing();
    }
  }

  /**
   * 绘制整个圆环 + 文字
   */
  private drawRing(): void {
    const w = this.ctx.width;
    const h = this.ctx.height;
    const size = Math.min(w, h);
    // 圆环直径占可用空间 80%
    const diameter = size * 0.8;
    const radius = diameter / 2;
    const centerX = w / 2;
    const centerY = h / 2;
    const arcRadius = (diameter - ARC_WIDTH) / 2;

    // 清空画布
    this.ctx.clearRect(0, 0, w, h);

    // 1. 绘制背景圆弧（完整灰色圆环）
    this.drawArc(centerX, centerY, arcRadius, 0, Math.PI * 2, COLOR_BG);

    // 2. 绘制进度圆弧（从顶部顺时针）
    const progressColor = this.getArcColor();
    const clampedProgress = Math.max(0, Math.min(1, this.progress));
    // 从 -90° (12 点钟) 起始，顺时针
    const startAngle = -Math.PI / 2;
    const sweepAngle = clampedProgress * Math.PI * 2;
    const endAngle = startAngle + sweepAngle;
    this.drawArc(centerX, centerY, arcRadius, startAngle, endAngle, progressColor);

    // 3. 中心文字：MM:SS（正向走时）
    const timeStr = this.formatTime(this.remainSeconds);
    this.ctx.font = 'bold 48px sans-serif';
    this.ctx.fillStyle = '#333333';
    this.ctx.textAlign = 'center';
    this.ctx.textBaseline = 'middle';
    this.ctx.fillText(timeStr, centerX, centerY - 16);

    // 4. 中心下方：今日已累计专注
    this.ctx.font = '13px sans-serif';
    this.ctx.fillStyle = '#999999';
    const todayText = `今日已专注 ${this.todayFocusMinutes} 分钟`;
    this.ctx.fillText(todayText, centerX, centerY + 30);
  }

  /**
   * 绘制一段圆弧
   */
  private drawArc(
    cx: number, cy: number, r: number,
    startAngle: number, endAngle: number,
    color: string
  ): void {
    this.ctx.beginPath();
    this.ctx.arc(cx, cy, r, startAngle, endAngle, false);
    this.ctx.strokeStyle = color;
    this.ctx.lineWidth = ARC_WIDTH;
    this.ctx.lineCap = 'round';
    this.ctx.stroke();
  }

  /**
   * 获取当前状态对应的圆弧颜色
   */
  private getArcColor(): string {
    if (this.state === TimerState.FOCUSING) {
      return '#FF6347';
    }
    if (this.state === TimerState.RESTING) {
      return '#4CAF50';
    }
    if (this.state === TimerState.PAUSED) {
      return '#FF9800';
    }
    return '#E8E8E8';
  }

  /**
   * 秒数 → MM:SS 格式化
   */
  private formatTime(totalSeconds: number): string {
    const secs = Math.max(0, Math.floor(totalSeconds));
    const m = Math.floor(secs / 60);
    const s = secs % 60;
    return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
  }
}
