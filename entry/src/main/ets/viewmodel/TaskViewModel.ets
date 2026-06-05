// ===== viewmodel/TaskViewModel.ets =====
// 任务管理业务逻辑 —— @ObservedV2 响应式数据

import { Task, Priority } from '../model/TaskModel';
import { TaskDao } from '../database/TaskDao';
import { AuthGuard } from '../utils/AuthGuard';

/**
 * TaskViewModel —— @ObservedV2 + @Trace 实现响应式任务列表
 * 组件层通过 @State 拷贝数据触发 UI 刷新
 */
@ObservedV2
export class TaskViewModel {
  /** 当前用户的任务列表 */
  @Trace tasks: Task[] = [];

  private taskDao: TaskDao = new TaskDao();

  /**
   * 加载当前用户所有任务，按优先级降序、创建时间降序
   */
  async loadTasks(): Promise<void> {
    try {
      const userId: number = AuthGuard.getCurrentUserId();
      if (userId <= 0) {
        this.tasks = [];
        return;
      }
      this.tasks = await this.taskDao.findAllByUser(userId);
    } catch (err) {
      this.tasks = [];
      throw new Error(`加载任务失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 添加新任务
   */
  async addTask(title: string, pomodoros: number, priority: Priority): Promise<void> {
    try {
      const userId: number = AuthGuard.getCurrentUserId();
      if (userId <= 0) {
        throw new Error('用户未登录');
      }
      await this.taskDao.insert({
        userId: userId,
        title: title,
        estimatedPomodoros: pomodoros,
        done: false,
        priority: priority,
        createdAt: Date.now(),
      });
      await this.loadTasks();
    } catch (err) {
      throw new Error(`添加任务失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 切换任务完成状态
   */
  async toggleDone(task: Task): Promise<void> {
    try {
      const newDone: boolean = !task.done;
      await this.taskDao.markDone(task.id, newDone);
      await this.loadTasks();
    } catch (err) {
      throw new Error(`切换完成状态失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 删除任务
   */
  async deleteTask(task: Task): Promise<void> {
    try {
      await this.taskDao.deleteById(task.id);
      await this.loadTasks();
    } catch (err) {
      throw new Error(`删除任务失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 更新任务
   */
  async updateTask(task: Task): Promise<void> {
    try {
      await this.taskDao.update(task);
      await this.loadTasks();
    } catch (err) {
      throw new Error(`更新任务失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 未完成任务数
   */
  @Computed
  get pendingCount(): number {
    let count = 0;
    for (const t of this.tasks) {
      if (!t.done) {
        count++;
      }
    }
    return count;
  }

  /**
   * 今日完成数（已完成任务总数）
   */
  @Computed
  get todayDoneCount(): number {
    let count = 0;
    for (const t of this.tasks) {
      if (t.done) {
        count++;
      }
    }
    return count;
  }
}
