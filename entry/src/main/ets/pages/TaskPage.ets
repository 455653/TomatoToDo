// ===== pages/TaskPage.ets =====
// 任务管理主页面 —— 两级导航：合集列表 → 合集内任务列表

import { promptAction } from '@kit.ArkUI';
import { Task, Priority } from '../model/TaskModel';
import { Collection } from '../model/CollectionModel';
import { TaskViewModel } from '../viewmodel/TaskViewModel';
import { CollectionViewModel, PRESET_COLORS } from '../viewmodel/CollectionViewModel';
import { TaskCard } from '../components/TaskCard';
import { AiDrawerContent } from '../components/AiDrawer';

// ============================================================
// AddTaskDialog —— 添加任务弹窗
// ============================================================

@CustomDialog
struct AddTaskDialog {
  /** 框架自动注入（用于 cancel 按钮关闭，不保证在 private 方法中可用） */
  controller: CustomDialogController;
  /** 确认回调 */
  confirmCallback?: AddTaskCallback;
  /** 弹窗标题（根据当前合集动态设置） */
  dialogTitle?: string = '添加任务';
  /** 当前合集 ID */
  collectionId?: number = 0;
  /** 关闭弹窗回调（闭包捕获 dialogController，避免 this 绑定问题） */
  onDialogClose?: () => void;

  /** 输入：任务名称 */
  @State inputTitle: string = '';
  /** 输入：番茄数 1-8 */
  @State pomodoroCount: number = 1;
  /** 输入：优先级 */
  @State selectedPriority: number = Priority.MEDIUM;

  aboutToAppear(): void {
    this.resetFields();
  }

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
      Text(this.dialogTitle)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')
        .margin({ top: 24, bottom: 20 })
        .width('100%')
        .textAlign(TextAlign.Center)

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

      Row() {
        Text('番茄数').fontSize(15).fontColor('#333333')
        Blank()
        Row() {
          Button('-')
            .width(36).height(36).fontSize(18).fontColor('#FFFFFF')
            .backgroundColor(this.pomodoroCount <= 1 ? '#CCCCCC' : '#FF6347')
            .borderRadius(4).enabled(this.pomodoroCount > 1)
            .onClick(() => { if (this.pomodoroCount > 1) { this.pomodoroCount--; } })
          Text(this.pomodoroCount.toString())
            .fontSize(18).fontWeight(FontWeight.Bold).fontColor('#333333')
            .width(40).textAlign(TextAlign.Center)
          Button('+')
            .width(36).height(36).fontSize(18).fontColor('#FFFFFF')
            .backgroundColor(this.pomodoroCount >= 8 ? '#CCCCCC' : '#FF6347')
            .borderRadius(4).enabled(this.pomodoroCount < 8)
            .onClick(() => { if (this.pomodoroCount < 8) { this.pomodoroCount++; } })
        }
      }
      .width('100%').margin({ bottom: 16 }).alignItems(VerticalAlign.Center)

      Row() {
        Text('优先级').fontSize(15).fontColor('#333333')
        Blank()
        Row({ space: 12 }) {
          Row() {
            Radio({ value: 'low', group: 'priorityRadio' })
              .checked(this.selectedPriority === Priority.LOW)
              .onChange((isChecked: boolean) => { if (isChecked) { this.selectedPriority = Priority.LOW; } })
            Text('低').fontSize(13).fontColor('#9E9E9E').margin({ left: 4 })
          }
          Row() {
            Radio({ value: 'medium', group: 'priorityRadio' })
              .checked(this.selectedPriority === Priority.MEDIUM)
              .onChange((isChecked: boolean) => { if (isChecked) { this.selectedPriority = Priority.MEDIUM; } })
            Text('中').fontSize(13).fontColor('#FF9800').margin({ left: 4 })
          }
          Row() {
            Radio({ value: 'high', group: 'priorityRadio' })
              .checked(this.selectedPriority === Priority.HIGH)
              .onChange((isChecked: boolean) => { if (isChecked) { this.selectedPriority = Priority.HIGH; } })
            Text('高').fontSize(13).fontColor('#FF4444').margin({ left: 4 })
          }
        }
      }
      .width('100%').margin({ bottom: 24 }).alignItems(VerticalAlign.Center)

      Row() {
        Button('取消')
          .layoutWeight(1).height(44).fontSize(16).fontColor('#666666')
          .backgroundColor('#F0F0F0').borderRadius(22)
          .onClick(() => { this.closeDialog(); })
        Blank().width(16)
        Button('确认添加')
          .layoutWeight(1).height(44).fontSize(16).fontColor('#FFFFFF')
          .backgroundColor('#FF6347').borderRadius(22)
          .onClick(() => { this.onConfirmClick(); })
      }
      .width('100%').margin({ bottom: 24 })
    }
    .width('100%').padding({ left: 20, right: 20 })
    .backgroundColor('#FFFFFF').borderRadius({ topLeft: 16, topRight: 16 })
  }

  /**
   * 安全关闭弹窗：优先使用闭包回调，回退到 controller
   */
  closeDialog(): void {
    if (this.onDialogClose) {
      this.onDialogClose();
    } else if (this.controller) {
      this.controller.close();
    }
  }

  /**
   * 「确认添加」按钮处理
   * 注意：此处不直接使用 this.controller.close()，因为 ArkTS 中
   * @CustomDialog 的 controller 在非 build() 方法中可能因 this 绑定问题而为 undefined。
   * 改用 onDialogClose 闭包回调安全关闭弹窗。
   */
  onConfirmClick(): void {
    const title = this.inputTitle.trim();
    if (title.length === 0) {
      promptAction.showToast({ message: '请输入任务名称', duration: 1500 });
      return;
    }
    if (this.confirmCallback) {
      this.confirmCallback(title, this.pomodoroCount, this.selectedPriority, this.collectionId ?? 0);
    }
    this.closeDialog();
  }
}

// ============================================================
// AddCollectionDialog —— 新建/编辑合集弹窗
// ============================================================

@CustomDialog
struct AddCollectionDialog {
  controller: CustomDialogController;
  /** 确认回调 */
  onConfirm?: (name: string, color: string) => void;
  /** 编辑模式：已有合集数据（undefined 表示新建） */
  editingCollection?: Collection;
  /** 重名检查回调 */
  onCheckDuplicate?: (name: string, excludeId?: number) => Promise<boolean>;

  @State inputName: string = '';
  @State selectedColor: string = PRESET_COLORS[0];

  aboutToAppear(): void {
    if (this.editingCollection) {
      this.inputName = this.editingCollection.name;
      this.selectedColor = this.editingCollection.color;
    } else {
      this.inputName = '';
      this.selectedColor = PRESET_COLORS[0];
    }
  }

  build() {
    Column() {
      Text(this.editingCollection ? '编辑合集' : '新建合集')
        .fontSize(20).fontWeight(FontWeight.Bold).fontColor('#333333')
        .margin({ top: 24, bottom: 20 }).width('100%').textAlign(TextAlign.Center)

      TextInput({ placeholder: '请输入合集名称', text: this.inputName })
        .width('100%').height(44).fontSize(15)
        .backgroundColor('#F5F5F5').borderRadius(8)
        .padding({ left: 12, right: 12 }).margin({ bottom: 20 })
        .onChange((value: string) => { this.inputName = value; })

      Text('选择颜色')
        .fontSize(14).fontColor('#666666').width('100%').margin({ bottom: 12 })

      Row({ space: 16 }) {
        ForEach(PRESET_COLORS, (color: string) => {
          Column()
            .width(40).height(40).borderRadius(20).backgroundColor(color)
            .border({ width: this.selectedColor === color ? 3 : 0, color: '#333333' })
            .onClick(() => { this.selectedColor = color; })
        })
      }
      .width('100%').justifyContent(FlexAlign.Center).margin({ bottom: 28 })

      Row() {
        Button('取消')
          .layoutWeight(1).height(44).fontSize(16).fontColor('#666666')
          .backgroundColor('#F0F0F0').borderRadius(22)
          .onClick(() => { this.controller.close(); })
        Blank().width(16)
        Button('确认')
          .layoutWeight(1).height(44).fontSize(16).fontColor('#FFFFFF')
          .backgroundColor(this.inputName.trim().length > 0 ? '#FF6347' : '#CCCCCC')
          .borderRadius(22).enabled(this.inputName.trim().length > 0)
          .onClick(() => { this.handleConfirm(); })
      }
      .width('100%').margin({ bottom: 24 })
    }
    .width('100%').padding({ left: 20, right: 20 })
    .backgroundColor('#FFFFFF').borderRadius({ topLeft: 16, topRight: 16 })
  }

  private async handleConfirm(): Promise<void> {
    const name = this.inputName.trim();
    if (name.length === 0) {
      promptAction.showToast({ message: '请输入合集名称', duration: 1500 });
      return;
    }
    if (this.onCheckDuplicate) {
      const excludeId = this.editingCollection ? this.editingCollection.id : undefined;
      const exists = await this.onCheckDuplicate(name, excludeId);
      if (exists) {
        promptAction.showToast({ message: '合集名称已存在，请换一个', duration: 2000 });
        return;
      }
    }
    if (this.onConfirm) {
      this.onConfirm(name, this.selectedColor);
    }
    this.controller.close();
  }
}

// ============================================================
// 回调类型别名
// ============================================================

type AddTaskCallback = (title: string, pomodoros: number, priority: number, collectionId: number) => void;

// ============================================================
// TaskPage —— 任务管理主页面
// ============================================================

@Entry
@Component
export struct TaskPage {
  private taskViewModel: TaskViewModel = new TaskViewModel();
  private collectionViewModel: CollectionViewModel = new CollectionViewModel();

  @State tasks: Task[] = [];
  @State collections: Collection[] = [];
  @State pendingCount: number = 0;
  @State todayDoneCount: number = 0;
  @State isLoading: boolean = false;
  @State showAiDrawer: boolean = false;

  /** 当前选中的合集（null = 合集列表视图） */
  @State selectedCollection: Collection | null = null;
  /** 正在编辑的合集（用于弹窗区分新建/编辑模式） */
  @State editingCollection: Collection | null = null;

  async aboutToAppear(): Promise<void> {
    await this.loadAllData();
  }

  build() {
    Stack() {
      Column() {
        if (this.selectedCollection === null) {
          this.buildCollectionListView()
        } else {
          this.buildCollectionDetailView()
        }
      }
      .width('100%').height('100%').backgroundColor('#F8F8F8')

      // 浮动按钮
      Column() {
        Button() {
          Row() {
            Text('✨').fontSize(16).margin({ right: 4 })
            Text('AI 拆解').fontSize(13).fontColor('#FFFFFF')
          }
        }
        .height(40).padding({ left: 12, right: 12 })
        .backgroundColor('#7C4DFF').borderRadius(20)
        .onClick(() => { this.showAiDrawer = true; })

        Button('＋')
          .width(56).height(56).fontSize(28)
          .fontColor('#FFFFFF').fontWeight(FontWeight.Normal)
          .backgroundColor('#FF6347').borderRadius(28)
          .margin({ top: 12 })
          .shadow({ radius: 8, color: '#44000000', offsetX: 0, offsetY: 4 })
          .onClick(() => {
            if (this.selectedCollection === null) {
              this.showCollectionDialog(null);
            } else {
              this.showAddTaskDialog();
            }
          })
      }
      .position({ right: 20, bottom: 32 }).alignItems(HorizontalAlign.Center)
    }
    .width('100%').height('100%')
    .bindSheet($$this.showAiDrawer, this.aiDrawerBuilder, {
      height: SheetSize.LARGE,
      dragBar: false,
      backgroundColor: '#FFFFFF',
    })
  }

  // ═══════════════════════════════════════════════
  // 合集列表视图
  // ═══════════════════════════════════════════════

  @Builder
  buildCollectionListView() {
    Column() {
      this.buildCollectionHeader()
      this.buildStatsRow()
      if (this.collections.length === 0 && !this.isLoading) {
        this.buildCollectionEmptyState()
      } else {
        this.buildCollectionGrid()
      }
    }
    .width('100%').height('100%').backgroundColor('#F8F8F8')
  }

  @Builder
  buildCollectionHeader() {
    Row() {
      Text('我的任务合集')
        .fontSize(22).fontWeight(FontWeight.Bold).fontColor('#333333')
      Blank()
      Text('＋').fontSize(28).fontColor('#FF6347')
        .onClick(() => { this.showCollectionDialog(null); })
    }
    .width('100%').padding({ left: 20, right: 20, top: 16, bottom: 8 })
    .backgroundColor('#FFFFFF')
  }

  @Builder
  buildCollectionGrid() {
    Scroll() {
      Grid() {
        ForEach(this.collections, (col: Collection) => {
          GridItem() {
            this.buildCollectionCard(col)
          }
        })
      }
      .columnsTemplate('1fr 1fr').columnsGap(12).rowsGap(12)
      .padding({ left: 16, right: 16, top: 12, bottom: 120 })
    }
    .scrollBar(BarState.Off).layoutWeight(1)
  }

  @Builder
  buildCollectionCard(col: Collection) {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column() {
        Column()
          .width('100%').height(6).backgroundColor(col.color)
          .borderRadius({ topLeft: 12, topRight: 12 })
        Column() {
          Text(col.name)
            .fontSize(17).fontWeight(FontWeight.Bold).fontColor('#333333')
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%').margin({ bottom: 6 })
          Text(`${this.getCollectionTaskCount(col.id)} 个任务`)
            .fontSize(12).fontColor('#999999').width('100%')
        }
        .width('100%').padding({ left: 14, right: 14, top: 12, bottom: 14 })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%').backgroundColor('#FFFFFF').borderRadius(12)
      .onClick(() => { this.enterCollection(col); })

      // 编辑按钮（右上角小图标，点击不触发进入合集）
      Text('✎')
        .fontSize(14).fontColor('#999999')
        .padding({ top: 10, right: 10 })
        .onClick(() => { this.showCollectionDialog(col); })
    }
    .width('100%')
    .gesture(
      LongPressGesture({ repeat: false, duration: 500 })
        .onAction(() => { this.confirmDeleteCollection(col); })
    )
  }

  @Builder
  buildCollectionEmptyState() {
    Column() {
      Text('📁').fontSize(64).margin({ bottom: 16 })
      Text('还没有合集，创建一个吧').fontSize(16).fontColor('#999999')
    }
    .width('100%').layoutWeight(1)
    .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
  }

  // ═══════════════════════════════════════════════
  // 合集详情视图
  // ═══════════════════════════════════════════════

  @Builder
  buildCollectionDetailView() {
    Column() {
      this.buildDetailHeader()
      this.buildDetailStatsRow()
      if (this.tasks.length === 0 && !this.isLoading) {
        this.buildDetailEmptyState()
      } else {
        this.buildTaskList()
      }
    }
    .width('100%').height('100%').backgroundColor('#F8F8F8')
  }

  @Builder
  buildDetailHeader() {
    Row() {
      Row() {
        Text('←')
          .fontSize(22).fontColor('#FF6347').fontWeight(FontWeight.Bold)
          .margin({ right: 10 })
          .onClick(() => { this.backToCollectionList(); })
        Text(this.selectedCollection!.name)
          .fontSize(20).fontWeight(FontWeight.Bold).fontColor('#333333')
      }
      Blank()
      Text('⚙')
        .fontSize(22).fontColor('#999999')
        .onClick(() => {
          if (this.selectedCollection) {
            this.showCollectionDialog(this.selectedCollection);
          }
        })
    }
    .width('100%').padding({ left: 20, right: 20, top: 16, bottom: 8 })
    .backgroundColor('#FFFFFF')
  }

  @Builder
  buildDetailStatsRow() {
    Row() {
      Text(`该合集完成 ${this.todayDoneCount} 个`).fontSize(13).fontColor('#666666')
      Text(' / ').fontSize(13).fontColor('#CCCCCC')
      Text(`待完成 ${this.pendingCount} 个`)
        .fontSize(13)
        .fontColor(this.pendingCount > 0 ? '#FF6347' : '#666666')
        .fontWeight(this.pendingCount > 0 ? FontWeight.Bold : FontWeight.Normal)
    }
    .width('100%').padding({ left: 20, right: 20, top: 8, bottom: 12 })
    .backgroundColor('#FFFFFF')
  }

  @Builder
  buildDetailEmptyState() {
    Column() {
      Text('🍅').fontSize(64).margin({ bottom: 16 })
      Text('该合集还没有任务，添加一个吧').fontSize(16).fontColor('#999999')
    }
    .width('100%').layoutWeight(1)
    .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
  }

  // ═══════════════════════════════════════════════
  // 共享组件
  // ═══════════════════════════════════════════════

  @Builder
  buildStatsRow() {
    Row() {
      Text(`今日完成 ${this.todayDoneCount} 个`).fontSize(13).fontColor('#666666')
      Text(' / ').fontSize(13).fontColor('#CCCCCC')
      Text(`待完成 ${this.pendingCount} 个`)
        .fontSize(13)
        .fontColor(this.pendingCount > 0 ? '#FF6347' : '#666666')
        .fontWeight(this.pendingCount > 0 ? FontWeight.Bold : FontWeight.Normal)
    }
    .width('100%').padding({ left: 20, right: 20, top: 8, bottom: 12 })
    .backgroundColor('#FFFFFF')
  }

  @Builder
  buildTaskList() {
    List({ space: 0 }) {
      ForEach(this.tasks, (task: Task) => {
        TaskCard({
          task: task,
          collectionName: this.getCollectionNameForTask(task),
          collectionColor: this.getCollectionColorForTask(task),
          onToggle: () => { this.onToggle(task); },
          onDelete: () => { this.onDelete(task); },
          onEdit: () => { this.onEdit(task); },
        })
      }, (task: Task) => task.id.toString())
    }
    .width('100%').layoutWeight(1)
    .padding({ left: 16, right: 16, top: 12, bottom: 120 })
    .backgroundColor('#F8F8F8')
  }

  @Builder
  aiDrawerBuilder() {
    AiDrawerContent({
      onClose: () => { this.showAiDrawer = false; },
      onTasksAdded: () => { this.refreshCurrentView(); },
      collectionId: this.selectedCollection ? this.selectedCollection.id : 0,
    })
  }

  // ═══════════════════════════════════════════════
  // 业务方法
  // ═══════════════════════════════════════════════

  private async loadAllData(): Promise<void> {
    try {
      this.isLoading = true;
      await this.collectionViewModel.loadCollections();
      await this.taskViewModel.loadTasks();
      this.syncFromViewModel();
      this.collections = [...this.collectionViewModel.collections];
    } catch (err) {
      promptAction.showToast({ message: `加载失败: ${JSON.stringify(err)}`, duration: 2000 });
    } finally {
      this.isLoading = false;
    }
  }

  private async enterCollection(col: Collection): Promise<void> {
    try {
      this.isLoading = true;
      this.selectedCollection = col;
      await this.taskViewModel.loadTasksByCollection(col.id);
      this.syncFromViewModel();
    } catch (err) {
      promptAction.showToast({ message: `加载失败: ${JSON.stringify(err)}`, duration: 2000 });
    } finally {
      this.isLoading = false;
    }
  }

  private async backToCollectionList(): Promise<void> {
    this.selectedCollection = null;
    await this.loadAllData();
  }

  private async refreshCurrentView(): Promise<void> {
    try {
      this.isLoading = true;
      if (this.selectedCollection === null) {
        await this.loadAllData();
      } else {
        await this.taskViewModel.loadTasksByCollection(this.selectedCollection.id);
        this.syncFromViewModel();
      }
    } catch (err) {
      promptAction.showToast({ message: `刷新失败: ${JSON.stringify(err)}`, duration: 2000 });
    } finally {
      this.isLoading = false;
    }
  }

  private syncFromViewModel(): void {
    this.tasks = [...this.taskViewModel.tasks];
    this.pendingCount = this.taskViewModel.pendingCount;
    this.todayDoneCount = this.taskViewModel.todayDoneCount;
  }

  /**
   * 显示合集弹窗（新建/编辑）
   * @param collection null=新建, Collection=编辑
   */
  private showCollectionDialog(collection: Collection | null): void {
    this.editingCollection = collection;
    const dialogController = new CustomDialogController({
      builder: AddCollectionDialog({
        onConfirm: (name: string, color: string) => {
          this.handleCollectionConfirm(name, color);
        },
        onCheckDuplicate: (name: string, excludeId?: number) => {
          return this.collectionViewModel.isNameDuplicate(name, excludeId);
        },
        editingCollection: collection ?? undefined,
      }),
      autoCancel: true,
      alignment: DialogAlignment.Bottom,
      customStyle: true,
      cornerRadius: 16,
    });
    dialogController.open();
  }

  /**
   * 合集弹窗确认处理
   */
  private async handleCollectionConfirm(name: string, color: string): Promise<void> {
    try {
      if (this.editingCollection) {
        // 编辑模式
        const updated: Collection = {
          id: this.editingCollection.id,
          userId: this.editingCollection.userId,
          name: name,
          color: color,
          createdAt: this.editingCollection.createdAt,
        };
        await this.collectionViewModel.updateCollection(updated);
        // 更新当前选中的合集信息
        if (this.selectedCollection && this.selectedCollection.id === updated.id) {
          this.selectedCollection = updated;
        }
        promptAction.showToast({ message: '合集已更新', duration: 1500 });
      } else {
        // 新建模式
        await this.collectionViewModel.addCollection(name, color);
        promptAction.showToast({ message: '合集已创建', duration: 1500 });
      }
      this.collections = [...this.collectionViewModel.collections];
      this.editingCollection = null;
    } catch (err) {
      promptAction.showToast({ message: `操作失败: ${JSON.stringify(err)}`, duration: 2000 });
    }
  }

  private confirmDeleteCollection(col: Collection): void {
    AlertDialog.show({
      title: '确认删除',
      message: `确定要删除合集「${col.name}」吗？\n合集内的任务将变为"未分类"，不会被删除。`,
      primaryButton: {
        value: '确认删除',
        fontColor: '#FF4444',
        action: async () => {
          try {
            await this.collectionViewModel.deleteCollection(col);
            this.collections = [...this.collectionViewModel.collections];
            promptAction.showToast({ message: '合集已删除', duration: 1500 });
            if (this.selectedCollection && this.selectedCollection.id === col.id) {
              this.selectedCollection = null;
              await this.taskViewModel.loadTasks();
              this.syncFromViewModel();
            }
          } catch (err) {
            promptAction.showToast({ message: `删除合集失败: ${JSON.stringify(err)}`, duration: 2000 });
          }
        },
      },
      secondaryButton: { value: '取消', action: () => {} },
    });
  }

  /**
   * 显示添加任务弹窗
   */
  private showAddTaskDialog(): void {
    const col = this.selectedCollection;
    const colName = col ? col.name : '';
    const colId = col ? col.id : 0;
    const dialogController = new CustomDialogController({
      builder: AddTaskDialog({
        confirmCallback: (title: string, pomodoros: number, priority: number, collectionId: number) => {
          dialogController.close();
          this.onAddTaskConfirm(title, pomodoros, priority, collectionId);
        },
        onDialogClose: () => {
          dialogController.close();
        },
        dialogTitle: colName ? `添加到「${colName}」` : '添加任务',
        collectionId: colId,
      }),
      autoCancel: true,
      alignment: DialogAlignment.Bottom,
      customStyle: true,
      cornerRadius: 16,
    });
    dialogController.open();
  }

  private async onAddTaskConfirm(title: string, pomodoros: number, priority: number, collectionId: number): Promise<void> {
    try {
      await this.taskViewModel.addTask(title, pomodoros, priority, collectionId);
      this.syncFromViewModel();
      promptAction.showToast({ message: '任务已添加', duration: 1500 });
    } catch (err) {
      promptAction.showToast({ message: `添加失败: ${JSON.stringify(err)}`, duration: 2000 });
    }
  }

  private async onToggle(task: Task): Promise<void> {
    try {
      await this.taskViewModel.toggleDone(task);
      this.syncFromViewModel();
    } catch (err) {
      promptAction.showToast({ message: `操作失败: ${JSON.stringify(err)}`, duration: 2000 });
    }
  }

  private async onDelete(task: Task): Promise<void> {
    try {
      await this.taskViewModel.deleteTask(task);
      this.syncFromViewModel();
      promptAction.showToast({ message: '任务已删除', duration: 1500 });
    } catch (err) {
      promptAction.showToast({ message: `删除失败: ${JSON.stringify(err)}`, duration: 2000 });
    }
  }

  private async onEdit(task: Task): Promise<void> {
    promptAction.showToast({ message: '编辑功能即将开放', duration: 1500 });
  }

  private getCollectionTaskCount(collectionId: number): number {
    let count = 0;
    for (const t of this.taskViewModel.tasks) {
      if (t.collectionId === collectionId) {
        count++;
      }
    }
    return count;
  }

  private getCollectionNameForTask(task: Task): string {
    if (task.collectionId <= 0) {
      return '';
    }
    for (const col of this.collections) {
      if (col.id === task.collectionId) {
        return col.name;
      }
    }
    return '';
  }

  private getCollectionColorForTask(task: Task): string {
    if (task.collectionId <= 0) {
      return '#999999';
    }
    for (const col of this.collections) {
      if (col.id === task.collectionId) {
        return col.color;
      }
    }
    return '#999999';
  }
}
