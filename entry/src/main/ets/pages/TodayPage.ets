// ===== pages/TodayPage.ets =====
// 今日待办页面

import { promptAction } from '@kit.ArkUI';
import { Task } from '../model/TaskModel';
import { TodayViewModel } from '../viewmodel/TodayViewModel';

@Entry
@Component
export struct TodayPage {
  private viewModel: TodayViewModel = new TodayViewModel();

  @State activeMilestone: Task[] = [];
  @State overdueMilestone: Task[] = [];
  @State habits: Task[] = [];
  @State completedHabitIdSet: number[] = [];
  @State totalTasks: number = 0;
  @State completedCount: number = 0;
  @State isLoading: boolean = false;

  async aboutToAppear(): Promise<void> {
    await this.refresh();
  }

  build() {
    Column() {
      this.buildHeader()
      this.buildStatsRow()
      Scroll() {
        Column() {
          this.buildMilestoneSection()
          this.buildHabitSection()
        }
        .padding({ left: 16, right: 16 })
      }
      .scrollBar(BarState.Off)
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F8F8F8')
  }

  // --------------------------------------------------
  // 顶部标题
  // --------------------------------------------------
  @Builder
  buildHeader() {
    Row() {
      Text('📋 今日待办')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')
      Blank()
      Text(this.getTodayDisplay())
        .fontSize(13)
        .fontColor('#999999')
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 16, bottom: 8 })
    .backgroundColor('#FFFFFF')
  }

  // --------------------------------------------------
  // 统计行
  // --------------------------------------------------
  @Builder
  buildStatsRow() {
    Row() {
      Text(`共 ${this.totalTasks} 项待办`)
        .fontSize(13)
        .fontColor('#666666')
      Text(' · ')
        .fontSize(13)
        .fontColor('#CCCCCC')
      Text(`已完成 ${this.completedCount} 项`)
        .fontSize(13)
        .fontColor(this.completedCount > 0 ? '#4CAF50' : '#666666')
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 8, bottom: 12 })
    .backgroundColor('#FFFFFF')
  }

  // --------------------------------------------------
  // 阶段性任务分区
  // --------------------------------------------------
  @Builder
  buildMilestoneSection() {
    Column() {
      // 分区标题
      Row() {
        Text('阶段性任务')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
        Text(` ${this.viewModel.activeCount + this.viewModel.overdueCount}`)
          .fontSize(14)
          .fontColor('#999999')
      }
      .width('100%')
      .margin({ top: 16, bottom: 10 })

      // 活跃任务
      if (this.activeMilestone.length > 0) {
        ForEach(this.activeMilestone, (task: Task) => {
          this.buildMilestoneCard(task, false)
        }, (task: Task) => `active_${task.id}`)
      }

      // 已过期分区
      if (this.overdueMilestone.length > 0) {
        Row() {
          Text('⚠️ 已过期')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FF4444')
          Text(` ${this.overdueMilestone.length}`)
            .fontSize(13)
            .fontColor('#FF4444')
        }
        .width('100%')
        .margin({ top: 12, bottom: 8 })

        ForEach(this.overdueMilestone, (task: Task) => {
          this.buildMilestoneCard(task, true)
        }, (task: Task) => `overdue_${task.id}`)
      }

      // 空状态
      if (this.activeMilestone.length === 0 && this.overdueMilestone.length === 0) {
        Text('暂无阶段性任务')
          .fontSize(14)
          .fontColor('#CCCCCC')
          .padding({ top: 12, bottom: 20 })
          .width('100%')
          .textAlign(TextAlign.Center)
      }
    }
    .width('100%')
  }

  /**
   * 阶段性任务卡片
   * @param isOverdue 是否已过期
   */
  @Builder
  buildMilestoneCard(task: Task, isOverdue: boolean) {
    Column() {
      Row() {
        // 左侧勾选框
        Column() {
          if (task.done) {
            Text('✓').fontSize(16).fontColor('#FFFFFF').fontWeight(FontWeight.Bold)
          }
        }
        .width(28).height(28).borderRadius(14)
        .backgroundColor(task.done ? '#4CAF50' : '#E0E0E0')
        .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
        .onClick(() => { this.onToggleMilestone(task); })

        // 中间：标题 + 日期
        Column() {
          Text(task.title)
            .fontSize(16).fontWeight(FontWeight.Medium)
            .fontColor(task.done ? '#999999' : '#333333')
            .decoration({ type: task.done ? TextDecorationType.LineThrough : TextDecorationType.None })
            .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(`${this.formatDate(task.startDate)} ~ ${this.formatDate(task.endDate)}`)
            .fontSize(12).fontColor('#999999').margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 12 })

        // 右侧：优先级 + 天数
        Row() {
          Text(this.getPriorityLabel(task.priority))
            .fontSize(11).fontColor('#FFFFFF').fontWeight(FontWeight.Bold)
            .width(28).height(28).borderRadius(4)
            .backgroundColor(this.getPriorityColor(task.priority))
            .textAlign(TextAlign.Center)

          if (isOverdue) {
            Text(`过期${this.getDaysDiff(task.endDate)}天`)
              .fontSize(12).fontColor('#FF4444')
              .backgroundColor('#FFF0F0').borderRadius(4)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .margin({ left: 8 })
          } else {
            Text(`还剩${this.getDaysRemaining(task.endDate)}天`)
              .fontSize(12).fontColor('#4CAF50')
              .margin({ left: 8 })
          }
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({ top: 12, bottom: 12, left: 12, right: 12 })
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .margin({ bottom: 8 })
  }

  // --------------------------------------------------
  // 习惯性任务分区
  // --------------------------------------------------
  @Builder
  buildHabitSection() {
    Column() {
      // 分区标题
      Row() {
        Text('🔄 每日习惯')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
        Text(` ${this.completedHabitIdSet.length}/${this.habits.length}`)
          .fontSize(14)
          .fontColor('#999999')
      }
      .width('100%')
      .margin({ top: 20, bottom: 10 })

      if (this.habits.length > 0) {
        ForEach(this.habits, (task: Task) => {
          this.buildHabitCard(task)
        }, (task: Task) => `habit_${task.id}`)
      }

      // 空状态
      if (this.habits.length === 0) {
        Text('暂无习惯性任务')
          .fontSize(14)
          .fontColor('#CCCCCC')
          .padding({ top: 12, bottom: 80 })
          .width('100%')
          .textAlign(TextAlign.Center)
      }
    }
    .width('100%')
  }

  /**
   * 习惯性任务卡片
   */
  @Builder
  buildHabitCard(task: Task) {

    Column() {
      Row() {
        // 左侧打卡圆
        Column() {
          if (this.completedHabitIdSet.includes(task.id)) {
            Text('✓').fontSize(16).fontColor('#FFFFFF').fontWeight(FontWeight.Bold)
          }
        }
        .width(28).height(28).borderRadius(14)
        .backgroundColor(this.completedHabitIdSet.includes(task.id) ? '#4CAF50' : '#E0E0E0')
        .border({ width: this.completedHabitIdSet.includes(task.id) ? 0 : 2, color: '#E0E0E0' })
        .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
        .onClick(() => { this.onToggleHabit(task); })

        // 中间：标题 + 副标题
        Column() {
          Text(task.title)
            .fontSize(16).fontWeight(FontWeight.Medium)
            .fontColor('#333333')
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text('每日习惯')
            .fontSize(12).fontColor('#999999').margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 12 })

        // 右侧：优先级
        Text(this.getPriorityLabel(task.priority))
          .fontSize(11).fontColor('#FFFFFF').fontWeight(FontWeight.Bold)
          .width(28).height(28).borderRadius(4)
          .backgroundColor(this.getPriorityColor(task.priority))
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({ top: 12, bottom: 12, left: 12, right: 12 })
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .margin({ bottom: 8 })
  }

  // ====================================================
  // 业务方法
  // ====================================================

  private async refresh(): Promise<void> {
    try {
      this.isLoading = true;
      await this.viewModel.loadToday();
      this.syncFromViewModel();
    } catch (err) {
      promptAction.showToast({ message: `加载失败: ${JSON.stringify(err)}`, duration: 2000 });
    } finally {
      this.isLoading = false;
    }
  }

  private syncFromViewModel(): void {
    this.activeMilestone = [...this.viewModel.activeMilestoneTasks];
    this.overdueMilestone = [...this.viewModel.overdueMilestoneTasks];
    this.habits = [...this.viewModel.habitTasks];
    this.completedHabitIdSet = [...this.viewModel.completedHabitIds];
    this.totalTasks = this.viewModel.totalTodayTasks;
    this.completedCount = this.viewModel.completedTodayCount;
  }

  private async onToggleMilestone(task: Task): Promise<void> {
    try {
      await this.viewModel.toggleMilestoneTask(task);
      this.syncFromViewModel();
    } catch (err) {
      promptAction.showToast({ message: '操作失败', duration: 1500 });
    }
  }

  private async onToggleHabit(task: Task): Promise<void> {
    try {
      await this.viewModel.toggleHabitTask(task);
      this.syncFromViewModel();
    } catch (err) {
      promptAction.showToast({ message: '打卡失败', duration: 1500 });
    }
  }

  // ====================================================
  // 工具方法
  // ====================================================

  /** 格式化时间戳为 'YYYY-MM-DD' */
  private formatDate(timestamp: number): string {
    if (timestamp <= 0) return '未设置';
    const d = new Date(timestamp);
    const y = d.getFullYear();
    const m = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${y}-${m}-${day}`;
  }

  /** 今日显示：'2026年6月6日 星期六' */
  private getTodayDisplay(): string {
    const d = new Date();
    const weekdays = ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六'];
    return `${d.getFullYear()}年${d.getMonth() + 1}月${d.getDate()}日 ${weekdays[d.getDay()]}`;
  }

  /** 剩余天数 */
  private getDaysRemaining(endTimestamp: number): number {
    const now = this.viewModel.getTodayStartMs();
    return Math.max(0, Math.ceil((endTimestamp - now) / 86400000));
  }

  /** 已过期天数 */
  private getDaysDiff(endTimestamp: number): number {
    const now = this.viewModel.getTodayStartMs();
    return Math.ceil((now - endTimestamp) / 86400000);
  }

  private getPriorityColor(priority: number): string {
    if (priority === 2) return '#FF4444';
    if (priority === 1) return '#FF9800';
    return '#9E9E9E';
  }

  private getPriorityLabel(priority: number): string {
    if (priority === 2) return '高';
    if (priority === 1) return '中';
    return '低';
  }
}
