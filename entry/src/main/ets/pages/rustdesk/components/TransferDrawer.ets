import { LocalFileEntry, RemoteFileEntry, TransferItem } from '../RustDeskSessionTypes';
import { RemoteFilePath } from '../RemoteFilePath';
import { FloatingDepthOverlay } from './FloatingDepth';
import { FloatingActionSurface, FloatingGlassSurface } from './FloatingSurface';

export interface TransferDrawerProps {
  scroller: Scroller;
  titleSpacerHeight: number;
  downloadRootPath: string;
  rootStatus: string;
  sessionReady: boolean;
  sessionStatus: string;
  localEntries: LocalFileEntry[];
  remoteDirectory: string;
  remoteEntries: RemoteFileEntry[];
  selectedLocalName: string;
  selectedRemoteName: string;
  transfers: TransferItem[];
  bottomAvoidInset: number;
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
  @Param scroller: Scroller = new Scroller();
  @Param titleSpacerHeight: number = 0;
  @Param downloadRootPath: string = '';
  @Param rootStatus: string = '';
  @Param sessionReady: boolean = false;
  @Param sessionStatus: string = '正在连接';
  @Param localEntries: LocalFileEntry[] = [];
  @Param remoteDirectory: string = '/';
  @Param remoteEntries: RemoteFileEntry[] = [];
  @Param selectedLocalName: string = '';
  @Param selectedRemoteName: string = '';
  @Param transfers: TransferItem[] = [];
  @Param bottomAvoidInset: number = 0;
  @Local viewportWidth: number = 390;
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
    return RemoteFilePath.isDirectoryType(entry.entry_type);
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

  private transferProgressValue(item: TransferItem): number {
    if (item.totalBytes <= 0) {
      return 0;
    }
    return Math.min(Math.max(item.transferredBytes, 0), item.totalBytes);
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

  private useWideLayout(): boolean {
    return this.viewportWidth >= 920;
  }

  private mobileEntrySurfaceHeight(entryCount: number): number {
    return entryCount > 0 ? entryCount * 56 : 96;
  }

  private actionEnabled(key: string): boolean {
    if (key === 'upload') {
      return this.sessionReady && this.selectedLocalName.length > 0;
    }
    if (key === 'download') {
      return this.sessionReady && this.selectedRemoteName.length > 0;
    }
    if (key === 'remote-back') {
      return this.sessionReady;
    }
    return true;
  }

  @Builder
  private FloatingAction(key: string, label: string, emphasized: boolean, onClick: () => void) {
    Stack() {
      FloatingActionSurface({
        actionEnabled: this.actionEnabled(key),
        compact: true,
        stopTouchPropagation: true,
        accessibilityLabel: label,
        onActivate: onClick,
      }) {
        Row() {
          Text(label)
            .fontSize($r('app.float.font_label'))
            .fontWeight(FontWeight.Medium)
            .fontColor(this.actionEnabled(key)
              ? (emphasized ? $r('app.color.neu_accent') : $r('app.color.text_primary'))
              : $r('app.color.disabled_text'));
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .borderRadius($r('app.float.radius_14'))
        .clip(true);
      }
    }
    .width(68)
    .height($r('app.float.control_small'))
    .borderRadius($r('app.float.radius_14'))
    .clip(false);
  }

  @Builder
  private LocalEntry(entry: LocalFileEntry, showDivider: boolean) {
    Button({ type: ButtonType.Normal, stateEffect: false }) {
      Stack() {
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
        .clip(true);
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
    .onClick(() => this.onSelectLocal(entry.name));
  }

  @Builder
  private RemoteEntry(entry: RemoteFileEntry, showDivider: boolean) {
    Button({ type: ButtonType.Normal, stateEffect: false }) {
      Stack() {
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
        .clip(true);
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
      if (item.state === 'queued' || item.state === 'running') {
        if (item.totalBytes > 0) {
          Progress({
            value: this.transferProgressValue(item),
            total: item.totalBytes,
            type: ProgressType.Linear,
          })
            .width('100%')
            .height(4)
            .color($r('app.color.brand_primary'))
            .backgroundColor($r('app.color.surface_secondary'));
        } else {
          LoadingProgress()
            .width($r('app.float.icon_regular'))
            .height($r('app.float.icon_regular'))
            .color($r('app.color.brand_primary'));
        }
      }
      if (item.errorText.length > 0) {
        Text(item.errorText)
          .fontSize($r('app.float.font_label'))
          .fontColor($r('app.color.error'))
          .maxLines(2);
      }
      if (item.state === 'awaiting_override') {
        Row({ space: $r('app.float.space_8') }) {
          this.FloatingAction(`override-${item.id}`, '覆盖', true,
            () => this.onResolveOverride(item.id, true))
          this.FloatingAction(`skip-${item.id}`, '跳过', false,
            () => this.onResolveOverride(item.id, false))
        }
        .width('100%');
      } else if (item.state === 'queued' || item.state === 'running') {
        this.FloatingAction(`cancel-${item.id}`, '取消', false, () => this.onCancel(item.id))
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: $r('app.float.space_12'), bottom: $r('app.float.space_12') })
    .border({ width: { bottom: 0.5 }, color: $r('app.color.divider') });
  }

  @Builder
  private LocalEntriesContent() {
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
          .padding($r('app.float.space_20'));
      }
    }
    .width('100%')
    .borderRadius($r('app.float.radius_14'))
    .clip(true);
  }

  @Builder
  private LocalPaneContent(fillAvailable: boolean) {
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

      this.FloatingAction('upload', '上传', true, () => this.onUpload())
    }
    .width('100%')
    .alignItems(VerticalAlign.Center);

    Stack() {
      FloatingGlassSurface({
        compact: true,
        inset: true,
        radius: $r('app.float.radius_10'),
      }) {
        Text(this.downloadRootPath.length > 0 ? this.downloadRootPath : '未选择下载位置')
          .width('100%')
          .height('100%')
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .padding({ left: $r('app.float.space_12'), right: $r('app.float.space_12') });
      }
    }
    .width('100%')
    .height(36)
    .margin({ top: $r('app.float.space_12'), bottom: $r('app.float.space_8') })
    .clip(false);

    Stack() {
      Stack() {
        FloatingDepthOverlay({
          inset: true,
          radius: $r('app.float.radius_14'),
        });

        if (fillAvailable) {
          Scroll() {
            this.LocalEntriesContent();
          }
          .width('100%')
          .height('100%')
          .scrollBar(BarState.Off);
        } else {
          this.LocalEntriesContent();
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.transparent'))
      .borderRadius($r('app.float.radius_14'))
      .clip(false);
    }
    .height(fillAvailable ? 0 : this.mobileEntrySurfaceHeight(this.localEntries.length) + 16)
    .layoutWeight(fillAvailable ? 1 : 0)
    .width('100%')
    .padding({
      left: $r('app.float.space_16'),
      right: $r('app.float.space_16'),
      top: $r('app.float.space_8'),
      bottom: $r('app.float.space_8'),
    });
  }

  @Builder
  private RemoteEntriesContent() {
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
          .padding($r('app.float.space_20'));
      }
    }
    .width('100%')
    .borderRadius($r('app.float.radius_14'))
    .clip(true);
  }

  @Builder
  private RemotePaneContent(fillAvailable: boolean) {
    Row({ space: $r('app.float.space_8') }) {
      Column({ space: $r('app.float.space_2') }) {
        Text('远端文件')
          .fontSize($r('app.float.font_body_large'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'));
        Text(this.sessionStatus)
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.text_secondary'));
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);

      this.FloatingAction('remote-back', '上级', false, () => this.onRemoteBack())
      this.FloatingAction('download', '下载', true, () => this.onDownload())
    }
    .width('100%')
    .alignItems(VerticalAlign.Center);

    Stack() {
      FloatingGlassSurface({
        compact: true,
        inset: true,
        radius: $r('app.float.radius_10'),
      }) {
        Text(this.remoteDirectory)
          .width('100%')
          .height('100%')
          .fontSize($r('app.float.font_caption'))
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .padding({ left: $r('app.float.space_12'), right: $r('app.float.space_12') });
      }
    }
    .width('100%')
    .height(36)
    .margin({ top: $r('app.float.space_12'), bottom: $r('app.float.space_8') })
    .clip(false);

    Stack() {
      Stack() {
        FloatingDepthOverlay({
          inset: true,
          radius: $r('app.float.radius_14'),
        });

        if (fillAvailable) {
          Scroll() {
            this.RemoteEntriesContent();
          }
          .width('100%')
          .height('100%')
          .scrollBar(BarState.Off);
        } else {
          this.RemoteEntriesContent();
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.transparent'))
      .borderRadius($r('app.float.radius_14'))
      .clip(false);
    }
    .height(fillAvailable ? 0 : this.mobileEntrySurfaceHeight(this.remoteEntries.length) + 16)
    .layoutWeight(fillAvailable ? 1 : 0)
    .width('100%')
    .padding({
      left: $r('app.float.space_16'),
      right: $r('app.float.space_16'),
      top: $r('app.float.space_8'),
      bottom: $r('app.float.space_8'),
    });
  }

  @Builder
  private TransferRowsContent() {
    Column() {
      ForEach(this.transfers, (item: TransferItem) => {
        this.TransferRow(item);
      }, (item: TransferItem) =>
        `${item.id}-${item.fileNum}-${item.state}-${Math.round(item.transferredBytes)}-${Math.round(item.speedBytesPerSecond)}`)
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

  @Builder
  private TransferPaneContent(fillAvailable: boolean) {
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

    if (fillAvailable) {
      Scroll() {
        this.TransferRowsContent();
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off);
    } else {
      this.TransferRowsContent();
    }
  }

  build() {
    Stack() {
      if (this.useWideLayout()) {
        Column() {
          Blank()
            .width('100%')
            .height(this.titleSpacerHeight)
            .flexShrink(0);

          Row({ space: $r('app.float.space_16') }) {
            Column() {
              this.LocalPaneContent(true);
            }
            .layoutWeight(1)
            .height('100%');

            Column()
              .width(1)
              .height('100%')
              .backgroundColor($r('app.color.divider'));

            Column() {
              this.RemotePaneContent(true);
            }
            .layoutWeight(1)
            .height('100%');

            Column()
              .width(1)
              .height('100%')
              .backgroundColor($r('app.color.divider'));

            Column() {
              this.TransferPaneContent(true);
            }
            .width(this.viewportWidth >= 1280 ? 300 : 260)
            .height('100%');
          }
          .layoutWeight(1)
          .width('100%')
          .alignItems(VerticalAlign.Top);
        }
        .width('100%')
        .height('100%')
        .alignItems(HorizontalAlign.Start);
      } else {
        Scroll(this.scroller) {
          Column() {
            Blank()
              .width('100%')
              .height(this.titleSpacerHeight)
              .flexShrink(0);

            Column({ space: $r('app.float.space_24') }) {
              Column() {
                this.LocalPaneContent(false);
              }
              .width('100%');

              Column() {
                this.RemotePaneContent(false);
              }
              .width('100%');

              Column() {
                this.TransferPaneContent(false);
              }
              .width('100%');
            }
            .width('100%')
            .padding({ bottom: 24 + this.bottomAvoidInset });
          }
          .width('100%')
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
