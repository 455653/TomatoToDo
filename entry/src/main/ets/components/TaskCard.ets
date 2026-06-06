// ===== components/TaskCard.ets =====
// 任务卡片组件

import { Task, Priority } from '../model/TaskModel';

/** 回调类型：无参数无返回值 */
type VoidCallback = () => void;

/**
 * TaskCard —— 单条任务展示卡片
 * 支持左滑删除、点击切换完成、优先级色块、合集标识
 */
@Component
export struct TaskCard {
  /** 任务数据 */
  @Prop task: Task = {
    id: 0,
    userId: 0,
    title: '',
    done: false,
    priority: Priority.MEDIUM,
    createdAt: 0,
    collectionId: 0,
    taskType: 0,
    startDate: 0,
    endDate: 0,
  };

  /** 任务所属合集名称（可选，用于在卡片上显示合集标识） */
  @Prop collectionName: string = '';
  /** 任务所属合集颜色（可选，用于合集颜色小圆点） */
  @Prop collectionColor: string = '#999999';
  /** 该任务累积专注分钟数 */
  @Prop focusMinutes: number = 0;

  /** 切换完成状态回调 */
  onToggle?: VoidCallback;
  /** 删除回调 */
  onDelete?: VoidCallback;
  /** 编辑回调 */
  onEdit?: VoidCallback;

  build() {
    // 左滑删除
    ListItem() {
      Row() {
        // ---- 左侧：圆形勾选框 ----
        this.buildCheckbox()

        // ---- 中间：标题 + 副标题 ----
        this.buildContent()

        // ---- 右侧：优先级色块 + 删除按钮 ----
        this.buildActions()
      }
      .width('100%')
      .padding({ top: 12, bottom: 12, left: 16, right: 8 })
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
      .alignItems(VerticalAlign.Center)
    }
    .swipeAction({
      end: this.buildSwipeDelete
    })
    .margin({ bottom: 8 })
  }

  /**
   * 左侧圆形勾选框
   */
  @Builder
  buildCheckbox() {
    Column() {
      if (this.task.done) {
        // 已完成：绿色实心圆 + 勾
        Text('✓')
          .fontSize(16)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Bold)
      }
    }
    .width(28)
    .height(28)
    .borderRadius(14)
    .backgroundColor(this.task.done ? '#4CAF50' : '#E0E0E0')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.onToggle?.();
    })
    .margin({ right: 12 })
  }

  /**
   * 中间内容区
   */
  @Builder
  buildContent() {
    Column() {
      // 任务标题
      Text(this.task.title)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.task.done ? '#999999' : '#333333')
        .decoration({
          type: this.task.done ? TextDecorationType.LineThrough : TextDecorationType.None,
        })
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      // 副标题行：专注时长 + 合集标识
      Row() {
        if (this.focusMinutes > 0) {
          Text(`已专注 ${this.focusMinutes} 分钟`)
            .fontSize(12)
            .fontColor('#999999')
        }

        // 合集标识
        if (this.collectionName.length > 0 && this.task.collectionId > 0) {
          if (this.focusMinutes > 0) {
            Text(' · ')
              .fontSize(12)
              .fontColor('#CCCCCC')
          }
          Text('●')
            .fontSize(8)
            .fontColor(this.collectionColor)
            .margin({ right: 3 })
          Text(this.collectionName)
            .fontSize(11)
            .fontColor('#999999')
            .maxLines(1)
        }
      }
      .width('100%')
      .margin({ top: 4 })
      .alignItems(VerticalAlign.Center)
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
  }

  /**
   * 右侧操作区
   */
  @Builder
  buildActions() {
    Row() {
      // 优先级色块
      Text(this.getPriorityLabel(this.task.priority))
        .fontSize(11)
        .fontColor('#FFFFFF')
        .fontWeight(FontWeight.Bold)
        .textAlign(TextAlign.Center)
        .width(28)
        .height(28)
        .borderRadius(4)
        .backgroundColor(this.getPriorityColor(this.task.priority))

      // 编辑按钮
      Text('✎')
        .fontSize(18)
        .fontColor('#999999')
        .margin({ left: 10 })
        .onClick(() => {
          this.onEdit?.();
        })

      // 删除按钮（长按触发）
      Text('🗑')
        .fontSize(20)
        .margin({ left: 10 })
        .onClick(() => {
          this.onDelete?.();
        })
        .gesture(
          LongPressGesture({ repeat: false, duration: 500 })
            .onAction(() => {
              this.onDelete?.();
            })
        )
    }
    .alignItems(VerticalAlign.Center)
  }

  /**
   * 左滑露出的删除按钮
   */
  @Builder
  buildSwipeDelete() {
    Row() {
      Text('删除')
        .fontSize(14)
        .fontColor('#FFFFFF')
        .fontWeight(FontWeight.Bold)
        .width(72)
        .height('100%')
        .textAlign(TextAlign.Center)
        .backgroundColor('#FF4444')
        .onClick(() => {
          this.onDelete?.();
        })
    }
  }

  /**
   * 获取优先级对应的颜色
   */
  private getPriorityColor(priority: number): string {
    if (priority === Priority.HIGH) {
      return '#FF4444';
    } else if (priority === Priority.MEDIUM) {
      return '#FF9800';
    }
    return '#9E9E9E';
  }

  /**
   * 获取优先级对应的短标签
   */
  private getPriorityLabel(priority: number): string {
    if (priority === Priority.HIGH) {
      return '高';
    } else if (priority === Priority.MEDIUM) {
      return '中';
    }
    return '低';
  }


}
