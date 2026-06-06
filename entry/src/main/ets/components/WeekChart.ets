// ===== components/WeekChart.ets =====
// 本周折线图 —— Canvas 绘制
// X 轴：周一~周日（中文缩写），Y 轴：分钟数自动适配

import { DayData } from '../viewmodel/StatViewModel';

/** 图表常量 */
const CHART_HEIGHT = 160;
const LEFT_PAD = 32;
const RIGHT_PAD = 12;
const TOP_PAD = 22;
const BOTTOM_PAD = 28;

const LINE_COLOR = '#FF6347';
const DOT_FILL_COLOR = '#FF6347';
const DOT_STROKE_COLOR = '#FF6347';
const GRID_COLOR = '#EEEEEE';
const TEXT_COLOR = '#999999';
const LABEL_COLOR = '#333333';

/** 一周内每天的中文缩写 */
const DAY_LABELS: string[] = ['一', '二', '三', '四', '五', '六', '日'];

/** 画布坐标点 */
interface Point2D {
  x: number;
  y: number;
  val: number;
}

/**
 * WeekChart —— 本周专注分钟数折线图
 */
@Component
export struct WeekChart {
  /** 7 天数据（周一 ~ 周日） */
  @Prop data: DayData[] = [];

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height(CHART_HEIGHT)
      .onReady(() => {
        this.drawChart();
      })
  }

  /**
   * 主绘制入口
   */
  private drawChart(): void {
    const w = this.ctx.width;
    const h = CHART_HEIGHT;
    if (w <= 0) {
      return;
    }

    this.ctx.clearRect(0, 0, w, h);

    const chartW = w - LEFT_PAD - RIGHT_PAD;
    const chartH = h - TOP_PAD - BOTTOM_PAD;
    if (chartW <= 0 || chartH <= 0) {
      return;
    }

    // 确定数据点个数
    const count = this.data.length;
    if (count === 0) {
      return;
    }

    // 计算 Y 轴最大值（自动适配）
    const maxVal = this.getYMax();

    // 绘制网格 + Y 轴标签
    this.drawGrid(w, h, chartW, chartH, maxVal);

    // 绘制折线 + 数据点
    this.drawLine(w, h, chartW, chartH, maxVal, count);

    // 绘制 X 轴标签
    this.drawXLabels(w, h, chartW, chartH, count);
  }

  /**
   * 自动适配 Y 轴最大值
   */
  private getYMax(): number {
    let max = 0;
    for (const d of this.data) {
      if (d.minutes > max) {
        max = d.minutes;
      }
    }
    if (max === 0) {
      return 4; // 无数据时显示 0~4 的空白图
    }
    // 向上取整到美化值
    if (max <= 2) {
      return max + 1;
    }
    if (max <= 5) {
      return max + 1;
    }
    // 向上取整到偶数或 5 的倍数
    const remainder = max % 5;
    if (remainder === 0) {
      return max;
    }
    return max + (5 - remainder);
  }

  /**
   * 绘制水平网格线 + Y 轴标签
   */
  private drawGrid(
    w: number, h: number,
    chartW: number, chartH: number,
    maxVal: number
  ): void {
    const gridLines = 4;
    const startX = LEFT_PAD;
    const endX = LEFT_PAD + chartW;

    this.ctx.strokeStyle = GRID_COLOR;
    this.ctx.lineWidth = 0.5;
    this.ctx.fillStyle = TEXT_COLOR;
    this.ctx.font = '11px sans-serif';
    this.ctx.textAlign = 'right';
    this.ctx.textBaseline = 'middle';

    for (let i = 0; i <= gridLines; i++) {
      const y = TOP_PAD + (chartH * i) / gridLines;
      const val = Math.round(maxVal - (maxVal * i) / gridLines);

      // 网格线
      this.ctx.beginPath();
      this.ctx.moveTo(startX, y);
      this.ctx.lineTo(endX, y);
      this.ctx.stroke();

      // Y 标签
      this.ctx.fillText(val.toString(), LEFT_PAD - 6, y);
    }
  }

  /**
   * 绘制折线 + 数据点
   */
  private drawLine(
    w: number, h: number,
    chartW: number, chartH: number,
    maxVal: number, count: number
  ): void {
    const startX = LEFT_PAD;
    const stepX = chartW / (count - 1);

    // 计算各点坐标
    const points: Point2D[] = [];
    for (let i = 0; i < count; i++) {
      const val = this.data[i].minutes;
      const x = startX + i * stepX;
      const y = TOP_PAD + chartH - (maxVal > 0 ? (val / maxVal) * chartH : 0);
      points.push({ x: x, y: y, val: val });
    }

    // 折线
    if (maxVal > 0) {
      this.ctx.beginPath();
      this.ctx.strokeStyle = LINE_COLOR;
      this.ctx.lineWidth = 2;
      this.ctx.lineCap = 'round';
      this.ctx.lineJoin = 'round';
      this.ctx.moveTo(points[0].x, points[0].y);
      for (let i = 1; i < count; i++) {
        this.ctx.lineTo(points[i].x, points[i].y);
      }
      this.ctx.stroke();
    }

    // 数据点 + 数值标注
    this.ctx.font = '11px sans-serif';
    this.ctx.textAlign = 'center';
    this.ctx.textBaseline = 'bottom';

    for (let i = 0; i < count; i++) {
      const p = points[i];

      if (p.val > 0) {
        // 实心红点
        this.ctx.beginPath();
        this.ctx.arc(p.x, p.y, 5, 0, Math.PI * 2);
        this.ctx.fillStyle = DOT_FILL_COLOR;
        this.ctx.fill();

        // 上方数值
        this.ctx.fillStyle = LABEL_COLOR;
        this.ctx.fillText(p.val.toString(), p.x, p.y - 8);
      } else {
        // 空心圆
        this.ctx.beginPath();
        this.ctx.arc(p.x, p.y, 5, 0, Math.PI * 2);
        this.ctx.strokeStyle = DOT_STROKE_COLOR;
        this.ctx.lineWidth = 1.5;
        this.ctx.stroke();
      }
    }
  }

  /**
   * 绘制 X 轴标签
   */
  private drawXLabels(
    w: number, h: number,
    chartW: number, chartH: number,
    count: number
  ): void {
    const startX = LEFT_PAD;
    const stepX = chartW / (count - 1);
    const labelY = h - 4;

    this.ctx.fillStyle = TEXT_COLOR;
    this.ctx.font = '11px sans-serif';
    this.ctx.textAlign = 'center';
    this.ctx.textBaseline = 'bottom';

    for (let i = 0; i < count; i++) {
      const x = startX + i * stepX;
      const label = DAY_LABELS[i];
      this.ctx.fillText(label, x, labelY);
    }
  }
}
