import { common } from '@kit.AbilityKit';
import {
  LuminousButton,
  LuminousControlSize,
  LuminousSegmentedControl,
  LuminousSelectionItem,
  LuminousSwitch,
  LuminousTone,
} from 'luminous_neo';
import { AccountProvider } from '../RustDeskDirectoryTypes';
import { RustDeskAccountController, rustDeskAccountController } from '../NativeAccountBridge';

export interface AccountSettingsCardProps {
  showHeader: boolean;
  controller?: RustDeskAccountController;
}

@ComponentV2
export struct AccountSettingsCard {
  @Param showHeader: boolean = false;
  @Param controller: RustDeskAccountController = rustDeskAccountController;
  @Local viewportWidth: number = 390;

  private isBusy(): boolean {
    return this.controller.oidcInProgress;
  }

  private contentWidth(): number {
    // Keep controls readable in the wide settings sheet; the parent card may
    // span the full tablet width, but selectors and actions need one stable rail.
    return Math.max(260, Math.min(this.viewportWidth - 48, 720));
  }

  private handleLogin(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    void this.controller.startOidcLogin(context);
  }

  private handleCancel(): void {
    void this.controller.cancelOidcLogin();
  }

  private handleLogout(): void {
    void this.controller.logout();
  }

  private handleRefreshProviders(): void {
    void this.controller.loadProviders();
  }

  private providerSelectionItems(): LuminousSelectionItem[] {
    const items: LuminousSelectionItem[] = [];
    for (let i = 0; i < this.controller.providers.length; i += 1) {
      const p = this.controller.providers[i];
      items.push(new LuminousSelectionItem(p.id, p.label));
    }
    return items;
  }

  private selectedProviderIndex(): number {
    const idx = this.controller.providers.findIndex(
      (p: AccountProvider) => p.id === this.controller.selectedProviderId,
    );
    return idx >= 0 ? idx : 0;
  }

  @Builder
  private LoggedInView() {
    Column({ space: 16 }) {
      Row({ space: 14 }) {
        SymbolGlyph($r('sys.symbol.person_crop_circle_fill'))
          .fontSize(44)
          .fontColor([$r('app.color.neu_accent')]);

        Column({ space: 4 }) {
          Text(this.controller.state.displayName || this.controller.state.name || '已登录用户')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.neu_text_primary'));

          if (this.controller.state.name && this.controller.state.name !== this.controller.state.displayName) {
            Text(`账号：${this.controller.state.name}`)
              .fontSize(12)
              .fontColor($r('app.color.neu_text_secondary'));
          }

          if (this.controller.state.status && this.controller.state.status.trim().length > 0) {
            Text(`状态：${this.controller.state.status}`)
              .fontSize(11)
              .fontColor($r('app.color.neu_text_secondary'));
          }

          if (this.controller.state.serverBindingMode === 'custom') {
            Text('服务：自建服务')
              .fontSize(11)
              .fontColor($r('app.color.neu_text_secondary'));
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);
      }
      .width('100%')
      .padding(16)
      .backgroundColor($r('app.color.surface_secondary'))
      .borderRadius(14);

      if (this.controller.booksLoading) {
        Row({ space: 8 }) {
          LoadingProgress().width(16).height(16);
          Text('正在同步云端通讯录…')
            .fontSize(12)
            .fontColor($r('app.color.neu_text_secondary'));
        }
        .width('100%')
        .padding({ left: 4, right: 4 });
      } else if (this.controller.addressBooks.length > 0) {
        Row() {
          Text(`云端通讯录：已同步 ${this.controller.addressBooks.length} 个地址簿`)
            .fontSize(12)
            .fontColor($r('app.color.neu_text_secondary'));
        }
        .width('100%')
        .padding({ left: 4, right: 4 });
      } else if (this.controller.booksError.length > 0) {
        Row() {
          Text(this.controller.booksError)
            .fontSize(12)
            .fontColor($r('app.color.warning'));
        }
        .width('100%')
        .padding({ left: 4, right: 4 });
      }

      LuminousButton({
        label: '退出登录',
        controlWidth: this.contentWidth(),
        controlSizeMode: LuminousControlSize.Regular,
        tone: LuminousTone.Neutral,
        isEnabled: !this.isBusy(),
        motionEnabled: true,
        onAction: (): void => this.handleLogout(),
      });
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  @Builder
  private LoginView() {
    Column({ space: 16 }) {
      if (this.controller.state.serverBindingMode === 'custom') {
        Text('服务：自建服务')
          .fontSize(12)
          .fontColor($r('app.color.neu_text_secondary'));
      }

      if (this.controller.providersLoading) {
        Row({ space: 8 }) {
          LoadingProgress().width(20).height(20);
          Text('正在查询登录方式…')
            .fontSize(12)
            .fontColor($r('app.color.neu_text_secondary'));
        }
        .width('100%')
        .padding(16);
      } else if (this.controller.providers.length === 0) {
        Column({ space: 10 }) {
          Text('当前服务器未返回可用登录方式')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.neu_text_primary'));
          Text('若使用自建服务，请在“服务器”设置中配置 API Server；若已配置，请检查服务连通性。')
            .fontSize(12)
            .lineHeight(18)
            .fontColor($r('app.color.neu_text_secondary'));

          LuminousButton({
            label: '重新获取',
            controlWidth: Math.min(180, this.contentWidth()),
            controlSizeMode: LuminousControlSize.Compact,
            tone: LuminousTone.Neutral,
            isEnabled: !this.isBusy(),
            motionEnabled: true,
            onAction: (): void => this.handleRefreshProviders(),
          });
        }
        .width('100%')
        .padding(16)
        .backgroundColor($r('app.color.surface_secondary'))
        .borderRadius(14);
      } else {
        Column({ space: 14 }) {
          Text('登录方式')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.neu_text_secondary'));

          if (this.controller.providers.length > 1) {
            LuminousSegmentedControl({
              items: this.providerSelectionItems(),
              selectedIndex: this.selectedProviderIndex(),
              controlWidth: this.contentWidth(),
              controlHeight: 44,
              isEnabled: !this.isBusy(),
              motionEnabled: true,
              onChange: (index: number): void => {
                if (index >= 0 && index < this.controller.providers.length) {
                  this.controller.selectedProviderId = this.controller.providers[index].id;
                }
              },
            });
          } else {
            Row() {
              Text(this.controller.providers[0].label)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.neu_text_primary'));
            }
            .width('100%')
            .padding(14)
            .backgroundColor($r('app.color.surface_secondary'))
            .borderRadius(12);
          }

          Row() {
            Text('保持登录状态')
              .fontSize(14)
              .fontColor($r('app.color.neu_text_primary'));
            Blank();
            LuminousSwitch({
              isOn: this.controller.rememberMe,
              isEnabled: !this.isBusy(),
              onChange: (isOn: boolean): void => {
                this.controller.rememberMe = isOn;
              },
            });
          }
          .width('100%')
          .padding({ top: 4, bottom: 4 });

          if (this.controller.oidcInProgress) {
            Column({ space: 10 }) {
              Row({ space: 10 }) {
                LoadingProgress().width(20).height(20);
                Text(this.controller.oidcPollMessage || '已在浏览器打开授权页面，等待授权完成…')
                  .fontSize(12)
                  .fontColor($r('app.color.neu_accent'));
              }
              .width('100%');

              LuminousButton({
                label: '取消登录',
                controlWidth: this.contentWidth(),
                controlSizeMode: LuminousControlSize.Regular,
                tone: LuminousTone.Neutral,
                motionEnabled: true,
                onAction: (): void => this.handleCancel(),
              });
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.surface_secondary'))
            .borderRadius(14);
          } else {
            LuminousButton({
              label: '前往浏览器登录',
              controlWidth: this.contentWidth(),
              controlSizeMode: LuminousControlSize.Regular,
              tone: LuminousTone.Accent,
              isEnabled: !this.isBusy(),
              motionEnabled: true,
              onAction: (): void => this.handleLogin(),
            });
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start);
      }

      if (this.controller.oidcError.length > 0) {
        Column({ space: 4 }) {
          Text('登录失败')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.error'));
          Text(this.controller.oidcError)
            .fontSize(12)
            .lineHeight(16)
            .fontColor($r('app.color.error'));
        }
        .width('100%')
        .padding(12)
        .backgroundColor($r('app.color.error_soft'))
        .borderRadius(10);
      } else if (this.controller.state.error.length > 0) {
        Column({ space: 4 }) {
          Text(this.controller.state.error)
            .fontSize(12)
            .lineHeight(16)
            .fontColor($r('app.color.error'));
        }
        .width('100%')
        .padding(12)
        .backgroundColor($r('app.color.error_soft'))
        .borderRadius(10);
      } else if (this.controller.state.message.length > 0) {
        Text(this.controller.state.message)
          .width('100%')
          .fontSize(12)
          .fontColor($r('app.color.neu_text_secondary'));
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  build() {
    Column({ space: 16 }) {
      if (this.showHeader) {
        Column({ space: 4 }) {
          Text('账号')
            .width('100%')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'));
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start);
      }

      if (this.controller.state.loggedIn) {
        this.LoggedInView();
      } else {
        this.LoginView();
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .onAreaChange((_oldArea: Area, newArea: Area): void => {
      const width = Number(newArea.width);
      if (width > 0) {
        this.viewportWidth = width;
      }
    })
    .accessibilityGroup(true);
  }
}
