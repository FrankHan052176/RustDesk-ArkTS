import { LocalFileEntry, RemoteFileEntry, TransferItem } from '../RustDeskSessionTypes';
import { RustDeskGlassEffect } from '../RustDeskGlassEffect';

export interface TransferDrawerProps {
  downloadRootPath: string;
  rootStatus: string;
  localEntries: LocalFileEntry[];
  remoteDirectory: string;
  remoteEntries: RemoteFileEntry[];
  selectedLocalName: string;
  selectedRemoteName: string;
  transfers: TransferItem[];
  onSelectLocal: (name: string) => void;
  onSelectRemote: (name: string) => void;
  onUpload: () => void;
  onDownload: () => void;
  onOpenRemoteDirectory: (name: string) => void;
  onRemoteBack: () => void;
  onResolveOverride: (id: number, needOverride: boolean) => void;
  onCancel: (id: number) => void;
  onClose: () => void;
}

@ComponentV2
export struct TransferDrawer {
  @Param downloadRootPath: string = '';
  @Param rootStatus: string = '';
  @Param localEntries: LocalFileEntry[] = [];
  @Param remoteDirectory: string = '/';
  @Param remoteEntries: RemoteFileEntry[] = [];
  @Param selectedLocalName: string = '';
  @Param selectedRemoteName: string = '';
  @Param transfers: TransferItem[] = [];
  @Local viewportWidth: number = 390;
  @Local pressedControl: string = '';
  @Local adjustingControl: string = '';
  @Event onSelectLocal: (name: string) => void = (_name: string) => {};
  @Event onSelectRemote: (name: string) => void = (_name: string) => {};
  @Event onUpload: () => void = () => {};
  @Event onDownload: () => void = () => {};
  @Event onOpenRemoteDirectory: (name: string) => void = (_name: string) => {};
  @Event onRemoteBack: () => void = () => {};
  @Event onResolveOverride: (id: number, needOverride: boolean) => void = (_id: number, _needOverride: boolean) => {};
  @Event onCancel: (id: number) => void = (_id: number) => {};
  @Event onClose: () => void = () => {};

  private formatBytes(value: number): string {
    const size = Math.max(value, 0);
    if (size < 1024) {
      return `${size} B`;
    }
    if (size < 1024 * 1024) {
      return `${(size / 1024).toFixed(1)} KB`;
    }
    if (size < 1024 * 1024 * 1024) {
      return `${(size / (1024 * 1024)).toFixed(1)} MB`;
    }
    return `${(size / (1024 * 1024 * 1024)).toFixed(1)} GB`;
  }

  private isDirectory(entry: RemoteFileEntry): boolean {
    return entry.entry_type !== 0;
  }

  private entrySize(entry: RemoteFileEntry): string {
    return this.isDirectory(entry) ? '文件夹' : this.formatBytes(entry.size);
  }

  private transferDetail(item: TransferItem): string {
    const transferred = this.formatBytes(item.transferredBytes);
    const total = item.totalBytes > 0 ? this.formatBytes(item.totalBytes) : '未知大小';
    const speed = item.speedBytesPerSecond > 0 ? `${this.formatBytes(item.speedBytesPerSecond)}/秒` : '等待速度';
    return `${this.stateText(item.state)} · ${transferred} / ${total} · ${speed}`;
  }

  private stateText(state: string): string {
    if (state === 'queued') {
      return '排队中';
    }
    if (state === 'running') {
      return '传输中';
    }
    if (state === 'awaiting_override') {
      return '等待覆盖确认';
    }
    if (state === 'completed') {
      return '已完成';
    }
    if (state === 'failed') {
      return '失败';
    }
    return '已取消';
  }

  private parentPath(): string {
    const current = this.remoteDirectory.trim().replace(/\/+$/, '');
    if (current.length === 0 || current === '/') {
      return '/';
    }
    const separator = current.lastIndexOf('/');
    return separator <= 0 ? '/' : current.substring(0, separator);
  }

  private useWideLayout(): boolean {
    return this.viewportWidth >= 920;
  }

  private clickBlurScale(key: string): number {
    return this.pressedControl === key ? 0.18 : 0.72;
  }

  private selectionBlurScale(prefix: string): number {
    return this.adjustingControl.startsWith(prefix) ? 0.18 : 0.72;
  }

  private animateClickBlur(key: string, active: boolean): void {
    this.getUIContext().animateTo({
      duration: active ? 160 : 280,
      curve: Curve.Friction,
    }, () => {
      if (active) {
        this.pressedControl = key;
      } else if (this.pressedControl === key) {
        this.pressedControl = '';
      }
    });
  }

  private animateSelectionBlur(key: string, active: boolean): void {
    this.getUIContext().animateTo({
      duration: active ? 160 : 280,
      curve: Curve.Friction,
    }, () => {
      if (active) {
        this.adjustingControl = key;
      } else if (this.adjustingControl === key) {
        this.adjustingControl = '';
      }
    });
  }

  @Builder
  private FloatingAction(key: string, label: string, emphasized: boolean, enabled: boolean, onClick: () => void) {
    Button({ type: ButtonType.Normal, stateEffect: false }) {
      Stack() {
        if (emphasized) {
          Row()
            .width('100%')
            .height('100%')
            .backgroundColor($r('app.color.brand_primary'));
        }
        Row() {
          Text(label)
            .fontSize($r('app.float.font_label'))
            .fontWeight(FontWeight.Medium)
            .fontColor(enabled
              ? (emphasized ? $r('app.color.white') : $r('app.color.text_primary'))
              : $r('app.color.disabled_text'));
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .borderRadius($r('app.float.radius_14'))
        .clip(true)
        .visualEffect(RustDeskGlassEffect.interactiveContent(
          this.pressedControl === key,
          $r('app.color.point_light'),
          0.56,
        ));
      }
      .width('100%')
      .height('100%')
      .borderRadius($r('app.float.radius_14'))
      .clip(true);
    }
    .height($r('app.float.control_small'))
    .padding(0)
    .enabled(enabled)
    .backgroundColor($r('app.color.glass_surface'))
    .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK, {
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: this.clickBlurScale(key),
    })
    .linearGradient({
      angle: 142,
      colors: [
        [$r('app.color.glass_gradient_high'), 0],
        [$r('app.color.glass_gradient_mid'), 0.48],
        [$r('app.color.glass_gradient_accent'), 1],
      ],
    })
    .borderRadius($r('app.float.radius_14'))
    .clip(true)
    .shadow(ShadowStyle.OUTER_DEFAULT_MD)
    .visualEffect(RustDeskGlassEffect.featherReceiver())
    .onTouch((event: TouchEvent) => {
      if (!enabled) {
        return;
      }
      if (event.type === TouchType.Down) {
        this.animateClickBlur(key, true);
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.animateClickBlur(key, false);
      }
    })
    .onClick(onClick);
  }

  @Builder
  private LocalEntry(entry: LocalFileEntry, showDivider: boolean) {
    Button({ type: ButtonType.Normal, stateEffect: false }) {
      Stack() {
        if (this.selectedLocalName === entry.name) {
          Row()
            .width('100%')
            .height('100%')
            .backgroundColor($r('app.color.brand_primary_soft'))
            .opacity(0.78);
        }
        Column({ space: $r('app.float.space_2') }) {
          Text(entry.name)
            .width('100%')
            .fontSize($r('app.float.font_body'))
            .fontWeight(FontWeight.Medium)
            .fontColor(this.selectedLocalName === entry.name
              ? $r('app.color.brand_primary')
              : $r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
          Text(this.formatBytes(entry.size))
            .fontSize($r('app.float.font_label'))
            .fontColor($r('app.color.text_secondary'));
        }
        .width('100%')
        .height('100%')
        .padding({ left: $r('app.float.space_12'), right: $r('app.float.space_12') })
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Start)
        .border({
          width: { bottom: showDivider ? 0.5 : 0 },
          color: $r('app.color.divider'),
        })
        .borderRadius($r('app.float.radius_14'))
        .clip(true)
        .visualEffect(RustDeskGlassEffect.interactiveContent(
          this.adjustingControl === `local-${entry.path}`,
          $r('app.color.point_light'),
          0.42,
        ));
      }
      .width('100%')
      .height('100%')
      .borderRadius($r('app.float.radius_14'))
      .clip(true);
    }
    .width('100%')
    .height($r('app.float.control_large'))
    .padding(0)
    .backgroundColor($r('app.color.transparent'))
    .borderRadius($r('app.float.radius_14'))
    .clip(true)
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.animateSelectionBlur(`local-${entry.path}`, true);
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.animateSelectionBlur(`local-${entry.path}`, false);
      }
    })
    .onClick(() => this.onSelectLocal(entry.name));
  }

  @Builder
  private RemoteEntry(entry: RemoteFileEntry, showDivider: boolean) {
    Button({ type: ButtonType.Normal, stateEffect: false }) {
      Stack() {
        if (this.selectedRemoteName === entry.name) {
          Row()
            .width('100%')
            .height('100%')
            .backgroundColor($r('app.color.brand_primary_soft'))
            .opacity(0.78);
        }
        Row({ space: $r('app.float.space_8') }) {
          Column({ space: $r('app.float.space_2') }) {
            Text(this.isDirectory(entry) ? `文件夹 · ${entry.name}` : entry.name)
              .width('100%')
              .fontSize($r('app.float.font_body'))
              .fontWeight(FontWeight.Medium)
              .fontColor(this.selectedRemoteName === entry.name
                ? $r('app.color.brand_primary')
                : $r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis });
            Text(this.entrySize(entry))
              .fontSize($r('app.float.font_label'))
              .fontColor($r('app.color.text_secondary'));
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start);
          if (this.isDirectory(entry)) {
            Text('进入')
              .fontSize($r('app.float.font_label'))
              .fontColor($r('app.color.brand_primary'));
          }
        }
        .width('100%')
        .height('100%')
        .padding({ left: $r('app.float.space_12'), right: $r('app.float.space_12') })
        .alignItems(VerticalAlign.Center)
        .border({
          width: { bottom: showDivider ? 0.5 : 0 },
          color: $r('app.color.divider'),
        })
        .borderRadius($r('app.float.radius_14'))
        .clip(true)
        .visualEffect(RustDeskGlassEffect.interactiveContent(
          this.adjustingControl === `remote-${entry.name}`,
          $r('app.color.point_light'),
          0.42,
        ));
      }
      .width('100%')
      .height('100%')
      .borderRadius($r('app.float.radius_14'))
      .clip(true);
    }
    .width('100%')
    .height($r('app.float.control_large'))
    .padding(0)
    .backgroundColor($r('app.color.transparent'))
    .borderRadius($r('app.float.radius_14'))
    .clip(true)
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.animateSelectionBlur(`remote-${entry.name}`, true);
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.animateSelectionBlur(`remote-${entry.name}`, false);
      }
    })
    .onClick(() => {
      if (this.isDirectory(entry)) {
        this.onOpenRemoteDirectory(entry.name);
      } else {
        this.onSelectRemote(entry.name);
      }
    });
  }

  @Builder
  private TransferRow(item: TransferItem) {
    Column({ space: $r('app.float.space_6') }) {
      Text(`${item.direction === 'upload' ? '上传' : '下载'} · ${item.fileName}`)
        .width('100%')
        .fontSize($r('app.float.font_body'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
      Text(this.transferDetail(item))
        .fontSize($r('app.float.font_label'))
        .fontColor($r('app.color.text_secondary'));
      if (item.errorText.length > 0) {
        Text(item.errorText)
          .fontSize($r('app.float.font_label'))
          .fontColor($r('app.color.error'))
          .maxLines(2);
      }
      if (item.state === 'awaiting_override') {
        Row({ space: $r('app.float.space_8') }) {
          this.FloatingAction(`override-${item.id}`, '覆盖', true, true,
            () => this.onResolveOverride(item.id, true))
          this.FloatingAction(`skip-${item.id}`, '跳过', false, true,
            () => this.onResolveOverride(item.id, false))
        }
        .width('100%');
      } else if (item.state === 'queued' || item.state === 'running') {
        this.FloatingAction(`cancel-${item.id}`, '取消', false, true, () => this.onCancel(item.id))
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: $r('app.float.space_12'), bottom: $r('app.float.space_12') })
    .border({ width: { bottom: 0.5 }, color: $r('app.color.divider') });
  }

  @Builder
  private LocalPaneContent() {
    Row({ space: $r('app.float.space_8') }) {
      Column({ space: $r('app.float.space_2') }) {
        Text('本机文件')
          .fontSize($r('app.float.font_body_large'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'));
        Text(this.rootStatus || 'HarmonyOS 下载目录')
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);

      this.FloatingAction('upload', '上传', true, this.selectedLocalName.length > 0, () => this.onUpload())
    }
    .width('100%')
    .alignItems(VerticalAlign.Center);

    Text(this.downloadRootPath.length > 0 ? this.downloadRootPath : '未选择下载位置')
      .width('100%')
      .fontSize($r('app.float.font_caption'))
      .fontColor($r('app.color.text_secondary'))
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .padding({ left: $r('app.float.space_12'), right: $r('app.float.space_12'),
        top: $r('app.float.space_8'), bottom: $r('app.float.space_8') })
      .margin({ top: $r('app.float.space_12'), bottom: $r('app.float.space_8') })
      .backgroundColor($r('app.color.field_background'))
      .borderRadius($r('app.float.radius_10'));

    Stack() {
      Scroll() {
        Column({ space: 0 }) {
          ForEach(this.localEntries, (entry: LocalFileEntry, index: number) => {
            this.LocalEntry(entry, index < this.localEntries.length - 1);
          }, (entry: LocalFileEntry) => entry.path)
          if (this.localEntries.length === 0) {
            Text('下载位置中没有可直接上传的文件')
              .width('100%')
              .fontSize($r('app.float.font_body'))
              .fontColor($r('app.color.text_secondary'))
              .textAlign(TextAlign.Center)
              .padding($r('app.float.space_20'))
              .visualEffect(RustDeskGlassEffect.contentReceiver());
          }
        }
        .width('100%')
        .borderRadius($r('app.float.radius_14'))
        .clip(true);
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off);
    }
    .layoutWeight(1)
    .width('100%')
    .backgroundColor($r('app.color.glass_surface'))
    .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK, {
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: this.selectionBlurScale('local-'),
    })
    .linearGradient({
      angle: 142,
      colors: [
        [$r('app.color.glass_gradient_high'), 0],
        [$r('app.color.glass_gradient_mid'), 0.48],
        [$r('app.color.glass_gradient_accent'), 1],
      ],
    })
    .borderRadius($r('app.float.radius_14'))
    .clip(true)
    .shadow(ShadowStyle.OUTER_DEFAULT_MD)
    .visualEffect(RustDeskGlassEffect.featherReceiver());
  }

  @Builder
  private RemotePaneContent() {
    Row({ space: $r('app.float.space_8') }) {
      Column({ space: $r('app.float.space_2') }) {
        Text('远端文件')
          .fontSize($r('app.float.font_body_large'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'));
        Text('选择文件夹继续浏览')
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.text_secondary'));
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);

      this.FloatingAction('remote-back', '上级', false, this.parentPath() !== this.remoteDirectory,
        () => this.onRemoteBack())
      this.FloatingAction('download', '下载', true, this.selectedRemoteName.length > 0,
        () => this.onDownload())
    }
    .width('100%')
    .alignItems(VerticalAlign.Center);

    Text(this.remoteDirectory)
      .width('100%')
      .fontSize($r('app.float.font_caption'))
      .fontColor($r('app.color.text_secondary'))
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .padding({ left: $r('app.float.space_12'), right: $r('app.float.space_12'),
        top: $r('app.float.space_8'), bottom: $r('app.float.space_8') })
      .margin({ top: $r('app.float.space_12'), bottom: $r('app.float.space_8') })
      .backgroundColor($r('app.color.field_background'))
      .borderRadius($r('app.float.radius_10'));

    Stack() {
      Scroll() {
        Column({ space: 0 }) {
          ForEach(this.remoteEntries, (entry: RemoteFileEntry, index: number) => {
            this.RemoteEntry(entry, index < this.remoteEntries.length - 1);
          }, (entry: RemoteFileEntry) => `${entry.entry_type}-${entry.name}`)
          if (this.remoteEntries.length === 0) {
            Text('远端目录为空或正在加载')
              .width('100%')
              .fontSize($r('app.float.font_body'))
              .fontColor($r('app.color.text_secondary'))
              .textAlign(TextAlign.Center)
              .padding($r('app.float.space_20'))
              .visualEffect(RustDeskGlassEffect.contentReceiver());
          }
        }
        .width('100%')
        .borderRadius($r('app.float.radius_14'))
        .clip(true);
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off);
    }
    .layoutWeight(1)
    .width('100%')
    .backgroundColor($r('app.color.glass_surface'))
    .backgroundBlurStyle(BlurStyle.BACKGROUND_THICK, {
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: this.selectionBlurScale('remote-'),
    })
    .linearGradient({
      angle: 142,
      colors: [
        [$r('app.color.glass_gradient_high'), 0],
        [$r('app.color.glass_gradient_mid'), 0.48],
        [$r('app.color.glass_gradient_accent'), 1],
      ],
    })
    .borderRadius($r('app.float.radius_14'))
    .clip(true)
    .shadow(ShadowStyle.OUTER_DEFAULT_MD)
    .visualEffect(RustDeskGlassEffect.featherReceiver());
  }

  @Builder
  private TransferPaneContent() {
    Row() {
      Text('传输任务')
        .layoutWeight(1)
        .fontSize($r('app.float.font_body_large'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'));
      Text(`${this.transfers.length}`)
        .fontSize($r('app.float.font_label'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.brand_primary'));
    }
    .width('100%')
    .margin({ bottom: $r('app.float.space_8') });

    Scroll() {
      Column() {
        ForEach(this.transfers, (item: TransferItem) => {
          this.TransferRow(item);
        }, (item: TransferItem) => item.id.toString())
        if (this.transfers.length === 0) {
          Column({ space: $r('app.float.space_8') }) {
            Text('⇄')
              .fontSize($r('app.float.font_title_large'))
              .fontColor($r('app.color.text_tertiary'));
            Text('暂无传输任务')
              .fontSize($r('app.float.font_body'))
              .fontColor($r('app.color.text_secondary'));
          }
          .width('100%')
          .padding({ top: $r('app.float.space_32'), bottom: $r('app.float.space_32') });
        }
      }
      .width('100%');
    }
    .layoutWeight(1)
    .width('100%')
    .scrollBar(BarState.Off);
  }

  build() {
    Stack() {
      if (this.useWideLayout()) {
        Row({ space: $r('app.float.space_16') }) {
          Column() {
            this.LocalPaneContent();
          }
          .layoutWeight(1)
          .height('100%');

          Column()
            .width(1)
            .height('100%')
            .backgroundColor($r('app.color.divider'));

          Column() {
            this.RemotePaneContent();
          }
          .layoutWeight(1)
          .height('100%');

          Column()
            .width(1)
            .height('100%')
            .backgroundColor($r('app.color.divider'));

          Column() {
            this.TransferPaneContent();
          }
          .width(this.viewportWidth >= 1280 ? 300 : 260)
          .height('100%');
        }
        .width('100%')
        .height('100%')
        .alignItems(VerticalAlign.Top);
      } else {
        Scroll() {
          Column({ space: $r('app.float.space_24') }) {
            Column() {
              this.LocalPaneContent();
            }
            .width('100%')
            .height(300);

            Column() {
              this.RemotePaneContent();
            }
            .width('100%')
            .height(360);

            Column() {
              this.TransferPaneContent();
            }
            .width('100%')
            .height(260);
          }
          .width('100%')
          .padding({ bottom: $r('app.float.space_8') });
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off);
      }
    }
    .width('100%')
    .layoutWeight(1)
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      const width = Number(newArea.width);
      if (width > 0) {
        this.viewportWidth = width;
      }
    });
  }
}
