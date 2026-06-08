// ===== pages/Index.ets =====
// 主容器页面 —— 底部 TabBar 导航（任务 | 今日 | 专注 | 统计 | 我的）

import { router } from '@kit.ArkUI';
import { AuthGuard } from '../utils/AuthGuard';
import { TaskPage } from './TaskPage';
import { TodayPage } from './TodayPage';
import { TimerPage } from './TimerPage';
import { StatPage } from './StatPage';
import { common } from '@kit.AbilityKit';

@Entry
@Component
struct Index {
  /** 当前选中的 Tab 索引 */
  @State currentTabIndex: number = 0;
  /** Tab 控制器 */
  private tabsController: TabsController = new TabsController();
  /**
   * 统计 Tab 重建密钥
   * 每次切换到统计 Tab 时递增，强制 StatPage 销毁→重建，
   * 从而完全绕过 TabsCacheMode.CACHE_BOTH_SIDE 的缓存问题。
   * 这是经过 emitter / AppStorage 两种方案均失败后的终极解决方案。
   */
  @State statTabKey: number = 0;

  /**
   * 页面出现时检查登录态
   */
  aboutToAppear(): void {
    const context = getContext(this) as common.Context;
    AuthGuard.init(context).then(() => {
      console.log('[Index] AuthGuard 已初始化');
      if (!AuthGuard.isLoggedIn()) {
        router.replaceUrl({ url: 'pages/LoginPage' }).catch((err: Error) => {
          console.error('[Index] 路由跳转失败', JSON.stringify(err));
        });
      }
    }).catch((err: Error) => {
      console.error('[Index] AuthGuard 初始化失败', JSON.stringify(err));
    });
  }

  build() {
    Tabs({
      barPosition: BarPosition.End,
      controller: this.tabsController,
      index: this.currentTabIndex,
    }) {
      // ═══════════════════════════════════════
      // Tab 0：任务
      // ═══════════════════════════════════════
      TabContent() {
        TaskPage()
      }
      .tabBar(this.TabBarTask())

      // ═══════════════════════════════════════
      // Tab 1：今日
      // ═══════════════════════════════════════
      TabContent() {
        TodayPage()
      }
      .tabBar(this.TabBarToday())

      // ═══════════════════════════════════════
      // Tab 2：专注
      // ═══════════════════════════════════════
      TabContent() {
        TimerPage()
      }
      .tabBar(this.TabBarFocus())

      // ═══════════════════════════════════════
      // Tab 3：统计
      // ═══════════════════════════════════════
      TabContent() {
        StatPage()
      }
      .key(`stat_tab_${this.statTabKey}`)
      .tabBar(this.TabBarStats())

      // ═══════════════════════════════════════
      // Tab 4：我的（占位）
      // ═══════════════════════════════════════
      TabContent() {
        this.SettingsPlaceholder()
      }
      .tabBar(this.TabBarProfile())
    }
    .barWidth('100%')
    .barHeight(56)
    .animationDuration(0)
    .onChange((index: number) => {
      this.currentTabIndex = index;
      if (index === 3) {
        // 递增密钥 → 强制销毁旧 StatPage → 创建新 StatPage → aboutToAppear → loadData()
        // 这完全绕过了 TabsCacheMode.CACHE_BOTH_SIDE 的缓存问题
        this.statTabKey++;
      }
    })
    .cachedMaxCount(5, TabsCacheMode.CACHE_BOTH_SIDE)
    .width('100%')
    .height('100%')
  }

  // ═══════════════════════════════════════════
  // TabBar 构建器
  // ═══════════════════════════════════════════

  @Builder
  TabBarTask() {
    Column() {
      Text('✅')
        .fontSize(22)
        .fontColor(this.currentTabIndex === 0 ? '#E53935' : '#9E9E9E')
      Text('任务')
        .fontSize(10)
        .fontColor(this.currentTabIndex === 0 ? '#E53935' : '#9E9E9E')
        .margin({ top: 2 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  TabBarToday() {
    Column() {
      Text('📋')
        .fontSize(22)
        .fontColor(this.currentTabIndex === 1 ? '#E53935' : '#9E9E9E')
      Text('今日')
        .fontSize(10)
        .fontColor(this.currentTabIndex === 1 ? '#E53935' : '#9E9E9E')
        .margin({ top: 2 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  TabBarFocus() {
    Column() {
      Text('🍅')
        .fontSize(22)
        .fontColor(this.currentTabIndex === 2 ? '#E53935' : '#9E9E9E')
      Text('专注')
        .fontSize(10)
        .fontColor(this.currentTabIndex === 2 ? '#E53935' : '#9E9E9E')
        .margin({ top: 2 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  TabBarStats() {
    Column() {
      Text('📊')
        .fontSize(22)
        .fontColor(this.currentTabIndex === 3 ? '#E53935' : '#9E9E9E')
      Text('统计')
        .fontSize(10)
        .fontColor(this.currentTabIndex === 3 ? '#E53935' : '#9E9E9E')
        .margin({ top: 2 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  TabBarProfile() {
    Column() {
      Text('👤')
        .fontSize(22)
        .fontColor(this.currentTabIndex === 4 ? '#E53935' : '#9E9E9E')
      Text('我的')
        .fontSize(10)
        .fontColor(this.currentTabIndex === 4 ? '#E53935' : '#9E9E9E')
        .margin({ top: 2 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  // ═══════════════════════════════════════════
  // "我的" 占位页
  // ═══════════════════════════════════════════

  @Builder
  SettingsPlaceholder() {
    Column() {
      Text('👤')
        .fontSize(48)
        .fontColor('#CCCCCC')
        .margin({ bottom: 16 })

      Text('设置功能即将开放')
        .fontSize(16)
        .fontColor('#999999')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#FFFFFF')
  }
}
