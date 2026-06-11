// ===== components/AiDrawer.ets =====
// AI 任务拆解底部抽屉
// 状态机：INPUT → LOADING_Q → QUESTIONS → LOADING_R → RESULT
// 使用 bindSheet 嵌入 TaskPage
// v2：每次拆解自动创建同名合集，同名时弹窗让用户改名

import { promptAction } from '@kit.ArkUI';
import { DeepSeekApi, SubTask, AiQuestion } from '../utils/DeepSeekApi';
import { TaskDao } from '../database/TaskDao';
import { CollectionDao } from '../database/CollectionDao';
import { AuthGuard } from '../utils/AuthGuard';
import { Priority, TaskType } from '../model/TaskModel';
import { PRESET_COLORS } from '../viewmodel/CollectionViewModel';

// ============================================================
// RenameCollectionDialog —— 合集重名时弹窗改名
// ============================================================

@CustomDialog
struct RenameCollectionDialog {
  controller: CustomDialogController;
  /** 已存在的合集名称 */
  existingName: string = '';
  /** 确认回调（返回新名称） */
  onConfirm?: (newName: string) => void;
  /** 取消回调 */
  onCancel?: () => void;

  @State inputName: string = '';

  aboutToAppear(): void {
    this.inputName = this.existingName;
  }

  build() {
    Column() {
      Text('合集名称已存在')
        .fontSize(20).fontWeight(FontWeight.Bold).fontColor('#333333')
        .margin({ top: 24, bottom: 8 }).width('100%').textAlign(TextAlign.Center)

      Text(`「${this.existingName}」已存在，请输入一个新名称`)
        .fontSize(14).fontColor('#999999')
        .margin({ bottom: 20 }).width('100%').textAlign(TextAlign.Center)

      TextInput({ placeholder: '请输入新合集名称', text: this.inputName })
        .width('100%').height(44).fontSize(15)
        .backgroundColor('#F5F5F5').borderRadius(8)
        .padding({ left: 12, right: 12 }).margin({ bottom: 24 })
        .onChange((value: string) => { this.inputName = value; })

      Row() {
        Button('取消')
          .layoutWeight(1).height(44).fontSize(16).fontColor('#666666')
          .backgroundColor('#F0F0F0').borderRadius(22)
          .onClick(() => {
            if (this.onCancel) { this.onCancel(); }
            this.controller.close();
          })
        Blank().width(16)
        Button('确认')
          .layoutWeight(1).height(44).fontSize(16).fontColor('#FFFFFF')
          .backgroundColor(this.inputName.trim().length > 0 ? '#7C4DFF' : '#CCCCCC')
          .borderRadius(22).enabled(this.inputName.trim().length > 0)
          .onClick(() => {
            const name = this.inputName.trim();
            if (name.length > 0 && this.onConfirm) {
              this.onConfirm(name);
            }
            this.controller.close();
          })
      }
      .width('100%').margin({ bottom: 24 })
    }
    .width('100%').padding({ left: 20, right: 20 })
    .backgroundColor('#FFFFFF').borderRadius({ topLeft: 16, topRight: 16 })
  }
}

/** 抽屉内部状态枚举 */
enum DrawerState {
  INPUT = 0,
  LOADING_Q = 1,
  QUESTIONS = 2,
  LOADING_R = 3,
  RESULT = 4,
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
  /** 从 AppStorage 读取实时合集ID（绕过 bindSheet 缓存导致的 @Prop 过时问题） */
  @StorageLink('aiSelectedCollectionId') selectedCollectionId: number = 0;

  // ═════════ 内部状态 ═════════

  /** 当前 UI 状态 */
  @State state: number = DrawerState.INPUT;
  /** 用户输入的大目标 */
  @State goalText: string = '';
  /** AI 生成的澄清问题列表 */
  @State questions: AiQuestion[] = [];
  /** 用户对问题的回答 {questionId: selectedOption} */
  @State userAnswers: Record<string, string> = {};
  /** 拆解出的子任务列表 */
  @State subtasks: SubTask[] = [];
  /** 加载/过程提示文字 */
  @State loadingText: string = '';
  /** 组件是否已挂载（防止卸载后回调操作状态） */
  private mounted: boolean = true;

  aboutToDisappear(): void {
    this.mounted = false;
  }

  build() {
    Column() {
      // 拖拽条
      this.dragBar()

      if (this.state === DrawerState.INPUT) {
        this.buildInput()
      } else if (this.state === DrawerState.LOADING_Q || this.state === DrawerState.LOADING_R) {
        this.buildLoading()
      } else if (this.state === DrawerState.QUESTIONS) {
        this.buildQuestions()
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
  // INPUT 状态 —— 输入目标描述
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

      Text('输入一个大目标，AI 会先问你几个问题，然后帮你拆解为可执行的子任务')
        .fontSize(13)
        .fontColor('#999999')
        .width('100%')
        .margin({ bottom: 12 })

      // 目标合集提示
      Row() {
        Text('📂 ')
          .fontSize(12)
          .fontColor('#999999')
        Text(this.goalText.trim().length > 0 ? `将自动创建「${this.goalText.trim()}」合集` : '将自动创建同名合集，任务归入其中')
          .fontSize(12)
          .fontColor('#7C4DFF')
          .fontWeight(FontWeight.Bold)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
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

      // 提示信息
      Text('💡 AI 将先了解你的需求，再生成带有优先级、类型、日期等完整信息的具体任务')
        .fontSize(12)
        .fontColor('#BBBBBB')
        .width('100%')
        .margin({ bottom: 12 })

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
  // LOADING 状态（问题生成 + 结果生成共用）
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
  // QUESTIONS 状态 —— 回答 AI 的澄清问题
  // ═══════════════════════════════════════════════

  @Builder
  buildQuestions() {
    Column() {
      // 标题行
      Row() {
        Text('补充信息')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')

        Text('请回答以下问题，以便更精准地拆解')
          .fontSize(13)
          .fontColor('#999999')
          .margin({ left: 8 })
      }
      .width('100%')
      .margin({ bottom: 16 })

      // 问题列表（可滚动）
      Scroll() {
        Column({ space: 16 }) {
          ForEach(this.questions, (q: AiQuestion, idx: number) => {
            this.buildQuestionItem(q, idx)
          }, (q: AiQuestion) => q.id)
        }
        .width('100%')
      }
      .scrollBar(BarState.Off)
      .layoutWeight(1)

      // 底部按钮组
      Row({ space: 12 }) {
        Button('返回修改目标')
          .layoutWeight(1)
          .height(46)
          .fontSize(15)
          .fontColor('#666666')
          .backgroundColor('#F0F0F0')
          .borderRadius(23)
          .onClick(() => {
            this.state = DrawerState.INPUT;
            this.questions = [];
            this.userAnswers = {};
          })

        Button('生成拆解')
          .layoutWeight(1)
          .height(46)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .backgroundColor(this.allQuestionsAnswered() ? '#7C4DFF' : '#CCCCCC')
          .borderRadius(23)
          .enabled(this.allQuestionsAnswered())
          .onClick(() => {
            this.onSubmitAnswers();
          })
      }
      .width('100%')
      .margin({ top: 16 })
    }
    .width('100%')
    .layoutWeight(1)
  }

  /**
   * 单条问题
   */
  @Builder
  buildQuestionItem(q: AiQuestion, idx: number) {
    Column() {
      Text(q.question)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor('#333333')
        .width('100%')
        .margin({ bottom: 10 })

      // 选项
      Column({ space: 8 }) {
        ForEach(q.options, (option: string) => {
          Row() {
            Row() {
              Radio({ value: option, group: `q_${q.id}` })
                .checked(this.userAnswers[q.id] === option)
                .onChange((isChecked: boolean) => {
                  if (isChecked) {
                    this.userAnswers[q.id] = option;
                  }
                })
              Text(option)
                .fontSize(14)
                .fontColor('#555555')
                .margin({ left: 8 })
            }
          }
          .width('100%')
          .padding({ top: 8, bottom: 8 })
        }, (option: string) => `${q.id}_${option}`)
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#FAFAFA')
    .borderRadius(10)
    .border({ width: 1, color: '#F0F0F0' })
  }

  // ═══════════════════════════════════════════════
  // RESULT 状态 —— 展示并编辑拆解结果
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

      // 合集名称预览
      Row() {
        Text('📂 将创建合集：')
          .fontSize(13)
          .fontColor('#999999')
        Text(`「${this.goalText.trim() || 'AI拆解任务'}」`)
          .fontSize(13)
          .fontColor('#7C4DFF')
          .fontWeight(FontWeight.Bold)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .flexShrink(1)
      }
      .width('100%')
      .margin({ bottom: 14 })

      // 子任务列表（可滚动）
      Scroll() {
        Column({ space: 10 }) {
          ForEach(this.subtasks, (st: SubTask, idx: number) => {
            this.buildSubtaskCard(st, idx)
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
            this.goalText = '';
            this.questions = [];
            this.userAnswers = {};
            this.subtasks = [];
          })

        Button('一键导入')
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
   * 单条子任务卡片（所有属性内联编辑）
   */
  @Builder
  buildSubtaskCard(st: SubTask, idx: number) {
    Column() {
      // ---- 标题行 + 删除 ----
      Row() {
        TextInput({ text: st.title })
          .layoutWeight(1)
          .fontSize(14)
          .backgroundColor('#F5F5F5')
          .borderRadius(6)
          .padding({ left: 10, right: 10 })
          .height(40)
          .onChange((value: string) => {
            this.updateSubtaskField(idx, 'title', value);
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
      .margin({ bottom: 10 })

      // ---- 优先级 ----
      Row() {
        Text('优先级')
          .fontSize(12)
          .fontColor('#999999')
          .width(50)
        Row({ space: 8 }) {
          Row() {
            Radio({ value: 'low', group: `priority_${idx}` })
              .checked(st.priority === Priority.LOW)
              .width(18).height(18)
              .onChange((isChecked: boolean) => {
                if (isChecked) { this.updateSubtaskField(idx, 'priority', Priority.LOW); }
              })
            Text('低').fontSize(11).fontColor('#9E9E9E').margin({ left: 2 })
          }
          Row() {
            Radio({ value: 'medium', group: `priority_${idx}` })
              .checked(st.priority === Priority.MEDIUM)
              .width(18).height(18)
              .onChange((isChecked: boolean) => {
                if (isChecked) { this.updateSubtaskField(idx, 'priority', Priority.MEDIUM); }
              })
            Text('中').fontSize(11).fontColor('#FF9800').margin({ left: 2 })
          }
          Row() {
            Radio({ value: 'high', group: `priority_${idx}` })
              .checked(st.priority === Priority.HIGH)
              .width(18).height(18)
              .onChange((isChecked: boolean) => {
                if (isChecked) { this.updateSubtaskField(idx, 'priority', Priority.HIGH); }
              })
            Text('高').fontSize(11).fontColor('#FF4444').margin({ left: 2 })
          }
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: 8 })

      // ---- 任务类型 ----
      Row() {
        Text('类型')
          .fontSize(12)
          .fontColor('#999999')
          .width(50)
        Row({ space: 8 }) {
          Row() {
            Radio({ value: 'milestone', group: `taskType_${idx}` })
              .checked(st.taskType === TaskType.MILESTONE)
              .width(18).height(18)
              .onChange((isChecked: boolean) => {
                if (isChecked) { this.updateSubtaskField(idx, 'taskType', TaskType.MILESTONE); }
              })
            Text('阶段性').fontSize(11).fontColor('#FF6347').margin({ left: 2 })
          }
          Row() {
            Radio({ value: 'habit', group: `taskType_${idx}` })
              .checked(st.taskType === TaskType.HABIT)
              .width(18).height(18)
              .onChange((isChecked: boolean) => {
                if (isChecked) { this.updateSubtaskField(idx, 'taskType', TaskType.HABIT); }
              })
            Text('习惯性').fontSize(11).fontColor('#2196F3').margin({ left: 2 })
          }
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: 8 })

      // ---- 日期（仅阶段性任务显示） ----
      if (st.taskType === TaskType.MILESTONE) {
        Column() {
          // 开始日期
          Row() {
            Text('开始')
              .fontSize(12)
              .fontColor('#999999')
              .width(50)
            Text(this.formatDate(st.startDate))
              .fontSize(11)
              .fontColor('#666666')
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .backgroundColor('#F5F5F5')
              .borderRadius(4)
              .onClick(() => {
                this.showDatePicker(idx, 'startDate', st.startDate);
              })
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .margin({ bottom: 4 })

          // 结束日期
          Row() {
            Text('结束')
              .fontSize(12)
              .fontColor('#999999')
              .width(50)
            Text(this.formatDate(st.endDate))
              .fontSize(11)
              .fontColor('#666666')
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .backgroundColor('#F5F5F5')
              .borderRadius(4)
              .onClick(() => {
                this.showDatePicker(idx, 'endDate', st.endDate);
              })
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
        }
        .width('100%')
        .margin({ bottom: 4 })
      }
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
   * 开始拆解 —— 阶段1：生成澄清问题
   */
  private async onStartDecompose(): Promise<void> {
    const goal = this.goalText.trim();
    if (goal.length === 0) {
      return;
    }

    this.state = DrawerState.LOADING_Q;
    this.loadingText = '正在分析你的目标...';

    try {
      const context = getContext(this);
      const questions: AiQuestion[] = await DeepSeekApi.generateQuestions(context, goal, (text: string) => {
        if (this.mounted) {
          this.loadingText = text;
        }
      });

      if (this.mounted) {
        this.questions = questions;
        this.userAnswers = {};
        this.state = DrawerState.QUESTIONS;
      }
    } catch (err) {
      if (!this.mounted) {
        return;
      }
      const msg = typeof err === 'object' && (err as Error).message
        ? (err as Error).message
        : '请求失败';
      promptAction.showToast({ message: msg, duration: 2000 });
      this.state = DrawerState.INPUT;
    }
  }

  /**
   * 提交答案 —— 阶段2：生成完整属性子任务
   */
  private async onSubmitAnswers(): Promise<void> {
    if (!this.allQuestionsAnswered()) {
      return;
    }

    this.state = DrawerState.LOADING_R;
    this.loadingText = '正在生成任务拆解...';

    try {
      const context = getContext(this);
      const result: SubTask[] = await DeepSeekApi.decomposeWithAnswers(
        context,
        this.goalText.trim(),
        this.questions,
        this.userAnswers,
        (text: string) => {
          if (this.mounted) {
            this.loadingText = text;
          }
        }
      );

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
      promptAction.showToast({ message: msg, duration: 2000 });
      this.state = DrawerState.QUESTIONS;
    }
  }

  /**
   * 批量导入子任务 —— v2：自动创建同名合集
   * 1. 使用目标文本作为合集名称
   * 2. 同名时弹窗让用户改名
   * 3. 创建合集后批量写入任务
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

      // ---- 1. 确定合集名称（来自目标输入） ----
      let collectionName: string = this.goalText.trim();
      if (collectionName.length === 0) {
        collectionName = 'AI拆解任务';
      }

      // ---- 2. 检查重名 ----
      const collectionDao = new CollectionDao();
      const isDuplicate: boolean = await collectionDao.isNameExists(userId, collectionName);
      if (isDuplicate) {
        // 弹窗让用户改名
        const newName: string | null = await this.showRenameDialog(collectionName);
        if (!newName) {
          // 用户取消
          return;
        }
        collectionName = newName;
      }

      // ---- 3. 选取合集颜色（按已有合集数量轮转） ----
      const existingCollections = await collectionDao.findAllByUser(userId);
      const colorIndex: number = existingCollections.length % PRESET_COLORS.length;
      const color: string = PRESET_COLORS[colorIndex];

      // ---- 4. 创建合集 ----
      const newCollectionId: number = await collectionDao.insert({
        userId: userId,
        name: collectionName,
        color: color,
        createdAt: Date.now(),
      });
      console.log(`[AiDrawer] 创建合集成功: id=${newCollectionId}, name="${collectionName}", color=${color}`);

      // ---- 5. 批量写入子任务 ----
      const dao = new TaskDao();
      for (const st of this.subtasks) {
        await dao.insert({
          userId: userId,
          title: st.title,
          done: false,
          priority: st.priority,
          createdAt: Date.now(),
          collectionId: newCollectionId,
          taskType: st.taskType,
          startDate: st.startDate,
          endDate: st.endDate,
        });
      }

      promptAction.showToast({
        message: `已创建合集「${collectionName}」并添加 ${this.subtasks.length} 个任务`,
        duration: 2000,
      });

      // ---- 6. 通知父页面刷新 + 关闭抽屉 ----
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
   * 弹出重命名对话框
   * @returns 新名称，取消则返回 null
   */
  private showRenameDialog(existingName: string): Promise<string | null> {
    return new Promise<string | null>((resolve) => {
      let resolved = false;
      const dialogController = new CustomDialogController({
        builder: RenameCollectionDialog({
          existingName: existingName,
          onConfirm: (newName: string) => {
            if (!resolved) {
              resolved = true;
              resolve(newName);
            }
          },
          onCancel: () => {
            if (!resolved) {
              resolved = true;
              resolve(null);
            }
          },
        }),
        autoCancel: true,
        alignment: DialogAlignment.Bottom,
        customStyle: true,
        cornerRadius: 16,
      });
      dialogController.open();
    });
  }

  /**
   * 更新子任务某个字段
   */
  private updateSubtaskField(index: number, field: string, value: number | string): void {
    const newList: SubTask[] = [];
    for (let i = 0; i < this.subtasks.length; i++) {
      if (i === index) {
        const updated: Record<string, number | string> = {};
        updated['title'] = this.subtasks[i].title;
        updated['priority'] = this.subtasks[i].priority;
        updated['taskType'] = this.subtasks[i].taskType;
        updated['startDate'] = this.subtasks[i].startDate;
        updated['endDate'] = this.subtasks[i].endDate;
        updated[field] = value;

        newList.push({
          title: updated['title'] as string,
          priority: updated['priority'] as number,
          taskType: updated['taskType'] as number,
          startDate: updated['startDate'] as number,
          endDate: updated['endDate'] as number,
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

  /**
   * 检查是否所有问题都已回答
   */
  private allQuestionsAnswered(): boolean {
    for (const q of this.questions) {
      if (!this.userAnswers[q.id] || this.userAnswers[q.id].length === 0) {
        return false;
      }
    }
    return this.questions.length > 0;
  }

  /**
   * 显示日期选择器
   */
  private showDatePicker(idx: number, field: string, currentTs: number): void {
    const defaultDate = currentTs > 0 ? new Date(currentTs) : new Date();
    DatePickerDialog.show({
      start: new Date('2020-1-1'),
      end: new Date('2030-12-31'),
      selected: defaultDate,
      lunar: false,
      onAccept: (value: DatePickerResult) => {
        const newDate = new Date(value.year, value.month, value.day);
        if (field === 'startDate') {
          newDate.setHours(0, 0, 0, 0);
          const newStartTs = newDate.getTime();
          // 记录更新前的 endDate，检查是否需要自动调整
          const oldEndTs = this.subtasks[idx].endDate;
          this.updateSubtaskField(idx, field, newStartTs);
          // 如果开始日期 > 原结束日期，自动延长结束日期（+7天）
          if (oldEndTs <= newStartTs) {
            const adjustedEnd = new Date(newStartTs + 7 * 24 * 60 * 60 * 1000);
            adjustedEnd.setHours(23, 59, 59, 999);
            this.updateSubtaskField(idx, 'endDate', adjustedEnd.getTime());
          }
        } else {
          newDate.setHours(23, 59, 59, 999);
          this.updateSubtaskField(idx, field, newDate.getTime());
        }
      },
    });
  }

  /**
   * 格式化日期时间戳为字符串
   */
  private formatDate(timestamp: number): string {
    if (timestamp <= 0) {
      return '请选择';
    }
    const d = new Date(timestamp);
    const y = d.getFullYear();
    const m = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${y}-${m}-${day}`;
  }
}
