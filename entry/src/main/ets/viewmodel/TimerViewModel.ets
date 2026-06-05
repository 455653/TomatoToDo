// ===== viewmodel/TimerViewModel.ets =====
// 番茄钟核心状态机 — @ObservedV2

import { emitter } from '@kit.BasicServicesKit';
import { Task } from '../model/TaskModel';
import { SessionDao, CreateSessionParams } from '../database/SessionDao';
import { AuthGuard } from '../utils/AuthGuard';

// ═══════════════════════════════════════════════
// 枚举 & 常量
// ═══════════════════════════════════════════════

/** 计时器状态枚举 */
export enum TimerState {
  IDLE = 'IDLE',
  FOCUSING = 'FOCUSING',
  SHORT_BREAK = 'SHORT_BREAK',
  LONG_BREAK = 'LONG_BREAK',
  PAUSED = 'PAUSED',
}

/** 默认时长（分钟） */
const FOCUS_MINUTES = 25;
const SHORT_BREAK_MINUTES = 5;
const LONG_BREAK_MINUTES = 15;

/** emitter 事件 ID */
const EVENT_CMD = 1001;
const EVENT_NOTIFY = 1002;

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
  /** 当前番茄序号（从 1 起） */
  @Trace currentPomodoro: number = 1;
  /** 今日累计完成番茄数 */
  @Trace todayPomodoros: number = 0;
  /** 今日累计专注分钟数 */
  @Trace todayMinutes: number = 0;
  /** 本次专注的中断次数 */
  @Trace interruptions: number = 0;
  /** 当前选中的任务 */
  @Trace selectedTask: Task | null = null;

  /** 暂停前的状态（用于恢复） */
  private previousState: TimerState = TimerState.IDLE;
  /** 专注开始时间戳（用于精确计算实际时长） */
  private focusStartTime: number = 0;
  /** 累计暂停毫秒数 */
  private pauseAccumulator: number = 0;
  /** 暂停开始时间 */
  private pauseStartTime: number = 0;

  private sessionDao: SessionDao = new SessionDao();

  /** 专注时长（秒） */
  get focusDurationSeconds(): number {
    return FOCUS_MINUTES * 60;
  }
  /** 短休息时长（秒） */
  get shortBreakSeconds(): number {
    return SHORT_BREAK_MINUTES * 60;
  }
  /** 长休息时长（秒） */
  get longBreakSeconds(): number {
    return LONG_BREAK_MINUTES * 60;
  }

  constructor() {
    this.listenForTimeUp();
  }

  // ═══════════════════════════════════════════════
  // 公开方法 — UI 调用
  // ═══════════════════════════════════════════════

  /**
   * 开始专注
   */
  start(): void {
    if (this.state !== TimerState.IDLE) {
      return;
    }
    this.state = TimerState.FOCUSING;
    this.interruptions = 0;
    this.pauseAccumulator = 0;
    this.focusStartTime = Date.now();

    const secs = this.focusDurationSeconds;
    this.sendCmd('start', secs);
  }

  /**
   * 暂停
   */
  pause(): void {
    if (this.state === TimerState.IDLE || this.state === TimerState.PAUSED) {
      return;
    }
    this.previousState = this.state;
    this.state = TimerState.PAUSED;
    this.pauseStartTime = Date.now();

    if (this.previousState === TimerState.FOCUSING) {
      this.interruptions++;
    }
    this.sendCmd('pause');
  }

  /**
   * 恢复
   */
  resume(): void {
    if (this.state !== TimerState.PAUSED) {
      return;
    }
    if (this.previousState === TimerState.FOCUSING) {
      this.pauseAccumulator += Date.now() - this.pauseStartTime;
    }
    this.state = this.previousState;
    this.sendCmd('resume');
  }

  /**
   * 跳过当前阶段（休息中可用）
   */
  skip(): void {
    if (this.state !== TimerState.SHORT_BREAK && this.state !== TimerState.LONG_BREAK) {
      return;
    }
    this.state = TimerState.IDLE;
    this.sendCmd('stop');
  }

  /**
   * 放弃（任意状态 → IDLE）
   * 如果正在专注则写入不完整 session
   */
  stop(): void {
    if (this.state === TimerState.IDLE) {
      return;
    }
    // 正在专注或暂停专注 → 写不完整记录
    if (this.state === TimerState.FOCUSING ||
      (this.state === TimerState.PAUSED && this.previousState === TimerState.FOCUSING)) {
      this.writeSession(false);
    }
    this.state = TimerState.IDLE;
    this.sendCmd('stop');
  }

  /**
   * 计算进度 (0.0 ~ 1.0)，配合 TimerService 的 tick 使用
   */
  getProgress(tickSeconds: number, st: TimerState): number {
    const total = this.getTotalSeconds(st);
    if (total <= 0 || st === TimerState.IDLE || st === TimerState.PAUSED) {
      return 0;
    }
    if (tickSeconds >= total) {
      return 0;
    }
    return 1 - (tickSeconds / total);
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
      const sessions = await this.sessionDao.findByUser(userId, todayStart);
      // 仅统计完整完成的专注 session
      const completedSessions = sessions.filter((s) => s.completed === 1);
      this.todayPomodoros = completedSessions.length;
      let totalSecs = 0;
      for (const s of completedSessions) {
        totalSecs += s.durationSeconds;
      }
      this.todayMinutes = Math.floor(totalSecs / 60);
    } catch (err) {
      console.error('[TimerViewModel] loadTodayStats error:', JSON.stringify(err));
    }
  }

  /**
   * 获取指定状态对应的总秒数
   */
  getTotalSeconds(st: TimerState): number {
    if (st === TimerState.FOCUSING) {
      return this.focusDurationSeconds;
    } else if (st === TimerState.SHORT_BREAK) {
      return this.shortBreakSeconds;
    } else if (st === TimerState.LONG_BREAK) {
      return this.longBreakSeconds;
    }
    return 0;
  }

  // ═══════════════════════════════════════════════
  // 内部 — 计时终止处理
  // ═══════════════════════════════════════════════

  /**
   * 监听 TimerService 的 timeUp 事件
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
   * 时间到：写 session + 切换状态
   */
  private handleTimeUp(): void {
    try {
      if (this.state === TimerState.FOCUSING ||
        (this.state === TimerState.PAUSED && this.previousState === TimerState.FOCUSING)) {
        // 专注结束 → 写完成记录 → 进入休息
        this.writeSession(true);
        this.todayPomodoros++;
        this.todayMinutes += FOCUS_MINUTES;
        this.currentPomodoro++;

        // 每 4 个番茄 → 长休息
        if (this.currentPomodoro % 4 === 1) {
          // 刚完成的是第 N 个，N%4==0 → 长休息
          // currentPomodoro 已+1，检查 (currentPomodoro-1) % 4 === 0
        }
        if ((this.currentPomodoro - 1) % 4 === 0) {
          this.state = TimerState.LONG_BREAK;
          this.sendCmd('start', this.longBreakSeconds);
        } else {
          this.state = TimerState.SHORT_BREAK;
          this.sendCmd('start', this.shortBreakSeconds);
        }
      } else if (this.state === TimerState.SHORT_BREAK || this.state === TimerState.LONG_BREAK) {
        // 休息结束 → 归位 IDLE
        this.state = TimerState.IDLE;
      }
      // PAUSED 状态下不应触发 timeUp（服务已暂停）
    } catch (err) {
      console.error('[TimerViewModel] handleTimeUp error:', JSON.stringify(err));
    }
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
        durationSeconds: actualDuration > 0 ? actualDuration : this.focusDurationSeconds,
        interruptions: this.interruptions,
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
   * 今日 00:00:00 的时间戳
   */
  private getTodayStartMs(): number {
    const now = new Date();
    now.setHours(0, 0, 0, 0);
    return now.getTime();
  }
}
