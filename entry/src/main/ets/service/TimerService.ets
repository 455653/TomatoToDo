// ===== service/TimerService.ets =====
// 番茄钟后台计时服务 —— ServiceExtensionAbility
//
// ════════════════════════════════════════════════════════════
// 【module.json5 配置说明】
// 在 entry/src/main/module.json5 的 extensionAbilities 数组中加入：
//
// {
//   "name": "TimerService",
//   "srcEntry": "./ets/service/TimerService.ets",
//   "type": "service",
//   "exported": false
// }
//
// 并在 module.json5 顶层加 requestPermissions：
// "requestPermissions": [
//   { "name": "ohos.permission.KEEP_BACKGROUND_RUNNING" }
// ]
// ════════════════════════════════════════════════════════════

import { AppServiceExtensionAbility, Want } from '@kit.AbilityKit';
import { notificationManager } from '@kit.NotificationKit';
import { emitter } from '@kit.BasicServicesKit';

/** 通知 ID 常量 */
const NOTIFICATION_ID = 9527;
const NOTIFICATION_CHANNEL_ID = 'timer_channel';
const NOTIFICATION_SLOT_TYPE: notificationManager.SlotType = notificationManager.SlotType.SERVICE_INFORMATION;

/** emitter 事件 ID */
const EVENT_CMD = 1001;
const EVENT_NOTIFY = 1002;
const EVENT_TICK = 1003;

/** 从 UI 发来的命令 */
interface TimerCmd {
  action: string;
  seconds?: number;
}

/** tick 事件携带的数据 */
interface TickEvent {
  remainSeconds: number;
  timerState: string;
}

/**
 * TimerService —— 后台倒计时服务
 * - 接收 UI 命令通过 emitter
 * - 每秒通过 emitter 广播 tick 事件
 * - 前台常驻通知保持存活
 * - 计时终止时通过 emitter 通知 UI
 */
export default class TimerService extends AppServiceExtensionAbility {
  /** setInterval 句柄 */
  private timerId?: number;
  /** 剩余秒数 */
  private remainSeconds: number = 0;

  /**
   * 服务创建：注册通知频道、监听 emitter 命令
   */
  onCreate(want: Want): void {
    console.info('[TimerService] onCreate');
    this.initNotificationSlot();

    // 监听 UI 发来的计时命令
    emitter.on({ eventId: EVENT_CMD }, (eventData: emitter.EventData) => {
      const cmd = eventData.data as TimerCmd;
      if (!cmd) {
        return;
      }
      switch (cmd.action) {
        case 'start': {
          const secs = cmd.seconds ?? 0;
          this.startTimer(secs);
          break;
        }
        case 'pause':
          this.pauseTimer();
          break;
        case 'resume':
          this.resumeTimer();
          break;
        case 'stop':
          this.stopTimer();
          break;
      }
    });
  }

  /**
   * 启动倒计时
   */
  startTimer(seconds: number): void {
    if (seconds <= 0) {
      return;
    }
    // 清除旧定时器
    this.clearTimer();
    this.remainSeconds = seconds;

    // 发送前台通知
    this.showNotification('专注中...', '番茄钟倒计时进行中');

    // 通过 emitter 广播初始 tick
    this.emitTick(this.remainSeconds, 'FOCUSING');

    // 每秒 tick
    this.timerId = setInterval(() => {
      this.remainSeconds--;
      this.emitTick(this.remainSeconds, 'FOCUSING');

      if (this.remainSeconds <= 0) {
        this.onTimerEnd();
      }
    }, 1000);
  }

  /**
   * 暂停计时
   */
  pauseTimer(): void {
    this.clearTimer();
    this.emitTick(this.remainSeconds, 'PAUSED');
    this.showNotification('已暂停', '番茄钟已暂停');
  }

  /**
   * 恢复计时
   */
  resumeTimer(): void {
    if (this.remainSeconds <= 0) {
      return;
    }
    this.emitTick(this.remainSeconds, 'FOCUSING');
    this.showNotification('专注中...', '番茄钟倒计时进行中');

    this.timerId = setInterval(() => {
      this.remainSeconds--;
      this.emitTick(this.remainSeconds, 'FOCUSING');

      if (this.remainSeconds <= 0) {
        this.onTimerEnd();
      }
    }, 1000);
  }

  /**
   * 停止计时（废弃当前 session）
   */
  stopTimer(): void {
    this.clearTimer();
    this.remainSeconds = 0;
    this.emitTick(-1, 'STOPPED');
    this.cancelNotification();
  }

  /**
   * 倒计时归零：通知 UI 处理 session 写入
   */
  private onTimerEnd(): void {
    this.clearTimer();
    // 通过 emitter 通知 ViewModel 计时结束
    emitter.emit(
      { eventId: EVENT_NOTIFY, priority: emitter.EventPriority.IMMEDIATE },
      { data: { action: 'timeUp' } as TimerCmd }
    );
    this.emitTick(0, 'FINISHED');
    this.cancelNotification();
  }

  /**
   * 通过 emitter 广播 tick 事件
   */
  private emitTick(remainSeconds: number, timerState: string): void {
    const tickData: TickEvent = { remainSeconds: remainSeconds, timerState: timerState };
    emitter.emit(
      { eventId: EVENT_TICK, priority: emitter.EventPriority.LOW },
      { data: tickData }
    );
  }

  /**
   * 清除定时器
   */
  private clearTimer(): void {
    if (this.timerId !== undefined) {
      clearInterval(this.timerId);
      this.timerId = undefined;
    }
  }

  // ═══════════════════════════════════════════════
  // 通知相关
  // ═══════════════════════════════════════════════

  /**
   * 初始化通知频道
   */
  private initNotificationSlot(): void {
    try {
      notificationManager.addSlot(NOTIFICATION_SLOT_TYPE, (err) => {
        if (err) {
          console.error('[TimerService] addSlot error:', JSON.stringify(err));
        }
      });
    } catch (err) {
      console.error('[TimerService] initNotificationSlot error:', JSON.stringify(err));
    }
  }

  /**
   * 发送前台常驻通知
   */
  private showNotification(title: string, text: string): void {
    try {
      const request: notificationManager.NotificationRequest = {
        id: NOTIFICATION_ID,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: title,
            text: text,
          },
        },
        notificationSlotType: NOTIFICATION_SLOT_TYPE,
        deliveryTime: Date.now(),
        showDeliveryTime: true,
        isOngoing: true,
      };
      notificationManager.publish(request, (err) => {
        if (err) {
          console.error('[TimerService] publish error:', JSON.stringify(err));
        }
      });
    } catch (err) {
      console.error('[TimerService] showNotification error:', JSON.stringify(err));
    }
  }

  /**
   * 取消通知
   */
  private cancelNotification(): void {
    try {
      notificationManager.cancel(NOTIFICATION_ID, (err) => {
        if (err) {
          console.error('[TimerService] cancel error:', JSON.stringify(err));
        }
      });
    } catch (err) {
      console.error('[TimerService] cancelNotification error:', JSON.stringify(err));
    }
  }

  /**
   * 服务销毁
   */
  onDestroy(): void {
    this.clearTimer();
    this.cancelNotification();
    console.info('[TimerService] onDestroy');
  }
}
