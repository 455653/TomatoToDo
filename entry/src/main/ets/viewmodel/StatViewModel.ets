// ===== viewmodel/StatViewModel.ets =====
// 数据统计 ViewModel — @ObservedV2
// 一次性加载全部统计维度，UI 绑定 @Trace 字段自动刷新

import { SessionDao } from '../database/SessionDao';
import { TaskDao } from '../database/TaskDao';
import { Session } from '../model/SessionModel';
import { Task } from '../model/TaskModel';
import { AuthGuard } from '../utils/AuthGuard';

/** 24 小时毫秒数 */
const DAY_MS = 24 * 60 * 60 * 1000;

/** 每日番茄数据（供折线图使用） */
export interface DayData {
  /** 日期字符串 "MM-DD" */
  date: string;
  /** 该日完成番茄数 */
  count: number;
}

@ObservedV2
export class StatViewModel {
  // ═════════ 今日 ═════════
  @Trace todayPomodoros: number = 0;
  @Trace todayMinutes: number = 0;
  @Trace todayDoneTasks: number = 0;

  // ═════════ 本周 ═════════
  @Trace weekData: DayData[] = [];

  // ═════════ 本月热力图 ═════════
  @Trace monthHeatmap: Map<string, number> = new Map();

  // ═════════ 累计 ═════════
  @Trace totalPomodoros: number = 0;
  @Trace totalHours: number = 0;
  @Trace streakDays: number = 0;

  private sessionDao: SessionDao = new SessionDao();
  private taskDao: TaskDao = new TaskDao();

  /**
   * 一次性加载全部统计维度
   */
  async loadAll(): Promise<void> {
    const userId = AuthGuard.getCurrentUserId();
    if (userId <= 0) {
      return;
    }

    try {
      // 并行查询全部数据
      const results = await Promise.all([
        this.sessionDao.findByUser(userId),
        this.taskDao.findAllByUser(userId),
      ]);
      const allSessions: Session[] = results[0] as Session[];
      const allTasks: Task[] = results[1] as Task[];

      // 仅统计完整完成的 session
      const completed = this.filterCompleted(allSessions);

      // 各维度计算
      this.calcToday(completed, allTasks);
      this.weekData = this.calcWeekData(completed);
      this.monthHeatmap = this.calcMonthHeatmap(completed);
      this.calcTotal(completed);
      this.streakDays = this.calcStreak(completed);
    } catch (err) {
      console.error('[StatViewModel] loadAll error:', JSON.stringify(err));
    }
  }

  // ═══════════════════════════════════════════════
  // 今日统计
  // ═══════════════════════════════════════════════

  private calcToday(completed: Session[], allTasks: Task[]): void {
    const todayStart = this.getTodayStartMs();
    const todaySessions: Session[] = [];
    for (const s of completed) {
      if (s.startTime >= todayStart) {
        todaySessions.push(s);
      }
    }

    this.todayPomodoros = todaySessions.length;

    let totalSecs = 0;
    for (const s of todaySessions) {
      totalSecs += s.durationSeconds;
    }
    this.todayMinutes = Math.floor(totalSecs / 60);

    // 今日涉及的 distinct taskId
    const taskIdSet = new Set<number>();
    for (const s of todaySessions) {
      if (s.taskId > 0) {
        taskIdSet.add(s.taskId);
      }
    }
    this.todayDoneTasks = taskIdSet.size;
  }

  // ═══════════════════════════════════════════════
  // 本周统计（周一 ~ 周日）
  // ═══════════════════════════════════════════════

  private calcWeekData(completed: Session[]): DayData[] {
    const mondayMs = this.getMondayStartMs();

    const result: DayData[] = [];
    for (let i = 0; i < 7; i++) {
      const dayStart = mondayMs + i * DAY_MS;
      const dayEnd = dayStart + DAY_MS;
      let count = 0;
      for (const s of completed) {
        if (s.startTime >= dayStart && s.startTime < dayEnd) {
          count++;
        }
      }
      const d = new Date(dayStart);
      const month = d.getMonth() + 1;
      const dateNum = d.getDate();
      const dateStr = `${month.toString().padStart(2, '0')}-${dateNum.toString().padStart(2, '0')}`;
      result.push({ date: dateStr, count: count });
    }
    return result;
  }

  // ═══════════════════════════════════════════════
  // 热力图（全部日期 → Map<"YYYY-MM-DD", count>）
  // ═══════════════════════════════════════════════

  private calcMonthHeatmap(completed: Session[]): Map<string, number> {
    const map = new Map<string, number>();
    for (const s of completed) {
      const d = new Date(s.startTime);
      const key =
        `${d.getFullYear()}-` +
        `${(d.getMonth() + 1).toString().padStart(2, '0')}-` +
        `${d.getDate().toString().padStart(2, '0')}`;
      const prev = map.get(key) ?? 0;
      map.set(key, prev + 1);
    }
    return map;
  }

  // ═══════════════════════════════════════════════
  // 累计统计
  // ═══════════════════════════════════════════════

  private calcTotal(completed: Session[]): void {
    this.totalPomodoros = completed.length;

    let totalSecs = 0;
    for (const s of completed) {
      totalSecs += s.durationSeconds;
    }
    this.totalHours = Math.floor(totalSecs / 3600);
  }

  // ═══════════════════════════════════════════════
  // 最长连续专注天数
  // ═══════════════════════════════════════════════

  private calcStreak(completed: Session[]): number {
    if (completed.length === 0) {
      return 0;
    }

    // 归一到当天 0 点 → 去重 → 排序
    const daySet = new Set<number>();
    for (const s of completed) {
      const d = new Date(s.startTime);
      d.setHours(0, 0, 0, 0);
      daySet.add(d.getTime());
    }
    const days = Array.from(daySet).sort((a: number, b: number) => a - b);

    let maxStreak = 1;
    let cur = 1;
    for (let i = 1; i < days.length; i++) {
      if (days[i] - days[i - 1] === DAY_MS) {
        cur++;
        if (cur > maxStreak) {
          maxStreak = cur;
        }
      } else {
        cur = 1;
      }
    }
    return maxStreak;
  }

  // ═══════════════════════════════════════════════
  // 工具方法
  // ═══════════════════════════════════════════════

  /** 今日 00:00:00 毫秒时间戳 */
  private getTodayStartMs(): number {
    const now = new Date();
    now.setHours(0, 0, 0, 0);
    return now.getTime();
  }

  /** 本周一 00:00:00 毫秒时间戳 */
  private getMondayStartMs(): number {
    const now = new Date();
    const dayOfWeek = now.getDay(); // 0=Sun
    const offset = dayOfWeek === 0 ? 6 : dayOfWeek - 1;
    now.setDate(now.getDate() - offset);
    now.setHours(0, 0, 0, 0);
    return now.getTime();
  }

  /** 过滤已完成会话 */
  private filterCompleted(sessions: Session[]): Session[] {
    const result: Session[] = [];
    for (const s of sessions) {
      if (s.completed === 1) {
        result.push(s);
      }
    }
    return result;
  }
}
