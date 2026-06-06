// ===== pages/TimerPage.ets =====
// 番茄钟计时主页面

import { promptAction } from '@kit.ArkUI';
import { emitter } from '@kit.BasicServicesKit';
import { Task } from '../model/TaskModel';
import { Collection } from '../model/CollectionModel';
import { TaskDao } from '../database/TaskDao';
import { CollectionDao } from '../database/CollectionDao';
import { TimerViewModel, TimerState } from '../viewmodel/TimerViewModel';
import { RingTimer } from '../components/RingTimer';
import { AuthGuard } from '../utils/AuthGuard';

/** 默认专注分钟数 */
const FOCUS_MINUTES = 25;

/** emitter tick 事件 ID（与 TimerService 保持一致） */
const EVENT_TICK = 1003;

/** tick 事件数据结构 */
interface TickEvent {
  remainSeconds: number;
  timerState: string;
}

/** 按合集分组后的任务项 */
interface GroupedTaskItem {
  task: Task;
  collectionName: string;
  collectionColor: string;
}

@Entry
@Component
export struct TimerPage {
  /** 剩余秒数，由 TimerService 通过 emitter 事件驱动 */
  @State remainSeconds: number = FOCUS_MINUTES * 60;

  /** 计时器 ViewModel */
  private viewModel: TimerViewModel = new TimerViewModel();

  /** 任务选择器展开状态 */
  @State showTaskPicker: boolean = false;
  /** 可选任务列表（分组后的扁平列表） */
  @State availableTasks: GroupedTaskItem[] = [];
  /** 所有合集 */
  @State collections: Collection[] = [];
  /** 任务列表加载中 */
  @State tasksLoading: boolean = false;

  /** tick 事件回调引用，用于 aboutToDisappear 时解绑 */
  private tickCallback?: (eventData: emitter.EventData) => void;

  async aboutToAppear(): Promise<void> {
    await this.viewModel.loadTodayStats();
    // 监听 TimerService 发来的 tick 事件
    this.tickCallback = (eventData: emitter.EventData) => {
      const tick = eventData.data as TickEvent;
      if (tick) {
        this.remainSeconds = tick.remainSeconds;
      }
    };
    emitter.on({ eventId: EVENT_TICK }, this.tickCallback);
  }

  aboutToDisappear(): void {
    if (this.tickCallback) {
      emitter.off(EVENT_TICK, this.tickCallback);
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 主内容层
      Column() {
        // ---- 任务选择器 ----
        this.buildTaskSelector()

        // ---- 计时圆环 ----
        this.buildRingArea()

        // ---- 按钮组 ----
        this.buildButtonGroup()

        // ---- 统计信息 ----
        this.buildStats()
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#FFFFFF')
      .padding({ top: 16, bottom: 24 })

      // 遮罩 + 任务选择面板
      if (this.showTaskPicker) {
        this.buildTaskPickerOverlay()
      }
    }
    .width('100%')
    .height('100%')
  }

  // ═══════════════════════════════════════════════
  // 任务选择器
  // ═══════════════════════════════════════════════

  @Builder
  buildTaskSelector() {
    Row() {
      Text('任务：')
        .fontSize(15)
        .fontColor('#666666')

      Text(this.viewModel.selectedTask ? this.viewModel.selectedTask.title : '未选择')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.viewModel.selectedTask ? '#333333' : '#CCCCCC')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)

      Text('▾')
        .fontSize(14)
        .fontColor('#999999')
    }
    .width('100%')
    .height(44)
    .padding({ left: 20, right: 20 })
    .backgroundColor('#F8F8F8')
    .borderRadius(8)
    .margin({ left: 20, right: 20, bottom: 8 })
    .onClick(() => {
      this.toggleTaskPicker();
    })
    .alignItems(VerticalAlign.Center)
  }

  // ═══════════════════════════════════════════════
  // 计时圆环区域
  // ═══════════════════════════════════════════════

  @Builder
  buildRingArea() {
    Stack() {
      RingTimer({
        progress: this.viewModel.getProgress(this.remainSeconds, this.viewModel.state),
        remainSeconds: this.remainSeconds,
        state: this.viewModel.state,
        pomodoroIndex: this.viewModel.currentPomodoro,
      })
    }
    .width('100%')
    .height(320)
    .margin({ top: 16, bottom: 16 })
  }

  // ═══════════════════════════════════════════════
  // 按钮组
  // ═══════════════════════════════════════════════

  @Builder
  buildButtonGroup() {
    Column() {
      if (this.viewModel.state === TimerState.IDLE) {
        this.buildPrimaryButton('开 始', '#FF6347', () => {
          this.onStart();
        })
      } else if (this.viewModel.state === TimerState.FOCUSING) {
        Row({ space: 20 }) {
          this.buildSecondaryButton('暂 停', '#FF9800', () => {
            this.onPause();
          })
          this.buildSecondaryButton('放 弃', '#999999', () => {
            this.onStop();
          })
        }
        .justifyContent(FlexAlign.Center)
      } else if (this.viewModel.state === TimerState.PAUSED) {
        Row({ space: 20 }) {
          this.buildSecondaryButton('继 续', '#4CAF50', () => {
            this.onResume();
          })
          this.buildSecondaryButton('放 弃', '#999999', () => {
            this.onStop();
          })
        }
        .justifyContent(FlexAlign.Center)
      } else if (this.viewModel.state === TimerState.SHORT_BREAK ||
        this.viewModel.state === TimerState.LONG_BREAK) {
        this.buildPrimaryButton('跳过休息', '#4CAF50', () => {
          this.onSkip();
        })
      }
    }
    .width('100%')
    .padding({ left: 40, right: 40 })
  }

  @Builder
  buildPrimaryButton(label: string, color: string, action: () => void) {
    Button(label)
      .width('100%')
      .height(52)
      .fontSize(20)
      .fontWeight(FontWeight.Bold)
      .fontColor('#FFFFFF')
      .backgroundColor(color)
      .borderRadius(26)
      .onClick(action)
  }

  @Builder
  buildSecondaryButton(label: string, color: string, action: () => void) {
    Button(label)
      .width(130)
      .height(48)
      .fontSize(17)
      .fontWeight(FontWeight.Medium)
      .fontColor('#FFFFFF')
      .backgroundColor(color)
      .borderRadius(24)
      .onClick(action)
  }

  // ═══════════════════════════════════════════════
  // 统计行
  // ═══════════════════════════════════════════════

  @Builder
  buildStats() {
    Text(`今日已完成 ${this.viewModel.todayPomodoros} 个番茄，共 ${this.viewModel.todayMinutes} 分钟`)
      .fontSize(13)
      .fontColor('#999999')
      .margin({ top: 24 })
      .textAlign(TextAlign.Center)
      .width('100%')
  }

  // ═══════════════════════════════════════════════
  // 任务选择弹层（按合集分组显示）
  // ═══════════════════════════════════════════════

  @Builder
  buildTaskPickerOverlay() {
    // 半透明遮罩背景
    Column() {
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#66000000')
    .onClick(() => {
      this.showTaskPicker = false;
    })

    // 任务选择面板（居中悬浮）
    Column() {
      Text('选择任务')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')
        .width('100%')
        .padding({ left: 20, top: 16, bottom: 12 })

      if (this.availableTasks.length === 0) {
        Text('暂无任务，请先在任务页添加')
          .fontSize(14)
          .fontColor('#999999')
          .padding(20)
      } else {
        List() {
          ForEach(this.availableTasks, (item: GroupedTaskItem, index: number) => {
            ListItem() {
              this.buildPickerItem(item, index)
            }
          }, (item: GroupedTaskItem, index: number) => `${index}_${item.task.id}`)
        }
        .constraintSize({ maxHeight: 300 })
      }

      Button('取消')
        .width('100%')
        .height(44)
        .fontSize(15)
        .fontColor('#999999')
        .backgroundColor('#F5F5F5')
        .onClick(() => {
          this.showTaskPicker = false;
        })
    }
    .width('85%')
    .constraintSize({ maxHeight: '50%' })
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .align(Alignment.Center)
  }

  /**
   * 任务选择项（区分合集 header 和任务项）
   */
  @Builder
  buildPickerItem(item: GroupedTaskItem, index: number) {
    // 判断是否需要显示合集 section header
    if (index === 0 || this.availableTasks[index - 1].collectionName !== item.collectionName) {
      // 合集 section header
      Column() {
        // Header 行
        Row() {
          // 颜色圆点
          Column()
            .width(10)
            .height(10)
            .borderRadius(5)
            .backgroundColor(item.collectionColor || '#999999')
            .margin({ right: 6 })

          Text(item.collectionName || '未分类')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(item.collectionColor || '#999999')
        }
        .width('100%')
        .height(32)
        .padding({ left: 20, right: 20 })
        .backgroundColor('#F8F8F8')
        .alignItems(VerticalAlign.Center)

        // 任务行
        this.buildTaskRow(item)
      }
    } else {
      // 仅任务行
      this.buildTaskRow(item)
    }
  }

  @Builder
  buildTaskRow(item: GroupedTaskItem) {
    Row() {
      Text(item.task.title)
        .fontSize(16)
        .fontColor('#333333')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)

      if (this.viewModel.selectedTask && this.viewModel.selectedTask.id === item.task.id) {
        Text('✓')
          .fontSize(18)
          .fontColor('#FF6347')
          .fontWeight(FontWeight.Bold)
      }
    }
    .width('100%')
    .height(48)
    .padding({ left: 20, right: 20 })
    .onClick(() => {
      this.viewModel.selectedTask = item.task;
      this.showTaskPicker = false;
    })
  }

  // ═══════════════════════════════════════════════
  // 业务逻辑
  // ═══════════════════════════════════════════════

  /**
   * 展开/收起任务选择器
   */
  private async toggleTaskPicker(): Promise<void> {
    if (this.showTaskPicker) {
      this.showTaskPicker = false;
      return;
    }
    this.showTaskPicker = true;
    if (this.availableTasks.length === 0 && !this.tasksLoading) {
      await this.loadAvailableTasks();
    }
  }

  /**
   * 加载用户任务列表，按合集分组
   */
  private async loadAvailableTasks(): Promise<void> {
    try {
      this.tasksLoading = true;
      const userId = AuthGuard.getCurrentUserId();
      if (userId <= 0) {
        return;
      }

      // 并行加载合集和任务
      const taskDao = new TaskDao();
      const collectionDao = new CollectionDao();
      const results = await Promise.all([
        taskDao.findAllByUser(userId),
        collectionDao.findAllByUser(userId),
      ]);
      const tasks: Task[] = results[0] as Task[];
      const collections: Collection[] = results[1] as Collection[];
      this.collections = collections;

      // 构建合集名称映射
      const collectionMap: Map<number, Collection> = new Map();
      for (const col of collections) {
        collectionMap.set(col.id, col);
      }

      // 按合集分组排序：先按合集创建时间排序（新在前），未分类放最后
      const grouped: GroupedTaskItem[] = [];

      // 有合集的任务
      for (const col of collections) {
        for (const task of tasks) {
          if (task.collectionId === col.id) {
            grouped.push({
              task: task,
              collectionName: col.name,
              collectionColor: col.color,
            });
          }
        }
      }

      // 未分类任务
      for (const task of tasks) {
        if (task.collectionId === 0) {
          grouped.push({
            task: task,
            collectionName: '未分类',
            collectionColor: '#999999',
          });
        }
      }

      this.availableTasks = grouped;
    } catch (err) {
      promptAction.showToast({ message: '加载任务失败', duration: 1500 });
    } finally {
      this.tasksLoading = false;
    }
  }

  /**
   * 开始专注
   */
  private onStart(): void {
    this.viewModel.start();
  }

  /**
   * 暂停
   */
  private onPause(): void {
    this.viewModel.pause();
  }

  /**
   * 恢复
   */
  private onResume(): void {
    this.viewModel.resume();
  }

  /**
   * 跳过休息
   */
  private onSkip(): void {
    this.viewModel.skip();
  }

  /**
   * 放弃
   */
  private async onStop(): Promise<void> {
    this.viewModel.stop();
    await this.viewModel.loadTodayStats();
  }
}
