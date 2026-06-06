// ===== database/TaskDao.ets =====
// 任务表数据访问对象

import { relationalStore } from '@kit.ArkData';
import { DbHelper } from './DbHelper';
import { Task } from '../model/TaskModel';

/**
 * 创建任务的参数（不含 id）
 */
export interface CreateTaskParams {
  userId: number;
  title: string;
  estimatedPomodoros: number;
  done: boolean;
  priority: number;
  createdAt: number;
  collectionId: number;
  taskType: number;      // 新增
  startDate: number;     // 新增
  endDate: number;       // 新增
}

/**
 * TaskDao —— 封装 tasks 表的增删改查
 */
export class TaskDao {

  /**
   * 插入一条任务记录
   * @returns 新插入记录的自增 ID
   */
  async insert(task: CreateTaskParams): Promise<number> {
    try {
      const store: relationalStore.RdbStore = await DbHelper.getInstance().getRdb();
      const valueBucket: relationalStore.ValuesBucket = {
        'user_id': task.userId,
        'title': task.title,
        'estimated_pomodoros': task.estimatedPomodoros,
        'done': task.done ? 1 : 0,
        'priority': task.priority,
        'created_at': task.createdAt,
        'collection_id': task.collectionId,
        'task_type': task.taskType,
        'start_date': task.startDate,
        'end_date': task.endDate,
      };
      const rowId: number = await store.insert('tasks', valueBucket);
      return rowId;
    } catch (err) {
      throw new Error(`任务插入失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 查询某用户的所有任务，按优先级降序、创建时间降序排列
   */
  async findAllByUser(userId: number): Promise<Task[]> {
    try {
      const store: relationalStore.RdbStore = await DbHelper.getInstance().getRdb();
      const sql = 'SELECT * FROM tasks WHERE user_id = ? ORDER BY priority DESC, created_at DESC';
      const resultSet: relationalStore.ResultSet = await store.querySql(sql, [userId.toString()]);

      const tasks: Task[] = [];
      while (resultSet.goToNextRow()) {
        tasks.push(this.rowToTask(resultSet));
      }
      resultSet.close();
      return tasks;
    } catch (err) {
      throw new Error(`任务查询失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 查询指定合集下的任务，按优先级降序、创建时间降序排列
   */
  async findByCollection(collectionId: number): Promise<Task[]> {
    try {
      const store: relationalStore.RdbStore = await DbHelper.getInstance().getRdb();
      const sql = 'SELECT * FROM tasks WHERE collection_id = ? ORDER BY priority DESC, created_at DESC';
      const resultSet: relationalStore.ResultSet = await store.querySql(sql, [collectionId.toString()]);

      const tasks: Task[] = [];
      while (resultSet.goToNextRow()) {
        tasks.push(this.rowToTask(resultSet));
      }
      resultSet.close();
      return tasks;
    } catch (err) {
      throw new Error(`按合集查询任务失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 查询未分类任务（collectionId === 0）
   */
  async findUncategorized(userId: number): Promise<Task[]> {
    try {
      const store: relationalStore.RdbStore = await DbHelper.getInstance().getRdb();
      const sql = 'SELECT * FROM tasks WHERE user_id = ? AND collection_id = 0 ORDER BY priority DESC, created_at DESC';
      const resultSet: relationalStore.ResultSet = await store.querySql(sql, [userId.toString()]);

      const tasks: Task[] = [];
      while (resultSet.goToNextRow()) {
        tasks.push(this.rowToTask(resultSet));
      }
      resultSet.close();
      return tasks;
    } catch (err) {
      throw new Error(`未分类任务查询失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 更新一条任务的全部字段（按 id 匹配）
   */
  async update(task: Task): Promise<void> {
    try {
      const store: relationalStore.RdbStore = await DbHelper.getInstance().getRdb();
      const valueBucket: relationalStore.ValuesBucket = {
        'title': task.title,
        'estimated_pomodoros': task.estimatedPomodoros,
        'done': task.done ? 1 : 0,
        'priority': task.priority,
        'created_at': task.createdAt,
        'collection_id': task.collectionId,
        'task_type': task.taskType,
        'start_date': task.startDate,
        'end_date': task.endDate,
      };
      const predicates = new relationalStore.RdbPredicates('tasks');
      predicates.equalTo('id', task.id);
      await store.update(valueBucket, predicates);
    } catch (err) {
      throw new Error(`任务更新失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 按 ID 删除任务
   */
  async deleteById(id: number): Promise<void> {
    try {
      const store: relationalStore.RdbStore = await DbHelper.getInstance().getRdb();
      const predicates = new relationalStore.RdbPredicates('tasks');
      predicates.equalTo('id', id);
      await store.delete(predicates);
    } catch (err) {
      throw new Error(`任务删除失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 更新任务的完成状态
   */
  async markDone(id: number, done: boolean): Promise<void> {
    try {
      const store: relationalStore.RdbStore = await DbHelper.getInstance().getRdb();
      const valueBucket: relationalStore.ValuesBucket = {
        'done': done ? 1 : 0,
      };
      const predicates = new relationalStore.RdbPredicates('tasks');
      predicates.equalTo('id', id);
      await store.update(valueBucket, predicates);
    } catch (err) {
      throw new Error(`任务状态更新失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 将 ResultSet 当前行转为 Task 对象（done INTEGER → boolean）
   */
  private rowToTask(rs: relationalStore.ResultSet): Task {
    return {
      id: rs.getLong(rs.getColumnIndex('id')),
      userId: rs.getLong(rs.getColumnIndex('user_id')),
      title: rs.getString(rs.getColumnIndex('title')),
      estimatedPomodoros: rs.getLong(rs.getColumnIndex('estimated_pomodoros')),
      done: rs.getLong(rs.getColumnIndex('done')) === 1,
      priority: rs.getLong(rs.getColumnIndex('priority')),
      createdAt: rs.getLong(rs.getColumnIndex('created_at')),
      collectionId: rs.getLong(rs.getColumnIndex('collection_id')),
      taskType: rs.getLong(rs.getColumnIndex('task_type')),
      startDate: rs.getLong(rs.getColumnIndex('start_date')),
      endDate: rs.getLong(rs.getColumnIndex('end_date')),
    };
  }

  /**
   * 查询指定日期范围内有效的阶段性任务
   * @param rangeStart 起始时间戳（毫秒）
   * @param rangeEnd 结束时间戳（毫秒）
   */
  async findActiveMilestoneTasks(userId: number, rangeStart: number, rangeEnd: number): Promise<Task[]> {
    try {
      const store = await DbHelper.getInstance().getRdb();
      const sql = `SELECT * FROM tasks WHERE user_id = ? AND task_type = 0
        AND start_date <= ? AND end_date >= ?
        ORDER BY priority DESC, created_at DESC`;
      const rs = await store.querySql(sql, [userId.toString(), rangeStart.toString(), rangeEnd.toString()]);
      const tasks: Task[] = [];
      while (rs.goToNextRow()) { tasks.push(this.rowToTask(rs)); }
      rs.close();
      return tasks;
    } catch (err) {
      throw new Error(`查询有效阶段性任务失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 查询已过期的阶段性任务（未完成的）
   * @param rangeStart 当前时间起点（毫秒）
   */
  async findOverdueMilestoneTasks(userId: number, rangeStart: number): Promise<Task[]> {
    try {
      const store = await DbHelper.getInstance().getRdb();
      const sql = `SELECT * FROM tasks WHERE user_id = ? AND task_type = 0
        AND end_date < ? AND done = 0
        ORDER BY end_date ASC, priority DESC`;
      const rs = await store.querySql(sql, [userId.toString(), rangeStart.toString()]);
      const tasks: Task[] = [];
      while (rs.goToNextRow()) { tasks.push(this.rowToTask(rs)); }
      rs.close();
      return tasks;
    } catch (err) {
      throw new Error(`查询过期阶段性任务失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 查询所有习惯性任务
   */
  async findHabitTasks(userId: number): Promise<Task[]> {
    try {
      const store = await DbHelper.getInstance().getRdb();
      const sql = `SELECT * FROM tasks WHERE user_id = ? AND task_type = 1
        ORDER BY priority DESC, created_at DESC`;
      const rs = await store.querySql(sql, [userId.toString()]);
      const tasks: Task[] = [];
      while (rs.goToNextRow()) { tasks.push(this.rowToTask(rs)); }
      rs.close();
      return tasks;
    } catch (err) {
      throw new Error(`查询习惯性任务失败: ${JSON.stringify(err)}`);
    }
  }
}
