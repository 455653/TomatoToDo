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

  /** 当前选中的合集 ID，0 表示未分类，-1 表示全部 */
  @Trace currentCollectionId: number = -1;

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
      this.currentCollectionId = -1;
    } catch (err) {
      this.tasks = [];
      throw new Error(`加载任务失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 根据合集 ID 加载任务
   * @param collectionId 合集ID：0 = 未分类，-1 = 所有任务，>0 = 指定合集
   */
  async loadTasksByCollection(collectionId: number): Promise<void> {
    try {
      const userId: number = AuthGuard.getCurrentUserId();
      if (userId <= 0) {
        this.tasks = [];
        return;
      }
      if (collectionId === -1) {
        // 加载所有任务
        this.tasks = await this.taskDao.findAllByUser(userId);
      } else if (collectionId === 0) {
        // 加载未分类任务
        this.tasks = await this.taskDao.findUncategorized(userId);
      } else {
        // 加载指定合集下的任务
        this.tasks = await this.taskDao.findByCollection(collectionId);
      }
      this.currentCollectionId = collectionId;
    } catch (err) {
      this.tasks = [];
      throw new Error(`加载任务失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 添加新任务
   * @param collectionId 所属合集ID，0 表示未分类
   */
  async addTask(title: string, pomodoros: number, priority: Priority, collectionId: number = 0): Promise<void> {
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
        collectionId: collectionId,
      });
      // 保持当前合集筛选状态重新加载
      if (this.currentCollectionId === -1) {
        await this.loadTasks();
      } else {
        await this.loadTasksByCollection(this.currentCollectionId);
      }
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
      // 保持当前合集筛选状态重新加载
      if (this.currentCollectionId === -1) {
        await this.loadTasks();
      } else {
        await this.loadTasksByCollection(this.currentCollectionId);
      }
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
      // 保持当前合集筛选状态重新加载
      if (this.currentCollectionId === -1) {
        await this.loadTasks();
      } else {
        await this.loadTasksByCollection(this.currentCollectionId);
      }
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
      // 保持当前合集筛选状态重新加载
      if (this.currentCollectionId === -1) {
        await this.loadTasks();
      } else {
        await this.loadTasksByCollection(this.currentCollectionId);
      }
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
