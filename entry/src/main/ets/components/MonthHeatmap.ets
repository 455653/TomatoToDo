// ===== components/MonthHeatmap.ets =====
// 月度专注热力图 —— 按周排列的小方块网格
// 颜色深浅代表当日专注分钟数：0=灰，1-30=浅红，31-60=中红，61-120=较深红，120+=深红

import { promptAction } from '@kit.ArkUI';

/** 单元格尺寸 + 间距 */
const CELL_SIZE = 12;
const CELL_GAP = 4;
const CELL_STEP = CELL_SIZE + CELL_GAP;

/** 热力颜色 */
const COLOR_EMPTY = '#F0F0F0';
const COLOR_LIGHT = '#FFCDD2';
const COLOR_MID = '#EF9A9A';
const COLOR_DEEP = '#E57373';
const COLOR_DARK = '#E53935';

/** 星期表头 */
const WEEK_HEADERS: string[] = ['一', '二', '三', '四', '五', '六', '日'];

/** 网格单元格数据 */
interface CellInfo {
  /** 日期（1~31），0 表示空白占位 */
  day: number;
  /** 当日专注分钟数 */
  count: number;
}

/**
 * MonthHeatmap —— 月度热力图组件
 * - 按周排列，周一~周日
 * - 颜色深浅表示专注密度
 * - 点击某天弹 Toast 显示详情
 */
@Component
export struct MonthHeatmap {
  /** 全量热力数据 Map<"YYYY-MM-DD", count> */
  @Prop data: Map<string, number> = new Map();
  /** 年份 */
  @Prop year: number = 2024;
  /** 月份 1~12 */
  @Prop month: number = 1;

  /**
   * 构建日历网格（行 × 7 列）
   */
  private buildGrid(): CellInfo[][] {
    const firstDay = new Date(this.year, this.month - 1, 1);
    // getDay(): 0=Sun → 调整为 0=Mon
    const jsDow = firstDay.getDay();
    const firstDayOffset = jsDow === 0 ? 6 : jsDow - 1;

    const daysInMonth = new Date(this.year, this.month, 0).getDate();
    const totalCells = firstDayOffset + daysInMonth;
    const numRows = Math.ceil(totalCells / 7);

    const rows: CellInfo[][] = [];
    let dayCounter = 1;

    for (let r = 0; r < numRows; r++) {
      const row: CellInfo[] = [];
      for (let c = 0; c < 7; c++) {
        const idx = r * 7 + c;
        if (idx < firstDayOffset || dayCounter > daysInMonth) {
          row.push({ day: 0, count: 0 });
        } else {
          const key = this.makeKey(dayCounter);
          const count = this.data.get(key) ?? 0;
          row.push({ day: dayCounter, count: count });
          dayCounter++;
        }
      }
      rows.push(row);
    }

    return rows;
  }

  /**
   * 获取单元格颜色
   */
  private getColor(count: number): string {
    if (count <= 0) {
      return COLOR_EMPTY;
    }
    if (count <= 30) {
      return COLOR_LIGHT;
    }
    if (count <= 60) {
      return COLOR_MID;
    }
    if (count <= 120) {
      return COLOR_DEEP;
    }
    return COLOR_DARK;
  }

  /**
   * 获取月份中文名
   */
  private getMonthName(): string {
    return `${this.month}月`;
  }

  /**
   * 生成日期 key "YYYY-MM-DD"
   */
  private makeKey(day: number): string {
    const m = this.month.toString().padStart(2, '0');
    const d = day.toString().padStart(2, '0');
    return `${this.year}-${m}-${d}`;
  }

  /**
   * 点击某天
   */
  private onDayClick(day: number, count: number): void {
    if (day <= 0) {
      return;
    }
    const msg = `${this.getMonthName()}${day}日：${count}分钟`;
    promptAction.showToast({ message: msg, duration: 1500 });
  }

  build() {
    Column() {
      // 星期表头
      Row() {
        ForEach(WEEK_HEADERS, (label: string) => {
          Text(label)
            .fontSize(10)
            .fontColor('#999999')
            .width(CELL_STEP)
            .textAlign(TextAlign.Center)
        }, (label: string) => label)
      }
      .margin({ bottom: 4 })

      // 日历网格
      Column() {
        ForEach(this.buildGrid(), (row: CellInfo[], rowIdx: number) => {
          Row() {
            ForEach(row, (cell: CellInfo, colIdx: number) => {
              // 触摸目标放大，内部绘制小方块
              Stack() {
                // 实际色块
                Column() {}
                  .width(CELL_SIZE)
                  .height(CELL_SIZE)
                  .backgroundColor(this.getColor(cell.count))
                  .borderRadius(2)
              }
              .width(CELL_STEP)
              .height(CELL_STEP)
              .alignContent(Alignment.Center)
              .onClick(() => {
                this.onDayClick(cell.day, cell.count);
              })
            }, (cell: CellInfo, colIdx: number) => `${rowIdx}_${colIdx}`)
          }
        }, (row: CellInfo[], rowIdx: number) => rowIdx.toString())
      }
    }
    .alignItems(HorizontalAlign.Center)
  }
}
