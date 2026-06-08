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

/** 每日专注数据（供折线图使用） */
export interface DayData {
  /** 日期字符串 "MM-DD" */
  date: string;
  /** 该日专注总分钟数 */
  minutes: number;
}

@ObservedV2
export class StatViewModel {
  // ═════════ 今日 ═════════
  @Trace todayFocusCount: number = 0;
  @Trace todayMinutes: number = 0;
  @Trace todayDoneTasks: number = 0;
  @Trace todayQualityScore: number = 0;

  // ═════════ 本周 ═════════
  @Trace weekData: DayData[] = [];

  // ═════════ 本月热力图 ═════════
  @Trace monthHeatmap: Map<string, number> = new Map();

  // ═════════ 累计 ═════════
  @Trace totalFocusCount: number = 0;
  @Trace totalHours: number = 0;
  @Trace streakDays: number = 0;

  // ═════════ 本月累计 ═════════
  @Trace monthFocusCount: number = 0;
  @Trace monthHours: number = 0;
  @Trace monthStreakDays: number = 0;

  private sessionDao: SessionDao = new SessionDao();
  private taskDao: TaskDao = new TaskDao();

  /**
   * 一次性加载全部统计维度
   */
  async loadAll(): Promise<void> {
    const userId = AuthGuard.getCurrentUserId();
    console.log(`[StatViewModel] loadAll called, userId=${userId}`);
    if (userId <= 0) {
      console.log('[StatViewModel] userId invalid, skipping');
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

      console.log(`[StatViewModel] Loaded ${allSessions.length} sessions, ${allTasks.length} tasks`);

      // 仅统计完整完成的 session
      const completed = this.filterCompleted(allSessions);
      console.log(`[StatViewModel] ${completed.length} completed sessions`);

      // 各维度计算
      this.calcToday(completed);
      console.log(`[StatViewModel] Today: count=${this.todayFocusCount}, minutes=${this.todayMinutes}, tasks=${this.todayDoneTasks}`);

      this.weekData = this.calcWeekData(completed);
      this.monthHeatmap = this.calcMonthHeatmap(completed);
      console.log(`[StatViewModel] weekData=${this.weekData.length} days, monthHeatmap=${this.monthHeatmap.size} entries`);

      this.calcMonthStats(completed);
      console.log(`[StatViewModel] Month: count=${this.monthFocusCount}, hours=${this.monthHours}, streak=${this.monthStreakDays}`);

      this.calcTotal(completed);
      console.log(`[StatViewModel] Total: count=${this.totalFocusCount}, hours=${this.totalHours}`);

      this.streakDays = this.calcStreak(completed);
      console.log(`[StatViewModel] Max streak: ${this.streakDays}`);
    } catch (err) {
      console.error('[StatViewModel] loadAll error:', JSON.stringify(err));
    }
  }

  // ═══════════════════════════════════════════════
  // 今日统计
  // ═══════════════════════════════════════════════

  private calcToday(completed: Session[]): void {
    const todayStart = this.getTodayStartMs();
    console.log(`[StatViewModel] calcToday: todayStart=${todayStart} (${new Date(todayStart).toLocaleString()})`);

    const todaySessions: Session[] = [];
    for (const s of completed) {
      if (s.startTime >= todayStart) {
        todaySessions.push(s);
        console.log(`[StatViewModel] Today session: startTime=${s.startTime} (${new Date(s.startTime).toLocaleString()}), duration=${s.durationSeconds}s`);
      }
    }

    this.todayFocusCount = todaySessions.length;

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

    // 质量分计算
    if (this.todayFocusCount === 0) {
      this.todayQualityScore = 0;
    } else {
      let score = 50; // 基础分
      
      // 完成率加成：因当前仅存储有效专注，使用专注次数进行合理评估，每次加10分，最高30分
      let countBonus = Math.min(this.todayFocusCount * 10, 30);
      score += countBonus;
      
      // 时长加成：每 10 分钟加 5 分，最高 20 分
      let durationBonus = Math.min(Math.floor(this.todayMinutes / 10) * 5, 20);
      score += durationBonus;
      
      // 上限 100 分
      this.todayQualityScore = Math.min(score, 100);
    }

    console.log(`[StatViewModel] calcToday result: focusCount=${this.todayFocusCount}, totalSecs=${totalSecs}, minutes=${this.todayMinutes}, tasks=${this.todayDoneTasks}, qualityScore=${this.todayQualityScore}`);
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
      let totalSecs = 0;
      for (const s of completed) {
        if (s.startTime >= dayStart && s.startTime < dayEnd) {
          totalSecs += s.durationSeconds;
        }
      }
      const d = new Date(dayStart);
      const month = d.getMonth() + 1;
      const dateNum = d.getDate();
      const dateStr = `${month.toString().padStart(2, '0')}-${dateNum.toString().padStart(2, '0')}`;
      result.push({ date: dateStr, minutes: Math.floor(totalSecs / 60) });
    }
    return result;
  }

  // ═══════════════════════════════════════════════
  // 热力图（全部日期 → Map<"YYYY-MM-DD", minutes>）
  // ═══════════════════════════════════════════════

  private calcMonthHeatmap(completed: Session[]): Map<string, number> {
    const map = new Map<string, number>();
    const daySecondsMap = new Map<string, number>();
    
    for (const s of completed) {
      const d = new Date(s.startTime);
      const key =
        `${d.getFullYear()}-` +
        `${(d.getMonth() + 1).toString().padStart(2, '0')}-` +
        `${d.getDate().toString().padStart(2, '0')}`;
      const prev = daySecondsMap.get(key) ?? 0;
      daySecondsMap.set(key, prev + s.durationSeconds);
    }
    
    // 再统一计算分钟数
    const keys = Array.from(daySecondsMap.keys());
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      const totalSecs = daySecondsMap.get(key) as number;
      map.set(key, Math.floor(totalSecs / 60));
    }
    
    return map;
  }

  // ═══════════════════════════════════════════════
  // 累计统计
  // ═══════════════════════════════════════════════

  private calcMonthStats(completed: Session[]): void {
    const monthStart = this.getMonthStartMs();
    const monthSessions = completed.filter(s => s.startTime >= monthStart);

    this.monthFocusCount = monthSessions.length;

    let totalSecs = 0;
    for (const s of monthSessions) {
      totalSecs += s.durationSeconds;
    }
    this.monthHours = Math.floor(totalSecs / 3600);

    // 本月连续天数 = 从今天往前推，连续专注的天数（仅在本月范围内）
    this.monthStreakDays = this.calcCurrentStreak(monthSessions);
  }

  private calcTotal(completed: Session[]): void {
    this.totalFocusCount = completed.length;

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

  /**
   * 当前连续专注天数 —— 从今天往前推，每天都专注才算连续
   * 与 calcStreak（最长连续）不同，此方法计算的是"当前连续"
   */
  private calcCurrentStreak(completed: Session[]): number {
    if (completed.length === 0) {
      return 0;
    }

    // 归一到每天 0 点 → 去重
    const daySet = new Set<number>();
    for (const s of completed) {
      const d = new Date(s.startTime);
      d.setHours(0, 0, 0, 0);
      daySet.add(d.getTime());
    }

    const todayStart = this.getTodayStartMs();
    // 今天必须有专注，否则当前连续为 0
    if (!daySet.has(todayStart)) {
      return 0;
    }

    // 从今天往前数
    let streak = 0;
    let checkDay = todayStart;
    while (daySet.has(checkDay)) {
      streak++;
      checkDay -= DAY_MS;
    }

    return streak;
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

  /** 本月1日 00:00:00 毫秒时间戳 */
  private getMonthStartMs(): number {
    const now = new Date();
    now.setDate(1);
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
    console.log(`[StatViewModel] filterCompleted: ${sessions.length} total → ${result.length} completed`);
    return result;
  }
}
