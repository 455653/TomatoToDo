// ===== pages/ProfilePage.ets =====
// "我的"页面 —— 用户信息、修改密码、退出登录

import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { AuthGuard } from '../utils/AuthGuard';
import { UserDao } from '../database/UserDao';
import { User } from '../model/UserModel';

@Component
export struct ProfilePage {
  /** 当前用户名 */
  @State username: string = '';
  /** 是否正在加载 */
  @State isLoading: boolean = true;

  private userDao: UserDao = new UserDao();

  /**
   * 页面出现时加载用户信息
   */
  async aboutToAppear(): Promise<void> {
    await this.loadUserInfo();
  }

  /**
   * 页面重新显示时刷新用户信息
   */
  onPageShow(): void {
    this.loadUserInfo();
  }

  /**
   * 加载当前用户信息
   */
  private async loadUserInfo(): Promise<void> {
    try {
      const userId: number = AuthGuard.getCurrentUserId();
      if (userId <= 0) {
        this.username = '未登录';
        this.isLoading = false;
        return;
      }
      const user: User | null = await this.userDao.findById(userId);
      if (user) {
        this.username = user.username;
      } else {
        this.username = '未知用户';
      }
    } catch (err) {
      console.error('[ProfilePage] 加载用户信息失败', JSON.stringify(err));
      this.username = '加载失败';
    } finally {
      this.isLoading = false;
    }
  }

  build() {
    Column() {
      // ========== 用户信息卡片 ==========
      this.UserInfoCard()

      // ========== 功能列表 ==========
      this.MenuList()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  /**
   * 用户信息卡片
   */
  @Builder
  UserInfoCard() {
    Column() {
      Text('👤')
        .fontSize(48)
        .margin({ bottom: 8 })

      Text(this.username)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')

      Text('已登录')
        .fontSize(13)
        .fontColor('rgba(255,255,255,0.8)')
        .margin({ top: 4 })
    }
    .width('100%')
    .padding({ top: 40, bottom: 32 })
    .backgroundColor('#FF6347')
    .borderRadius({ bottomLeft: 20, bottomRight: 20 })
  }

  /**
   * 功能菜单列表
   */
  @Builder
  MenuList() {
    Column() {
      // ---- 修改密码 ----
      Row() {
        Text('🔑')
          .fontSize(22)
          .margin({ right: 12 })

        Column() {
          Text('修改密码')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#333333')
          Text('验证旧密码后设置新密码')
            .fontSize(12)
            .fontColor('#999999')
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text('›')
          .fontSize(20)
          .fontColor('#CCCCCC')
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 16 })
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
      .margin({ top: 16, left: 16, right: 16 })
      .onClick(() => {
        router.pushUrl({ url: 'pages/ChangePasswordPage' });
      })

      // ---- 退出登录 ----
      Row() {
        Text('🚪')
          .fontSize(22)
          .margin({ right: 12 })

        Column() {
          Text('退出登录')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#333333')
          Text('退出当前帐号')
            .fontSize(12)
            .fontColor('#999999')
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text('›')
          .fontSize(20)
          .fontColor('#CCCCCC')
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 16 })
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
      .margin({ top: 12, left: 16, right: 16 })
      .onClick(() => {
        this.handleLogout();
      })
    }
    .width('100%')
  }

  /**
   * 退出登录 —— 弹出确认对话框
   */
  private handleLogout(): void {
    AlertDialog.show({
      title: '退出登录',
      message: '确定要退出当前帐号吗？',
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '取消',
        action: () => {},
      },
      secondaryButton: {
        value: '退出',
        fontColor: '#FF6347',
        action: async () => {
          try {
            await AuthGuard.logout();
            promptAction.showToast({ message: '已退出登录', duration: 1500 });
            router.replaceUrl({ url: 'pages/LoginPage' });
          } catch (err) {
            console.error('[ProfilePage] 退出登录失败', JSON.stringify(err));
            promptAction.showToast({ message: '退出失败，请重试', duration: 1500 });
          }
        },
      },
    });
  }
}
