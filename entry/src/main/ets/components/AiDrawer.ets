// ===== components/AiDrawer.ets =====
// AI 任务拆解底部抽屉 —— 状态机：INPUT → LOADING → RESULT → DONE
// 使用 bindSheet 嵌入 TaskPage

import { promptAction } from '@kit.ArkUI';
import { DeepSeekApi, SubTask } from '../utils/DeepSeekApi';
import { TaskDao } from '../database/TaskDao';
import { AuthGuard } from '../utils/AuthGuard';
import { Priority } from '../model/TaskModel';

/** 抽屉内部状态枚举 */
enum DrawerState {
  INPUT = 0,
  LOADING = 1,
  RESULT = 2,
}

/**
 * AiDrawerContent —— AI 拆解抽屉的内容组件
 *
 * 用法（在父页面中）：
 * ```
 * @State showAiDrawer: boolean = false;
 *
 * @Builder aiDrawerBuilder() {
 *   AiDrawerContent({
 *     onClose: () => { this.showAiDrawer = false; },
 *     onTasksAdded: () => { this.refreshTaskList(); },
 *     collectionId: this.selectedCollection ? this.selectedCollection.id : 0,
 *   })
 * }
 *
 * // 在 build() 中：
 * .bindSheet($$this.showAiDrawer, this.aiDrawerBuilder, {
 *   height: SheetSize.LARGE,
 *   dragBar: true,
 *   backgroundColor: '#FFFFFF',
 *   radius: 16,
 * })
 * ```
 */
@Component
export struct AiDrawerContent {
  /** 关闭抽屉回调 */
  onClose?: () => void;
  /** 任务已批量添加回调 */
  onTasksAdded?: () => void;
  /** 当前合集 ID（批量添加任务时自动关联） */
  @Prop collectionId: number = 0;

  // ═════════ 内部状态 ═════════

  /** 当前 UI 状态 */
  @State state: number = DrawerState.INPUT;
  /** 用户输入的大目标 */
  @State goalText: string = '';
  /** 拆解出的子任务列表 */
  @State subtasks: SubTask[] = [];
  /** 加载/过程提示文字 */
  @State loadingText: string = '';
  /** 是否已设置 API Key */
  @State hasApiKey: boolean = false;
  /** 组件是否已挂载（防止卸载后回调操作状态） */
  private mounted: boolean = true;

  async aboutToAppear(): Promise<void> {
    await this.checkApiKey();
  }

  aboutToDisappear(): void {
    this.mounted = false;
  }

  /**
   * 检查 API Key 是否已设置
   */
  private async checkApiKey(): Promise<void> {
    try {
      const key = await DeepSeekApi.getApiKey(getContext(this));
      this.hasApiKey = key.length > 0;
    } catch (err) {
      this.hasApiKey = false;
    }
  }

  build() {
    Column() {
      // 拖拽条
      this.dragBar()

      if (this.state === DrawerState.INPUT) {
        this.buildInput()
      } else if (this.state === DrawerState.LOADING) {
        this.buildLoading()
      } else {
        this.buildResult()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
    .padding({ left: 20, right: 20, bottom: 24 })
  }

  // ═══════════════════════════════════════════════
  // 拖拽指示条
  // ═══════════════════════════════════════════════

  @Builder
  dragBar() {
    Row() {
      Column()
        .width(36)
        .height(4)
        .backgroundColor('#DDDDDD')
        .borderRadius(2)
    }
    .width('100%')
    .height(20)
    .justifyContent(FlexAlign.Center)
  }

  // ═══════════════════════════════════════════════
  // INPUT 状态
  // ═══════════════════════════════════════════════

  @Builder
  buildInput() {
    Column() {
      // 标题
      Text('✨ AI 任务拆解')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')
        .width('100%')
        .margin({ bottom: 8 })

      Text('输入一个大目标，AI 帮你拆解为可执行的子任务')
        .fontSize(13)
        .fontColor('#999999')
        .width('100%')
        .margin({ bottom: 16 })

      // 输入框
      TextArea({ placeholder: '描述你想完成的事情，比如：准备述职报告', text: this.goalText })
        .width('100%')
        .height(120)
        .fontSize(15)
        .backgroundColor('#F5F5F5')
        .borderRadius(10)
        .padding(12)
        .margin({ bottom: 12 })
        .onChange((value: string) => {
          this.goalText = value;
        })

      // API Key 未设置警告
      if (!this.hasApiKey) {
        Row() {
          Text('⚠️')
            .fontSize(14)
            .margin({ right: 6 })
          Text('请先在设置中填写 DeepSeek API Key')
            .fontSize(13)
            .fontColor('#FF9800')
        }
        .width('100%')
        .padding(10)
        .backgroundColor('#FFF8E1')
        .borderRadius(8)
        .margin({ bottom: 12 })
      }

      // 开始拆解按钮
      Button('开始拆解')
        .width('100%')
        .height(48)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .backgroundColor(this.goalText.trim().length > 0 ? '#7C4DFF' : '#CCCCCC')
        .borderRadius(24)
        .enabled(this.goalText.trim().length > 0)
        .onClick(() => {
          this.onStartDecompose();
        })
    }
    .width('100%')
    .layoutWeight(1)
  }

  // ═══════════════════════════════════════════════
  // LOADING 状态
  // ═══════════════════════════════════════════════

  @Builder
  buildLoading() {
    Column() {
      LoadingProgress()
        .width(48)
        .height(48)
        .color('#7C4DFF')
        .margin({ bottom: 20 })

      Text(this.loadingText)
        .fontSize(16)
        .fontColor('#666666')
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  // ═══════════════════════════════════════════════
  // RESULT 状态
  // ═══════════════════════════════════════════════

  @Builder
  buildResult() {
    Column() {
      // 标题行
      Row() {
        Text('拆解结果')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')

        Text(`（${this.subtasks.length} 个子任务）`)
          .fontSize(14)
          .fontColor('#999999')
          .margin({ left: 4 })
      }
      .width('100%')
      .margin({ bottom: 12 })

      // 子任务列表（可滚动）
      Scroll() {
        Column({ space: 10 }) {
          ForEach(this.subtasks, (st: SubTask, idx: number) => {
            this.buildSubtaskItem(st, idx)
          }, (st: SubTask, idx: number) => `${idx}_${st.title}`)
        }
        .width('100%')
      }
      .scrollBar(BarState.Off)
      .layoutWeight(1)

      // 底部按钮组
      Row({ space: 12 }) {
        Button('重新拆解')
          .layoutWeight(1)
          .height(46)
          .fontSize(15)
          .fontColor('#666666')
          .backgroundColor('#F0F0F0')
          .borderRadius(23)
          .onClick(() => {
            this.state = DrawerState.INPUT;
          })

        Button('全部加入任务')
          .layoutWeight(1)
          .height(46)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .backgroundColor('#7C4DFF')
          .borderRadius(23)
          .onClick(() => {
            this.onBatchAdd();
          })
      }
      .width('100%')
      .margin({ top: 16 })
    }
    .width('100%')
    .layoutWeight(1)
  }

  /**
   * 单条子任务卡片
   */
  @Builder
  buildSubtaskItem(st: SubTask, idx: number) {
    Column() {
      // 标题 + 删除
      Row() {
        TextInput({ text: st.title })
          .layoutWeight(1)
          .fontSize(14)
          .backgroundColor('#F5F5F5')
          .borderRadius(6)
          .padding({ left: 10, right: 10 })
          .height(40)
          .onChange((value: string) => {
            this.updateSubtaskTitle(idx, value);
          })

        Text('✕')
          .fontSize(16)
          .fontColor('#CCCCCC')
          .padding({ left: 8, right: 4, top: 4, bottom: 4 })
          .onClick(() => {
            this.deleteSubtask(idx);
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // 番茄数 Stepper
      Row() {
        Text('番茄数')
          .fontSize(13)
          .fontColor('#999999')

        Blank()

        Row({ space: 8 }) {
          Text('−')
            .fontSize(18)
            .fontColor(st.estimatedPomodoros <= 1 ? '#CCCCCC' : '#7C4DFF')
            .width(30)
            .height(30)
            .textAlign(TextAlign.Center)
            .onClick(() => {
              if (st.estimatedPomodoros > 1) {
                this.updateSubtaskPomo(idx, st.estimatedPomodoros - 1);
              }
            })

          Text(st.estimatedPomodoros.toString())
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
            .width(24)
            .textAlign(TextAlign.Center)

          Text('+')
            .fontSize(18)
            .fontColor(st.estimatedPomodoros >= 4 ? '#CCCCCC' : '#7C4DFF')
            .width(30)
            .height(30)
            .textAlign(TextAlign.Center)
            .onClick(() => {
              if (st.estimatedPomodoros < 4) {
                this.updateSubtaskPomo(idx, st.estimatedPomodoros + 1);
              }
            })
        }
      }
      .width('100%')
      .margin({ top: 4 })
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#FAFAFA')
    .borderRadius(10)
    .border({ width: 1, color: '#F0F0F0' })
  }

  // ═══════════════════════════════════════════════
  // 业务方法
  // ═══════════════════════════════════════════════

  /**
   * 开始拆解
   */
  private async onStartDecompose(): Promise<void> {
    const goal = this.goalText.trim();
    if (goal.length === 0) {
      return;
    }

    this.state = DrawerState.LOADING;
    this.loadingText = '正在思考中...';

    try {
      const context = getContext(this);
      const result: SubTask[] = await DeepSeekApi.decompose(context, goal, (text: string) => {
        if (this.mounted) {
          this.loadingText = text;
        }
      });

      if (this.mounted) {
        this.subtasks = result;
        this.state = DrawerState.RESULT;
      }
    } catch (err) {
      if (!this.mounted) {
        return;
      }
      const msg = typeof err === 'object' && (err as Error).message
        ? (err as Error).message
        : '请求失败';

      if (msg === 'API_KEY_EMPTY') {
        this.hasApiKey = false;
        promptAction.showToast({ message: '请先在设置中填写 DeepSeek API Key', duration: 2000 });
      } else {
        promptAction.showToast({ message: msg, duration: 2000 });
      }
      this.state = DrawerState.INPUT;
    }
  }

  /**
   * 批量将子任务写入 tasks 表
   * 如果父页面传入了 collectionId，则自动关联到对应合集
   */
  private async onBatchAdd(): Promise<void> {
    if (this.subtasks.length === 0) {
      return;
    }

    try {
      const userId: number = AuthGuard.getCurrentUserId();
      if (userId <= 0) {
        promptAction.showToast({ message: '请先登录', duration: 1500 });
        return;
      }

      const dao = new TaskDao();
      for (const st of this.subtasks) {
        await dao.insert({
          userId: userId,
          title: st.title,
          estimatedPomodoros: st.estimatedPomodoros,
          done: false,
          priority: Priority.MEDIUM,
          createdAt: Date.now(),
          collectionId: this.collectionId,
        });
      }

      promptAction.showToast({ message: `已添加 ${this.subtasks.length} 个任务`, duration: 1500 });

      // 通知父页面刷新 + 关闭抽屉
      if (this.onTasksAdded) {
        this.onTasksAdded();
      }
      if (this.onClose) {
        this.onClose();
      }
    } catch (err) {
      promptAction.showToast({ message: `添加任务失败: ${JSON.stringify(err)}`, duration: 2000 });
    }
  }

  /**
   * 更新子任务标题
   */
  private updateSubtaskTitle(index: number, newTitle: string): void {
    const newList: SubTask[] = [];
    for (let i = 0; i < this.subtasks.length; i++) {
      if (i === index) {
        newList.push({
          title: newTitle,
          estimatedPomodoros: this.subtasks[i].estimatedPomodoros,
        });
      } else {
        newList.push(this.subtasks[i]);
      }
    }
    this.subtasks = newList;
  }

  /**
   * 更新子任务番茄数
   */
  private updateSubtaskPomo(index: number, newPomo: number): void {
    if (newPomo < 1 || newPomo > 4) {
      return;
    }
    const newList: SubTask[] = [];
    for (let i = 0; i < this.subtasks.length; i++) {
      if (i === index) {
        newList.push({
          title: this.subtasks[i].title,
          estimatedPomodoros: newPomo,
        });
      } else {
        newList.push(this.subtasks[i]);
      }
    }
    this.subtasks = newList;
  }

  /**
   * 删除子任务
   */
  private deleteSubtask(index: number): void {
    const newList: SubTask[] = [];
    for (let i = 0; i < this.subtasks.length; i++) {
      if (i !== index) {
        newList.push(this.subtasks[i]);
      }
    }
    this.subtasks = newList;
  }
}
