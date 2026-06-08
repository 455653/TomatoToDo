// ===== pages/StatPage.ets =====
// 专注统计页面 —— 今日概览 / 本周趋势 / 月度热力图 / 累计成就

import { WeekChart } from '../components/WeekChart';
import { MonthHeatmap } from '../components/MonthHeatmap';
import { AuthGuard } from '../utils/AuthGuard';
import { StatViewModel, DayData } from '../viewmodel/StatViewModel';

class MetricCardParams {
  label: string = '';
  value: string = '';
  accentColor: string = '';
}

class StatColParams {
  emojiLabel: string = '';
  value: string = '';
}

@Entry
@Component
export struct StatPage {
  /** 热力图展示的年份 */
  @State currentYear: number = new Date().getFullYear();
  /** 热力图展示的月份 1~12 */
  @State @Watch('onMonthChange') currentMonth: number = new Date().getMonth() + 1;

  // UI 绑定的状态变量
  @State todayFocusCount: number = 0;
  @State todayMinutes: number = 0;
  @State todayDoneTasks: number = 0;
  @State todayQualityScore: number = 0;
  @State weekData: DayData[] = [];
  @State monthHeatmap: Map<string, number> = new Map();
  @State totalFocusCount: number = 0;
  @State totalHours: number = 0;
  @State streakDays: number = 0;
  @State monthFocusCount: number = 0;
  @State monthHours: number = 0;
  @State monthStreakDays: number = 0;
  
  // 组件唯一标识，用于强制刷新子组件
  @State refreshId: string = 'initial';
  // 累计成就区块重建密钥：月份切换时递增，强制 BuildCumulative 重建
  @State cumulativeKey: string = 'cumulative_initial';
  // 数据是否已加载完成（解决 Tab 缓存导致 @State 文本不更新的问题）
  @State isDataLoaded: boolean = false;
  // 数据加载中
  @State isLoading: boolean = false;

  /** 使用 StatViewModel 管理数据 */
  private viewModel: StatViewModel = new StatViewModel();

  /** 加载锁，防止并发重复 loadData */
  private isLoadingData: boolean = false;

  /**
   * 响应 AppStorage 刷新信号
   * 由 Index.onChange（切 Tab）和 TimerViewModel.stop()（完成专注）触发
   * 这是比 emitter 更可靠的跨 Tab 刷新机制，不受 CACHE_BOTH_SIDE 影响
   */
  @StorageProp('statRefreshTrigger') @Watch('onStatRefresh') statRefreshTrigger: number = 0;

  async aboutToAppear(): Promise<void> {
    console.log('[StatPage] aboutToAppear called');
    await this.loadData();
  }

  aboutToDisappear(): void {
    console.log('[StatPage] aboutToDisappear');
  }

  async aboutToReappear(): Promise<void> {
    console.log('[StatPage] aboutToReappear called, reloading data...');
    this.isDataLoaded = false;
    await this.loadData();
  }

  /**
   * 月份切换回调 —— @Watch 触发
   * 当 currentMonth 变化时（无论是点击 ◀/▶ 还是其他方式），
   * 自动重新计算选中月份的统计并强制刷新累计成就区块
   */
  onMonthChange(): void {
    console.log(`[StatPage] onMonthChange: ${this.currentYear}-${this.currentMonth}`);
    if (this.isDataLoaded) {
      this.viewModel.recalcMonthStats(this.currentYear, this.currentMonth);
      this.monthFocusCount = this.viewModel.monthFocusCount;
      this.monthHours = this.viewModel.monthHours;
      this.monthStreakDays = this.viewModel.monthStreakDays;
      // 更新 cumulativeKey → 强制累计成就区块的 Column 销毁→重建
      this.cumulativeKey = `cumulative_${this.currentYear}_${this.currentMonth}_${Date.now()}`;
      console.log(`[StatPage] onMonthChange synced: focusCount=${this.monthFocusCount}, hours=${this.monthHours}, streak=${this.monthStreakDays}`);
    }
  }

  /**
   * AppStorage 刷新回调 —— 当 statRefreshTrigger 变化时自动触发
   */
  onStatRefresh(): void {
    console.log('[StatPage] statRefreshTrigger changed, reloading data...');
    this.isDataLoaded = false;
    this.loadData(); // 异步调用，不阻塞 UI 线程
  }

  /**
   * 加载数据（带 AuthGuard 就绪等待 + 防并发锁）
   */
  private async loadData(): Promise<void> {
    // 防并发：如果已有 loadData 正在执行，跳过本次调用
    if (this.isLoadingData) {
      console.log('[StatPage] loadData skipped - already loading');
      return;
    }
    this.isLoadingData = true;
    console.log('========== [StatPage] loadData ==========');

    // 防御式等待：AuthGuard 可能因 Tab 预创建时序尚未就绪
    let userId = AuthGuard.getCurrentUserId();
    if (userId <= 0) {
      console.log('[StatPage] userId invalid, waiting for AuthGuard...');
      // 轮询等待最多 1000ms
      for (let i = 0; i < 10; i++) {
        await this.sleep(100);
        userId = AuthGuard.getCurrentUserId();
        if (userId > 0) {
          console.log(`[StatPage] AuthGuard ready after ${(i + 1) * 100}ms, userId=${userId}`);
          break;
        }
      }
    }

    if (userId <= 0) {
      console.log('[StatPage] userId still invalid after wait, skipping');
      this.isLoadingData = false;
      return;
    }

    this.isLoading = true;

    try {
      // 创建新的 ViewModel 避免缓存
      this.viewModel = new StatViewModel();
      await this.viewModel.loadAll();
      this.syncFromViewModel();
      this.isDataLoaded = true;

      console.log('========== [StatPage] loadData complete ==========');
    } catch (err) {
      console.error('[StatPage] loadData error:', JSON.stringify(err));
    } finally {
      this.isLoading = false;
      this.isLoadingData = false;
    }
  }

  /**
   * 工具：暂停 ms 毫秒
   */
  private sleep(ms: number): Promise<void> {
    return new Promise<void>((resolve: (value: void) => void) => {
      setTimeout(() => { resolve(); }, ms);
    });
  }

  private syncFromViewModel(): void {
    console.log('[StatPage] syncFromViewModel START');

    // 直接同步更新
    this.todayFocusCount = this.viewModel.todayFocusCount;
    this.todayMinutes = this.viewModel.todayMinutes;
    this.todayDoneTasks = this.viewModel.todayDoneTasks;
    this.todayQualityScore = this.viewModel.todayQualityScore;
    this.weekData = [...this.viewModel.weekData];
    this.monthHeatmap = new Map(this.viewModel.monthHeatmap);
    this.totalFocusCount = this.viewModel.totalFocusCount;
    this.totalHours = this.viewModel.totalHours;
    this.streakDays = this.viewModel.streakDays;
    this.monthFocusCount = this.viewModel.monthFocusCount;
    this.monthHours = this.viewModel.monthHours;
    this.monthStreakDays = this.viewModel.monthStreakDays;
    // 更新时间戳，触发 .key() 整树重建强制所有子组件刷新
    this.refreshId = Date.now().toString();

    console.log('[StatPage] syncFromViewModel END');
    console.log(`[StatPage] synced: todayFocusCount=${this.todayFocusCount}, todayMinutes=${this.todayMinutes}, todayDoneTasks=${this.todayDoneTasks}, todayQualityScore=${this.todayQualityScore}`);
    console.log(`[StatPage] synced: totalFocusCount=${this.totalFocusCount}, totalHours=${this.totalHours}, streakDays=${this.streakDays}`);
    console.log(`[StatPage] synced: monthFocusCount=${this.monthFocusCount}, monthHours=${this.monthHours}, monthStreakDays=${this.monthStreakDays}`);
    console.log(`[StatPage] synced: weekData length=${this.weekData.length}, monthHeatmap size=${this.monthHeatmap.size}, refreshId=${this.refreshId}`);
  }

  build() {
    Scroll() {
      Column() {
        this.BuildTitleBar()

        Divider().margin({ top: 12, bottom: 4 })

        this.BuildSectionTitle('今日概览')
        // 两阶段渲染：数据就绪前展示 "--" 骨架，就绪后展示真实数据
        if (this.isDataLoaded) {
          this.BuildTodayMetrics()
        } else {
          this.BuildLoadingMetrics()
        }

        Divider().margin({ top: 16, bottom: 12 })

        this.BuildSectionTitle('本周趋势')
        WeekChart({
          data: this.weekData,
          refreshKey: this.refreshId
        })

        Divider().margin({ top: 16, bottom: 12 })

        this.BuildSectionTitle('本月热力图')
        MonthHeatmap({
          data: this.monthHeatmap,
          year: this.currentYear,
          month: this.currentMonth,
          refreshKey: this.refreshId
        })

        Divider().margin({ top: 16, bottom: 12 })

        this.BuildSectionTitle('累计成就')
        Column() {
          if (this.isDataLoaded) {
            this.BuildCumulative()
          } else {
            this.BuildCumulativeLoading()
          }
        }
        .key(this.cumulativeKey)

        Column().height(24)
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
      .key(this.refreshId)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
    .scrollBar(BarState.Off)
  }

  @Builder
  BuildTitleBar() {
    Row() {
      Text('专注统计')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')

      Blank()

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

  @Builder
  BuildTodayMetrics() {
    Row({ space: 8 }) {
      this.BuildMetricCard({ label: '专注次数', value: this.todayFocusCount.toString(), accentColor: '#FF6347' } as MetricCardParams)
      this.BuildMetricCard({ label: '专注分钟', value: this.todayMinutes.toString(), accentColor: '#4CAF50' } as MetricCardParams)
      this.BuildMetricCard({ label: '涉及任务', value: this.todayDoneTasks.toString(), accentColor: '#2196F3' } as MetricCardParams)
      this.BuildMetricCard({
        label: '质量分',
        value: this.todayFocusCount === 0 ? '--' : this.todayQualityScore.toString(),
        accentColor: this.todayQualityScore >= 60 ? '#4CAF50' : '#FF9800'
      } as MetricCardParams)
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
  }

  /** 数据加载中的骨架指标（展示 "--" 避免误导用户显示 0） */
  @Builder
  BuildLoadingMetrics() {
    Row({ space: 8 }) {
      this.BuildMetricCard({ label: '专注次数', value: '--', accentColor: '#CCCCCC' } as MetricCardParams)
      this.BuildMetricCard({ label: '专注分钟', value: '--', accentColor: '#CCCCCC' } as MetricCardParams)
      this.BuildMetricCard({ label: '涉及任务', value: '--', accentColor: '#CCCCCC' } as MetricCardParams)
      this.BuildMetricCard({ label: '质量分', value: '--', accentColor: '#CCCCCC' } as MetricCardParams)
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
  }

  @Builder
  BuildMetricCard($$: MetricCardParams) {
    Column() {
      Text($$.value)
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor($$.accentColor)

      Text($$.label)
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

  @Builder
  BuildCumulative() {
    Column({ space: 12 }) {
      // 本月成就
      Row() {
        Text('本月成就')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#666666')
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      
      Row({ space: 8 }) {
        this.BuildStatCol({ emojiLabel: '📅 本月次数', value: `${this.monthFocusCount} 次` } as StatColParams)
        this.BuildStatCol({ emojiLabel: '⏱️ 本月时长', value: `${this.monthHours} 小时` } as StatColParams)
        this.BuildStatCol({ emojiLabel: '🔥 本月连续', value: `${this.monthStreakDays} 天` } as StatColParams)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      // 历史总计
      Row() {
        Text('历史总计')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#666666')
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .margin({ top: 8 })

      Row({ space: 8 }) {
        this.BuildStatCol({ emojiLabel: '🥇 总次数', value: `${this.totalFocusCount} 次` } as StatColParams)
        this.BuildStatCol({ emojiLabel: '🌟 总时长', value: `${this.totalHours} 小时` } as StatColParams)
        this.BuildStatCol({ emojiLabel: '🏆 历史最长', value: `${this.streakDays} 天` } as StatColParams)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .width('100%')
  }

  /** 累计成就加载骨架（展示 "--" 避免误导用户） */
  @Builder
  BuildCumulativeLoading() {
    Column({ space: 12 }) {
      // 本月成就骨架
      Row() {
        Text('本月成就')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#666666')
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)

      Row({ space: 8 }) {
        this.BuildStatCol({ emojiLabel: '📅 本月次数', value: '-- 次' } as StatColParams)
        this.BuildStatCol({ emojiLabel: '⏱️ 本月时长', value: '-- 小时' } as StatColParams)
        this.BuildStatCol({ emojiLabel: '🔥 本月连续', value: '-- 天' } as StatColParams)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      // 历史总计骨架
      Row() {
        Text('历史总计')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#666666')
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .margin({ top: 8 })

      Row({ space: 8 }) {
        this.BuildStatCol({ emojiLabel: '🥇 总次数', value: '-- 次' } as StatColParams)
        this.BuildStatCol({ emojiLabel: '🌟 总时长', value: '-- 小时' } as StatColParams)
        this.BuildStatCol({ emojiLabel: '🏆 历史最长', value: '-- 天' } as StatColParams)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .width('100%')
  }

  @Builder
  BuildStatCol($$: StatColParams) {
    Column() {
      Text($$.emojiLabel)
        .fontSize(12)
        .fontColor('#666666')

      Text($$.value)
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

  @Builder
  BuildSectionTitle(title: string) {
    Text(title)
      .fontSize(16)
      .fontWeight(FontWeight.Bold)
      .fontColor('#333333')
      .width('100%')
      .margin({ bottom: 10 })
  }

  private prevMonth(): void {
    if (this.currentMonth === 1) {
      this.currentMonth = 12;
      this.currentYear--;
    } else {
      this.currentMonth--;
    }
    this.recalcMonthStats();
  }

  private nextMonth(): void {
    const now = new Date();
    const nowYear = now.getFullYear();
    const nowMonth = now.getMonth() + 1;

    if (this.currentYear === nowYear && this.currentMonth >= nowMonth) {
      return;
    }

    if (this.currentMonth === 12) {
      this.currentMonth = 1;
      this.currentYear++;
    } else {
      this.currentMonth++;
    }
    this.recalcMonthStats();
  }

  /**
   * 月份切换后重新计算该月的统计数据
   * 复用 StatViewModel 中已缓存的 completedSessions，无需重新查询数据库
   */
  private recalcMonthStats(): void {
    this.viewModel.recalcMonthStats(this.currentYear, this.currentMonth);
    // 同步月份相关字段到 UI
    this.monthFocusCount = this.viewModel.monthFocusCount;
    this.monthHours = this.viewModel.monthHours;
    this.monthStreakDays = this.viewModel.monthStreakDays;
    // 更新 refreshId 强制 MonthHeatmap / WeekChart / 整棵子树完全重建
    this.refreshId = Date.now().toString();
    // 更新 cumulativeKey 强制累计成就区块销毁→重建（绕过 @Builder 缓存）
    this.cumulativeKey = `cumulative_${this.currentYear}_${this.currentMonth}_${Date.now()}`;
    console.log(`[StatPage] recalcMonthStats: ${this.currentYear}-${this.currentMonth} → focusCount=${this.monthFocusCount}, hours=${this.monthHours}, streak=${this.monthStreakDays}`);
  }
}
