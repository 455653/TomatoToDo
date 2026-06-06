// ===== pages/Index.ets =====
// 主容器页面 —— 底部 TabBar 导航（任务 | 今日 | 专注 | 统计 | 我的）

import { router } from '@kit.ArkUI';
import { AuthGuard } from '../utils/AuthGuard';
import { TaskPage } from './TaskPage';
import { TodayPage } from './TodayPage';
import { TimerPage } from './TimerPage';
import { StatPage } from './StatPage';

@Entry
@Component
struct Index {
  /** 当前选中的 Tab 索引 */
  @State currentTabIndex: number = 0;
  /** Tab 控制器 */
  private tabsController: TabsController = new TabsController();

  /**
   * 页面出现时检查登录态
   */
  aboutToAppear(): void {
    if (!AuthGuard.isLoggedIn()) {
      router.replaceUrl({ url: 'pages/LoginPage' });
    }
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
