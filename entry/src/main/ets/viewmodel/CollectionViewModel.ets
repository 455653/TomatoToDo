// ===== viewmodel/CollectionViewModel.ets =====
// 任务合集管理业务逻辑 —— @ObservedV2 响应式数据

import { Collection } from '../model/CollectionModel';
import { CollectionDao } from '../database/CollectionDao';
import { AuthGuard } from '../utils/AuthGuard';

/** 预设合集颜色 */
export const PRESET_COLORS: string[] = [
  '#FF6347',
  '#4CAF50',
  '#2196F3',
  '#FF9800',
  '#9C27B0',
  '#607D8B',
];

/**
 * CollectionViewModel —— @ObservedV2 + @Trace 实现响应式合集列表
 * 组件层通过 @State 拷贝数据触发 UI 刷新
 */
@ObservedV2
export class CollectionViewModel {
  /** 当前用户的合集列表 */
  @Trace collections: Collection[] = [];

  private collectionDao: CollectionDao = new CollectionDao();

  /**
   * 加载当前用户所有合集
   */
  async loadCollections(): Promise<void> {
    try {
      const userId: number = AuthGuard.getCurrentUserId();
      if (userId <= 0) {
        this.collections = [];
        return;
      }
      this.collections = await this.collectionDao.findAllByUser(userId);
    } catch (err) {
      this.collections = [];
      throw new Error(`加载合集失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 添加新合集
   */
  async addCollection(name: string, color: string): Promise<void> {
    try {
      const userId: number = AuthGuard.getCurrentUserId();
      if (userId <= 0) {
        throw new Error('用户未登录');
      }
      await this.collectionDao.insert({
        userId: userId,
        name: name,
        color: color,
        createdAt: Date.now(),
      });
      await this.loadCollections();
    } catch (err) {
      throw new Error(`添加合集失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 更新合集
   */
  async updateCollection(collection: Collection): Promise<void> {
    try {
      await this.collectionDao.update(collection);
      await this.loadCollections();
    } catch (err) {
      throw new Error(`更新合集失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 删除合集（将合集下任务置为未分类，不删除任务）
   */
  async deleteCollection(collection: Collection): Promise<void> {
    try {
      await this.collectionDao.deleteById(collection.id);
      await this.loadCollections();
    } catch (err) {
      throw new Error(`删除合集失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 检查合集名称是否已存在
   */
  async isNameDuplicate(name: string, excludeId?: number): Promise<boolean> {
    try {
      const userId: number = AuthGuard.getCurrentUserId();
      if (userId <= 0) {
        return false;
      }
      return await this.collectionDao.isNameExists(userId, name, excludeId);
    } catch (err) {
      return false;
    }
  }
}
