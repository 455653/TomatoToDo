// ===== viewmodel/TodayViewModel.ets =====
// 今日待办业务逻辑 —— @ObservedV2

import { Task } from '../model/TaskModel';
import { TaskDao } from '../database/TaskDao';
import { DailyTaskLogDao } from '../database/DailyTaskLogDao';
import { AuthGuard } from '../utils/AuthGuard';

@ObservedV2
export class TodayViewModel {
  /** 有效期内的阶段性任务 */
  @Trace activeMilestoneTasks: Task[] = [];
  /** 已过期未完成的阶段性任务 */
  @Trace overdueMilestoneTasks: Task[] = [];
  /** 所有习惯性任务 */
  @Trace habitTasks: Task[] = [];
  /** 今日已打卡的习惯任务ID集合 */
  @Trace completedHabitIds: number[] = [];

  /** 今日待办总数 */
  @Trace totalTodayTasks: number = 0;
  /** 今日已完成数 */
  @Trace completedTodayCount: number = 0;

  private taskDao: TaskDao = new TaskDao();
  private dailyLogDao: DailyTaskLogDao = new DailyTaskLogDao();

  /**
   * 加载今日全部待办数据
   */
  async loadToday(): Promise<void> {
    try {
      const userId = AuthGuard.getCurrentUserId();
      if (userId <= 0) {
        this.activeMilestoneTasks = [];
        this.overdueMilestoneTasks = [];
        this.habitTasks = [];
        this.completedHabitIds = [];
        return;
      }

      const todayStart = this.getTodayStartMs();
      const todayEnd = this.getTodayEndMs();
      const todayStr = this.getTodayDateStr();

      // 并行加载
      const results = await Promise.all([
        this.taskDao.findActiveMilestoneTasks(userId, todayStart, todayEnd),
        this.taskDao.findOverdueMilestoneTasks(userId, todayStart),
        this.taskDao.findHabitTasks(userId),
        this.dailyLogDao.findCompletedTaskIdsByDate(userId, todayStr),
      ]);

      this.activeMilestoneTasks = results[0];
      this.overdueMilestoneTasks = results[1];
      this.habitTasks = results[2];
      this.completedHabitIds = results[3];

      // 计算统计
      this.totalTodayTasks =
        this.activeMilestoneTasks.length +
        this.overdueMilestoneTasks.length +
        this.habitTasks.length;

      const activeDone = this.activeMilestoneTasks.filter(t => t.done).length;
      const overdueDone = this.overdueMilestoneTasks.filter(t => t.done).length;
      this.completedTodayCount = activeDone + overdueDone + this.completedHabitIds.length;

    } catch (err) {
      throw new Error(`加载今日待办失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 切换阶段性任务的完成状态
   */
  async toggleMilestoneTask(task: Task): Promise<void> {
    try {
      await this.taskDao.markDone(task.id, !task.done);
      await this.loadToday();
    } catch (err) {
      throw new Error(`切换任务状态失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 切换习惯性任务的今日打卡状态
   */
  async toggleHabitTask(task: Task): Promise<void> {
    try {
      const userId = AuthGuard.getCurrentUserId();
      const todayStr = this.getTodayDateStr();

      const isCompleted = this.completedHabitIds.includes(task.id);

      if (isCompleted) {
        await this.dailyLogDao.deleteByTaskAndDate(task.id, todayStr);
      } else {
        await this.dailyLogDao.insert({
          taskId: task.id,
          userId: userId,
          logDate: todayStr,
          completedAt: Date.now(),
        });
      }

      await this.loadToday();
    } catch (err) {
      throw new Error(`打卡操作失败: ${JSON.stringify(err)}`);
    }
  }

  // ---- 计算属性 ----

  @Computed
  get activeCount(): number {
    return this.activeMilestoneTasks.length;
  }

  @Computed
  get overdueCount(): number {
    return this.overdueMilestoneTasks.length;
  }

  @Computed
  get habitCount(): number {
    return this.habitTasks.length;
  }

  /**
   * 判断指定习惯任务今日是否已打卡
   */
  isHabitCompletedToday(taskId: number): boolean {
    return this.completedHabitIds.includes(taskId);
  }

  // ---- 时间工具方法 ----

  /** 今日 00:00:00 毫秒时间戳 */
  getTodayStartMs(): number {
    const d = new Date();
    d.setHours(0, 0, 0, 0);
    return d.getTime();
  }

  /** 今日 23:59:59 毫秒时间戳 */
  getTodayEndMs(): number {
    const d = new Date();
    d.setHours(23, 59, 59, 999);
    return d.getTime();
  }

  /** 今日日期字符串 'YYYY-MM-DD' */
  getTodayDateStr(): string {
    const d = new Date();
    const y = d.getFullYear();
    const m = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${y}-${m}-${day}`;
  }
}
