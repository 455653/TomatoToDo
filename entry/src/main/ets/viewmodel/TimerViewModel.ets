// ===== viewmodel/TimerViewModel.ets =====
// 番茄钟核心状态机 — @ObservedV2 — 正向计时 + 手动休息

import { emitter } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';
import { Task } from '../model/TaskModel';
import { Session } from '../model/SessionModel';
import { SessionDao, CreateSessionParams } from '../database/SessionDao';
import { AuthGuard } from '../utils/AuthGuard';

// ═══════════════════════════════════════════════
// 枚举 & 常量
// ═══════════════════════════════════════════════

/** 计时器状态枚举 */
export enum TimerState {
  IDLE = 'IDLE',
  FOCUSING = 'FOCUSING',
  PAUSED = 'PAUSED',
  RESTING = 'RESTING',
}

/** 手动休息时长（分钟） */
const REST_MINUTES = 5;

/** emitter 事件 ID */
const EVENT_CMD = 1001;
const EVENT_NOTIFY = 1002;
const EVENT_TICK = 1003;
const EVENT_TASK_CHANGED = 2001;

/** 发给 TimerService 的命令 */
interface TimerCmd {
  action: string;
  seconds?: number;
}

// ═══════════════════════════════════════════════
// TimerViewModel
// ═══════════════════════════════════════════════

@ObservedV2
export class TimerViewModel {
  /** 当前状态 */
  @Trace state: TimerState = TimerState.IDLE;
  /** 当前选中的任务 */
  @Trace selectedTask: Task | null = null;
  /** 今日专注次数 */
  @Trace todayFocusCount: number = 0;
  /** 今日专注总分钟数 */
  @Trace todayFocusMinutes: number = 0;
  /** 当前专注已走秒数（正向累加） */
  @Trace elapsedSeconds: number = 0;
  /** 休息剩余秒数（倒计时） */
  @Trace restRemainSeconds: number = 0;

  /** 暂停前的状态（用于恢复） */
  private previousState: TimerState = TimerState.IDLE;
  /** 专注开始时间戳（用于精确计算实际时长） */
  private focusStartTime: number = 0;
  /** 本次专注累计暂停毫秒 */
  private pauseAccumulator: number = 0;
  /** 暂停开始时间 */
  private pauseStartTime: number = 0;
  /** setInterval 句柄 */
  private timerId?: number;

  private sessionDao: SessionDao = new SessionDao();

  constructor() {
    this.listenForTimeUp();
  }

  // ═══════════════════════════════════════════════
  // 公开方法 — UI 调用
  // ═══════════════════════════════════════════════

  /**
   * 开始专注（正向计时从 0 开始）
   */
  start(): void {
    if (this.state !== TimerState.IDLE) {
      return;
    }
    this.state = TimerState.FOCUSING;
    this.elapsedSeconds = 0;
    this.focusStartTime = Date.now();
    this.pauseAccumulator = 0;
    this.sendCmd('start', 0);
    this.emitTick(this.elapsedSeconds, 'FOCUSING');
    this.startForwardTimer();
  }

  /**
   * 暂停专注
   */
  pause(): void {
    if (this.state !== TimerState.FOCUSING) {
      return;
    }
    this.previousState = this.state;
    this.state = TimerState.PAUSED;
    this.pauseStartTime = Date.now();
    this.clearTimer();
    this.emitTick(this.elapsedSeconds, 'PAUSED');
    this.sendCmd('pause');
  }

  /**
   * 恢复专注
   */
  resume(): void {
    if (this.state !== TimerState.PAUSED) {
      return;
    }
    this.pauseAccumulator += Date.now() - this.pauseStartTime;
    this.state = TimerState.FOCUSING;
    this.emitTick(this.elapsedSeconds, 'FOCUSING');
    this.startForwardTimer();
    this.sendCmd('resume');
  }

  /**
   * 停止专注（写入 session 并回到 IDLE）
   */
  async stop(): Promise<void> {
    if (this.state !== TimerState.FOCUSING && this.state !== TimerState.PAUSED) {
      return;
    }

    // 如果正在专注或从专注暂停，判断是否达到最低记录门槛
    if (this.state === TimerState.FOCUSING ||
      (this.state === TimerState.PAUSED && this.previousState === TimerState.FOCUSING)) {
      if (this.elapsedSeconds < 60) {
        promptAction.showToast({ message: '专注不足1分钟，未记录', duration: 1500 });
      } else {
        await this.writeSession(true);
        // 先从 DB 重新加载今日统计，确保数据一致
        await this.loadTodayStats();
        // 通过 emitter 通知 TodayPage 等组件刷新
        emitter.emit(
          { eventId: EVENT_TASK_CHANGED, priority: emitter.EventPriority.LOW },
          { data: {} }
        );
        // 同时通过 AppStorage 通知 StatPage 刷新（跨 Tab 缓存通信）
        const trigger = (AppStorage.get<number>('statRefreshTrigger') ?? 0) + 1;
        AppStorage.setOrCreate('statRefreshTrigger', trigger);
      }
    }

    this.state = TimerState.IDLE;
    this.clearTimer();
    this.elapsedSeconds = 0;
    this.sendCmd('stop');
    this.emitTick(-1, 'STOPPED');
  }

  /**
   * 开始手动休息（从 IDLE 进入 RESTING）
   */
  startRest(): void {
    if (this.state !== TimerState.IDLE) {
      return;
    }
    this.state = TimerState.RESTING;
    this.restRemainSeconds = REST_MINUTES * 60;
    this.sendCmd('start', this.restRemainSeconds);
    this.emitTick(this.restRemainSeconds, 'RESTING');
    this.startRestCountdown();
  }

  /**
   * 跳过休息（RESTING → IDLE）
   */
  skipRest(): void {
    if (this.state !== TimerState.RESTING) {
      return;
    }
    this.state = TimerState.IDLE;
    this.clearTimer();
    this.restRemainSeconds = 0;
    this.sendCmd('stop');
  }

  /**
   * 计算进度 (0.0 ~ 1.0)
   * - FOCUSING: 正向计时，用 1 小时（3600 秒）作为满环刻度
   * - RESTING: 倒计时，restRemainSeconds / (REST_MINUTES * 60) 的反比
   * - IDLE / PAUSED: 0
   */
  getProgress(seconds: number, st: TimerState): number {
    if (st === TimerState.IDLE || st === TimerState.PAUSED) {
      return 0;
    }
    if (st === TimerState.FOCUSING) {
      // 正向计时无终点，用 1 小时作为满环刻度（3600 秒 = 100%）
      return Math.min(1, seconds / 3600);
    }
    if (st === TimerState.RESTING) {
      const total = REST_MINUTES * 60;
      if (total <= 0) {
        return 0;
      }
      return 1 - (seconds / total);
    }
    return 0;
  }

  /**
   * 加载今日统计数据
   */
  async loadTodayStats(): Promise<void> {
    try {
      const userId = AuthGuard.getCurrentUserId();
      if (userId <= 0) {
        return;
      }
      const todayStart = this.getTodayStartMs();
      const sessions: Session[] = await this.sessionDao.findByUser(userId, todayStart);
      const completed = sessions.filter((s: Session) => s.completed === 1);
      this.todayFocusCount = completed.length;
      let totalSecs = 0;
      for (const s of completed) {
        totalSecs += s.durationSeconds;
      }
      this.todayFocusMinutes = Math.floor(totalSecs / 60);
    } catch (err) {
      console.error('[TimerViewModel] loadTodayStats error:', JSON.stringify(err));
    }
  }

  // ═══════════════════════════════════════════════
  // 内部 — 计时终止处理
  // ═══════════════════════════════════════════════

  /**
   * 监听 TimerService 的 timeUp 事件（仅休息倒计时归零时触发）
   */
  private listenForTimeUp(): void {
    emitter.on({ eventId: EVENT_NOTIFY }, (eventData: emitter.EventData) => {
      const cmd = eventData.data as TimerCmd;
      if (cmd && cmd.action === 'timeUp') {
        this.handleTimeUp();
      }
    });
  }

  /**
   * 时间到：专注无自动结束，仅处理休息结束
   */
  private handleTimeUp(): void {
    if (this.state === TimerState.RESTING) {
      this.state = TimerState.IDLE;
      this.clearTimer();
      this.restRemainSeconds = 0;
      this.sendCmd('stop');
      // 可选：发送通知"休息结束"，由 TimerService 的 notification 承担
    }
    // 专注不再有 timeUp（正向计时无自动结束）
  }

  /**
   * 正向走时（每秒 +1）
   */
  private startForwardTimer(): void {
    this.clearTimer();
    this.timerId = setInterval(() => {
      this.elapsedSeconds++;
      this.emitTick(this.elapsedSeconds, this.state);
    }, 1000);
  }

  /**
   * 休息倒计时（每秒 -1）
   */
  private startRestCountdown(): void {
    this.clearTimer();
    this.timerId = setInterval(() => {
      this.restRemainSeconds--;
      this.emitTick(this.restRemainSeconds, 'RESTING');
      if (this.restRemainSeconds <= 0) {
        this.clearTimer();
        this.handleTimeUp();
      }
    }, 1000);
  }

  /**
   * 写入专注 session
   */
  private async writeSession(completed: boolean): Promise<void> {
    try {
      const userId = AuthGuard.getCurrentUserId();
      const taskId = this.selectedTask ? this.selectedTask.id : 0;
      const endTime = Date.now();
      // 实际专注时长 = 总耗时 - 暂停耗时
      const actualDuration = Math.floor((endTime - this.focusStartTime - this.pauseAccumulator) / 1000);

      const params: CreateSessionParams = {
        userId: userId,
        taskId: taskId,
        startTime: this.focusStartTime,
        endTime: endTime,
        durationSeconds: actualDuration > 0 ? actualDuration : 0,
        interruptions: 0,  // 不再追踪中断次数
        completed: completed ? 1 : 0,
      };
      await this.sessionDao.insert(params);
    } catch (err) {
      console.error('[TimerViewModel] writeSession error:', JSON.stringify(err));
    }
  }

  // ═══════════════════════════════════════════════
  // 辅助
  // ═══════════════════════════════════════════════

  /**
   * 给 TimerService 发送命令
   */
  private sendCmd(action: string, seconds?: number): void {
    emitter.emit(
      { eventId: EVENT_CMD, priority: emitter.EventPriority.LOW },
      { data: { action: action, seconds: seconds } as TimerCmd }
    );
  }

  /**
   * 通过 emitter 广播 tick 事件（驱动 TimerPage UI 更新）
   */
  private emitTick(seconds: number, state: string): void {
    emitter.emit(
      { eventId: EVENT_TICK, priority: emitter.EventPriority.LOW },
      { data: { remainSeconds: seconds, timerState: state } }
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

  /**
   * 今日 00:00:00 的时间戳
   */
  private getTodayStartMs(): number {
    const now = new Date();
    now.setHours(0, 0, 0, 0);
    return now.getTime();
  }
}
