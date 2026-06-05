// ===== pages/TaskPage.ets =====
// 任务管理主页面

import { promptAction } from '@kit.ArkUI';
import { Task, Priority } from '../model/TaskModel';
import { TaskViewModel } from '../viewmodel/TaskViewModel';
import { TaskCard } from '../components/TaskCard';
import { AiDrawerContent } from '../components/AiDrawer';

// ============================================================
// AddTaskDialog —— 添加任务弹窗
// ============================================================

@CustomDialog
struct AddTaskDialog {
  /** 框架自动注入 */
  controller: CustomDialogController;
  /** 确认回调 */
  confirmCallback?: AddTaskCallback;

  /** 输入：任务名称 */
  @State inputTitle: string = '';
  /** 输入：番茄数 1-8 */
  @State pomodoroCount: number = 1;
  /** 输入：优先级 */
  @State selectedPriority: number = Priority.MEDIUM;

  /**
   * 弹窗即将出现时重置所有输入状态
   */
  aboutToAppear(): void {
    this.resetFields();
  }

  /**
   * 弹窗关闭时重置
   */
  aboutToDisappear(): void {
    this.resetFields();
  }

  resetFields(): void {
    this.inputTitle = '';
    this.pomodoroCount = 1;
    this.selectedPriority = Priority.MEDIUM;
  }

  build() {
    Column() {
      // ---- 标题 ----
      Text('添加任务')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')
        .margin({ top: 24, bottom: 20 })
        .width('100%')
        .textAlign(TextAlign.Center)

      // ---- 任务名输入 ----
      TextInput({ placeholder: '请输入任务名称', text: this.inputTitle })
        .width('100%')
        .height(44)
        .fontSize(15)
        .backgroundColor('#F5F5F5')
        .borderRadius(8)
        .padding({ left: 12, right: 12 })
        .margin({ bottom: 16 })
        .onChange((value: string) => {
          this.inputTitle = value;
        })

      // ---- 番茄数 Stepper ----
      Row() {
        Text('番茄数')
          .fontSize(15)
          .fontColor('#333333')

        Blank()

        Row() {
          Button('-')
            .width(36)
            .height(36)
            .fontSize(18)
            .fontColor('#FFFFFF')
            .backgroundColor(this.pomodoroCount <= 1 ? '#CCCCCC' : '#FF6347')
            .borderRadius(4)
            .enabled(this.pomodoroCount > 1)
            .onClick(() => {
              if (this.pomodoroCount > 1) {
                this.pomodoroCount--;
              }
            })

          Text(this.pomodoroCount.toString())
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
            .width(40)
            .textAlign(TextAlign.Center)

          Button('+')
            .width(36)
            .height(36)
            .fontSize(18)
            .fontColor('#FFFFFF')
            .backgroundColor(this.pomodoroCount >= 8 ? '#CCCCCC' : '#FF6347')
            .borderRadius(4)
            .enabled(this.pomodoroCount < 8)
            .onClick(() => {
              if (this.pomodoroCount < 8) {
                this.pomodoroCount++;
              }
            })
        }
      }
      .width('100%')
      .margin({ bottom: 16 })
      .alignItems(VerticalAlign.Center)

      // ---- 优先级选择 ----
      Row() {
        Text('优先级')
          .fontSize(15)
          .fontColor('#333333')

        Blank()

        Row({ space: 12 }) {
          // 低
          Row() {
            Radio({ value: 'low', group: 'priorityRadio' })
              .checked(this.selectedPriority === Priority.LOW)
              .onChange((isChecked: boolean) => {
                if (isChecked) {
                  this.selectedPriority = Priority.LOW;
                }
              })
            Text('低').fontSize(13).fontColor('#9E9E9E').margin({ left: 4 })
          }

          // 中
          Row() {
            Radio({ value: 'medium', group: 'priorityRadio' })
              .checked(this.selectedPriority === Priority.MEDIUM)
              .onChange((isChecked: boolean) => {
                if (isChecked) {
                  this.selectedPriority = Priority.MEDIUM;
                }
              })
            Text('中').fontSize(13).fontColor('#FF9800').margin({ left: 4 })
          }

          // 高
          Row() {
            Radio({ value: 'high', group: 'priorityRadio' })
              .checked(this.selectedPriority === Priority.HIGH)
              .onChange((isChecked: boolean) => {
                if (isChecked) {
                  this.selectedPriority = Priority.HIGH;
                }
              })
            Text('高').fontSize(13).fontColor('#FF4444').margin({ left: 4 })
          }
        }
      }
      .width('100%')
      .margin({ bottom: 24 })
      .alignItems(VerticalAlign.Center)

      // ---- 底部按钮 ----
      Row() {
        Button('取消')
          .layoutWeight(1)
          .height(44)
          .fontSize(16)
          .fontColor('#666666')
          .backgroundColor('#F0F0F0')
          .borderRadius(22)
          .onClick(() => {
            this.controller.close();
          })

        Blank().width(16)

        Button('确认添加')
          .layoutWeight(1)
          .height(44)
          .fontSize(16)
          .fontColor('#FFFFFF')
          .backgroundColor('#FF6347')
          .borderRadius(22)
          .onClick(() => {
            this.handleConfirm();
          })
      }
      .width('100%')
      .margin({ bottom: 24 })
    }
    .width('100%')
    .padding({ left: 20, right: 20 })
    .backgroundColor('#FFFFFF')
    .borderRadius({ topLeft: 16, topRight: 16 })
  }

  /**
   * 确认添加任务
   */
  private handleConfirm(): void {
    const title = this.inputTitle.trim();
    if (title.length === 0) {
      promptAction.showToast({ message: '请输入任务名称', duration: 1500 });
      return;
    }
    if (this.confirmCallback) {
      this.confirmCallback(title, this.pomodoroCount, this.selectedPriority);
    }
    this.controller.close();
  }
}

// ============================================================
// 回调类型别名
// ============================================================

/** 添加任务弹窗确认回调 */
type AddTaskCallback = (title: string, pomodoros: number, priority: number) => void;

// ============================================================
// TaskPage —— 任务管理主页面
// ============================================================

@Entry
@Component
export struct TaskPage {
  /** 任务 ViewModel */
  private viewModel: TaskViewModel = new TaskViewModel();

  /** 任务列表（从 ViewModel 同步到 @State 触发 UI 刷新） */
  @State tasks: Task[] = [];
  /** 待完成任务数 */
  @State pendingCount: number = 0;
  /** 已完成任务数 */
  @State todayDoneCount: number = 0;
  /** 列表加载状态 */
  @State isLoading: boolean = false;
  /** AI 拆解抽屉展开状态 */
  @State showAiDrawer: boolean = false;

  /** 添加任务弹窗控制器 */
  private addDialogController: CustomDialogController = new CustomDialogController({
    builder: AddTaskDialog({
      confirmCallback: (title: string, pomodoros: number, priority: number) => {
        this.onAddTaskConfirm(title, pomodoros, priority);
      },
    }),
    autoCancel: true,
    alignment: DialogAlignment.Bottom,
    customStyle: true,
    cornerRadius: 16,
  });

  /**
   * 页面出现时加载任务
   */
  async aboutToAppear(): Promise<void> {
    await this.refreshTaskList();
  }

  build() {
    Stack() {
      // ---- 主内容区 ----
      Column() {
        this.buildHeader()
        this.buildStatsRow()

        // 任务列表或空状态
        if (this.tasks.length === 0 && !this.isLoading) {
          this.buildEmptyState()
        } else {
          this.buildTaskList()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F8F8F8')

      // ---- 浮动按钮 ----
      Column() {
        // AI 拆解按钮
        Button() {
          Row() {
            Text('✨')
              .fontSize(16)
              .margin({ right: 4 })
            Text('AI 拆解')
              .fontSize(13)
              .fontColor('#FFFFFF')
          }
        }
        .height(40)
        .padding({ left: 12, right: 12 })
        .backgroundColor('#7C4DFF')
        .borderRadius(20)
        .onClick(() => {
          this.showAiDrawer = true;
        })

        // 添加任务按钮
        Button('＋')
          .width(56)
          .height(56)
          .fontSize(28)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Normal)
          .backgroundColor('#FF6347')
          .borderRadius(28)
          .margin({ top: 12 })
          .shadow({
            radius: 8,
            color: '#44000000',
            offsetX: 0,
            offsetY: 4,
          })
          .onClick(() => {
            this.addDialogController.open();
          })
      }
      .position({ right: 20, bottom: 32 })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .bindSheet($$this.showAiDrawer, this.aiDrawerBuilder, {
      height: SheetSize.LARGE,
      dragBar: false,
      backgroundColor: '#FFFFFF',
    })
  }

  /**
   * AI 拆解抽屉内容
   */
  @Builder
  aiDrawerBuilder() {
    AiDrawerContent({
      onClose: () => {
        this.showAiDrawer = false;
      },
      onTasksAdded: () => {
        this.refreshTaskList();
      },
    })
  }

  /**
   * 顶部标题栏
   */
  @Builder
  buildHeader() {
    Row() {
      Text('我的任务')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')

      Blank()

      Text('＋')
        .fontSize(28)
        .fontColor('#FF6347')
        .onClick(() => {
          this.addDialogController.open();
        })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 16, bottom: 8 })
    .backgroundColor('#FFFFFF')
  }

  /**
   * 统计行
   */
  @Builder
  buildStatsRow() {
    Row() {
      Text(`今日完成 ${this.todayDoneCount} 个`)
        .fontSize(13)
        .fontColor('#666666')

      Text(' / ')
        .fontSize(13)
        .fontColor('#CCCCCC')

      Text(`待完成 ${this.pendingCount} 个`)
        .fontSize(13)
        .fontColor(this.pendingCount > 0 ? '#FF6347' : '#666666')
        .fontWeight(this.pendingCount > 0 ? FontWeight.Bold : FontWeight.Normal)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 8, bottom: 12 })
    .backgroundColor('#FFFFFF')
  }

  /**
   * 任务列表
   */
  @Builder
  buildTaskList() {
    List({ space: 0 }) {
      ForEach(this.tasks, (task: Task) => {
        TaskCard({
          task: task,
          onToggle: () => {
            this.onToggle(task);
          },
          onDelete: () => {
            this.onDelete(task);
          },
          onEdit: () => {
            this.onEdit(task);
          },
        })
      }, (task: Task) => task.id.toString())
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ left: 16, right: 16, top: 12, bottom: 120 })
    .backgroundColor('#F8F8F8')
  }

  /**
   * 空状态
   */
  @Builder
  buildEmptyState() {
    Column() {
      Text('🍅')
        .fontSize(64)
        .margin({ bottom: 16 })

      Text('还没有任务，添加一个吧')
        .fontSize(16)
        .fontColor('#999999')
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  // ============================================================
  // 业务方法
  // ============================================================

  /**
   * 刷新任务列表（从 ViewModel 同步到 @State）
   */
  private async refreshTaskList(): Promise<void> {
    try {
      this.isLoading = true;
      await this.viewModel.loadTasks();
      this.syncFromViewModel();
    } catch (err) {
      promptAction.showToast({ message: `加载失败: ${JSON.stringify(err)}`, duration: 2000 });
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 将 ViewModel 的 @Trace 数据同步到组件 @State
   */
  private syncFromViewModel(): void {
    this.tasks = [...this.viewModel.tasks];
    this.pendingCount = this.viewModel.pendingCount;
    this.todayDoneCount = this.viewModel.todayDoneCount;
  }

  /**
   * 添加任务确认
   */
  private async onAddTaskConfirm(title: string, pomodoros: number, priority: number): Promise<void> {
    try {
      await this.viewModel.addTask(title, pomodoros, priority);
      this.syncFromViewModel();
      promptAction.showToast({ message: '任务已添加', duration: 1500 });
    } catch (err) {
      promptAction.showToast({ message: `添加失败: ${JSON.stringify(err)}`, duration: 2000 });
    }
  }

  /**
   * 切换完成状态
   */
  private async onToggle(task: Task): Promise<void> {
    try {
      await this.viewModel.toggleDone(task);
      this.syncFromViewModel();
    } catch (err) {
      promptAction.showToast({ message: `操作失败: ${JSON.stringify(err)}`, duration: 2000 });
    }
  }

  /**
   * 删除任务
   */
  private async onDelete(task: Task): Promise<void> {
    try {
      await this.viewModel.deleteTask(task);
      this.syncFromViewModel();
      promptAction.showToast({ message: '任务已删除', duration: 1500 });
    } catch (err) {
      promptAction.showToast({ message: `删除失败: ${JSON.stringify(err)}`, duration: 2000 });
    }
  }

  /**
   * 编辑任务（现阶段暂不实现，留待扩展）
   */
  private async onEdit(task: Task): Promise<void> {
    promptAction.showToast({ message: '编辑功能即将开放', duration: 1500 });
  }
}
