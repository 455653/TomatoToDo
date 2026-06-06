// ===== pages/StatPage.ets =====
// 专注统计页面 —— 今日概览 / 本周趋势 / 月度热力图 / 累计成就

import { StatViewModel } from '../viewmodel/StatViewModel';
import { WeekChart } from '../components/WeekChart';
import { MonthHeatmap } from '../components/MonthHeatmap';

@Entry
@Component
export struct StatPage {
  /** 统计数据 ViewModel */
  private viewModel: StatViewModel = new StatViewModel();

  /** 热力图展示的年份 */
  @State currentYear: number = new Date().getFullYear();
  /** 热力图展示的月份 1~12 */
  @State currentMonth: number = new Date().getMonth() + 1;
  /** 本次加载过数据 */
  private loaded: boolean = false;

  /**
   * 页面每次出现时刷新数据
   */
  async aboutToAppear(): Promise<void> {
    await this.viewModel.loadAll();
    this.loaded = true;
  }

  build() {
    Scroll() {
      Column() {
        // ═══════════════════════════════════════
        // 顶部标题 + 月份切换
        // ═══════════════════════════════════════
        this.BuildTitleBar()

        Divider().margin({ top: 12, bottom: 4 })

        // ═══════════════════════════════════════
        // 今日概览
        // ═══════════════════════════════════════
        this.BuildSectionTitle('今日概览')
        this.BuildTodayMetrics()

        Divider().margin({ top: 16, bottom: 12 })

        // ═══════════════════════════════════════
        // 本周趋势
        // ═══════════════════════════════════════
        this.BuildSectionTitle('本周趋势')
        WeekChart({ data: this.viewModel.weekData })

        Divider().margin({ top: 16, bottom: 12 })

        // ═══════════════════════════════════════
        // 本月热力图
        // ═══════════════════════════════════════
        this.BuildSectionTitle('本月热力图')
        MonthHeatmap({
          data: this.viewModel.monthHeatmap,
          year: this.currentYear,
          month: this.currentMonth,
        })

        Divider().margin({ top: 16, bottom: 12 })

        // ═══════════════════════════════════════
        // 累计成就
        // ═══════════════════════════════════════
        this.BuildSectionTitle('累计成就')
        this.BuildCumulative()

        // 底部安全距离
        Column().height(24)
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
    .scrollBar(BarState.Off)
  }

  // ═══════════════════════════════════════════
  // 标题栏
  // ═══════════════════════════════════════════

  @Builder
  BuildTitleBar() {
    Row() {
      Text('专注统计')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')

      Blank()

      // 月份切换器
      Row({ space: 8 }) {
        Text('◀')
          .fontSize(14)
          .fontColor('#999999')
          .padding({ left: 4, right: 4 })
          .onClick(() => {
            this.prevMonth();
          })

        Text(`${this.currentYear}年${this.currentMonth}月`)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')
          .width(100)
          .textAlign(TextAlign.Center)

        Text('▶')
          .fontSize(14)
          .fontColor('#999999')
          .padding({ left: 4, right: 4 })
          .onClick(() => {
            this.nextMonth();
          })
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .margin({ top: 12 })
  }

  // ═══════════════════════════════════════════
  // 今日四项指标
  // ═══════════════════════════════════════════

  @Builder
  BuildTodayMetrics() {
    Row({ space: 8 }) {
      this.BuildMetricCard('专注次数', this.viewModel.todayFocusCount.toString(), '#FF6347')
      this.BuildMetricCard('专注分钟', this.viewModel.todayMinutes.toString(), '#4CAF50')
      this.BuildMetricCard('涉及任务', this.viewModel.todayDoneTasks.toString(), '#2196F3')
      this.BuildMetricCard('质量分', '--', '#FF9800')
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
  }

  @Builder
  BuildMetricCard(label: string, value: string, accentColor: string) {
    Column() {
      Text(value)
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor(accentColor)

      Text(label)
        .fontSize(11)
        .fontColor('#999999')
        .margin({ top: 4 })
    }
    .width('22%')
    .padding({ top: 12, bottom: 12 })
    .backgroundColor('#FAFAFA')
    .borderRadius(10)
    .alignItems(HorizontalAlign.Center)
  }

  // ═══════════════════════════════════════════
  // 累计成就（三列）
  // ═══════════════════════════════════════════

  @Builder
  BuildCumulative() {
    Row({ space: 8 }) {
      this.BuildStatCol('🥇 总次数', `${this.viewModel.totalFocusCount} 次`)
      this.BuildStatCol('⏱️ 总时长', `${this.viewModel.totalHours} 小时`)
      this.BuildStatCol('🔥 连续天数', `${this.viewModel.streakDays} 天`)
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
  }

  @Builder
  BuildStatCol(emojiLabel: string, value: string) {
    Column() {
      Text(emojiLabel)
        .fontSize(12)
        .fontColor('#666666')

      Text(value)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')
        .margin({ top: 6 })
    }
    .width('31%')
    .padding({ top: 14, bottom: 14 })
    .backgroundColor('#FAFAFA')
    .borderRadius(10)
    .alignItems(HorizontalAlign.Center)
  }

  // ═══════════════════════════════════════════
  // 通用小节标题
  // ═══════════════════════════════════════════

  @Builder
  BuildSectionTitle(title: string) {
    Text(title)
      .fontSize(16)
      .fontWeight(FontWeight.Bold)
      .fontColor('#333333')
      .width('100%')
      .margin({ bottom: 10 })
  }

  // ═══════════════════════════════════════════
  // 月份切换逻辑
  // ═══════════════════════════════════════════

  /**
   * 上一月
   */
  private prevMonth(): void {
    if (this.currentMonth === 1) {
      this.currentMonth = 12;
      this.currentYear--;
    } else {
      this.currentMonth--;
    }
  }

  /**
   * 下一月（不超当前月份）
   */
  private nextMonth(): void {
    const now = new Date();
    const nowYear = now.getFullYear();
    const nowMonth = now.getMonth() + 1;

    if (this.currentYear === nowYear && this.currentMonth >= nowMonth) {
      return; // 已是当前月，不再前进
    }

    if (this.currentMonth === 12) {
      this.currentMonth = 1;
      this.currentYear++;
    } else {
      this.currentMonth++;
    }
  }
}
