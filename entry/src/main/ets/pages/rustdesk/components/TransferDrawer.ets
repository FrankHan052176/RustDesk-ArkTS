import {
  HdsNavigation,
  HdsNavigationTitleMode,
  IconStyleMode,
  ScrollEffectType,
  hdsMaterial,
} from '@kit.UIDesignKit';
import { LocalFileEntry, RemoteFileEntry, TransferItem } from '../RustDeskSessionTypes';
import { RemoteFilePath } from '../RemoteFilePath';
import { FloatingDepthOverlay } from './FloatingDepth';
import { FloatingActionSurface, FloatingGlassSurface } from './FloatingSurface';

type TransferPrimaryPane = 'local' | 'remote';

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
  @Local compactLayout: boolean = true;
  @Local threePaneLayout: boolean = false;
  @Local primaryPane: TransferPrimaryPane = 'remote';
  @Local transferSheetVisible: boolean = false;
  private transferSheetScroller: Scroller = new Scroller();
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

  private shouldUseCompactLayout(width: number): boolean {
    return width < 920;
  }

  private shouldUseThreePaneLayout(width: number): boolean {
    return width >= 1280;
  }

  private paneGap(): number {
    return 12;
  }

  private halfPaneGap(): number {
    return this.paneGap() / 2;
  }

  private paneWidth(): number {
    if (this.compactLayout) {
      return this.viewportWidth;
    }
    if (this.threePaneLayout) {
      return Math.max(1, (this.viewportWidth - this.paneGap() * 2) / 3);
    }
    return Math.max(1, (this.viewportWidth - this.paneGap()) / 2);
  }

  private compactPeekWidth(): number {
    return Math.max(40, this.viewportWidth * 0.1);
  }

  private localPaneContentRightPadding(): number {
    if (!this.compactLayout || this.primaryPane === 'remote') {
      return this.compactLayout ? this.halfPaneGap() : 0;
    }
    return this.compactPeekWidth() + this.halfPaneGap();
  }

  private remotePaneContentLeftPadding(): number {
    return this.compactLayout ? this.halfPaneGap() : 0;
  }

  private remotePaneContentRightPadding(): number {
    if (!this.compactLayout) {
      return 0;
    }
    return this.compactPeekWidth();
  }

  private localPaneOffset(): number {
    if (!this.compactLayout || this.primaryPane === 'local') {
      return 0;
    }
    return -(this.viewportWidth - this.compactPeekWidth());
  }

  private remotePaneOffset(): number {
    if (!this.compactLayout) {
      return this.paneWidth() + this.paneGap();
    }
    return this.primaryPane === 'remote'
      ? this.compactPeekWidth()
      : this.viewportWidth - this.compactPeekWidth();
  }

  private transferPaneOffset(): number {
    return (this.paneWidth() + this.paneGap()) * 2;
  }

  private transferTrayHeight(): number {
    return 132;
  }

  private switchPrimaryPane(pane: TransferPrimaryPane): void {
    if (!this.compactLayout || this.primaryPane === pane) {
      return;
    }
    this.getUIContext().animateTo({
      duration: 320,
      curve: Curve.FastOutSlowIn,
    }, (): void => {
      this.primaryPane = pane;
    });
  }

  private updateViewportWidth(width: number): void {
    if (width <= 0 || Math.abs(width - this.viewportWidth) < 0.5) {
      return;
    }
    const nextCompactLayout = this.shouldUseCompactLayout(width);
    const nextThreePaneLayout = this.shouldUseThreePaneLayout(width);
    if (nextCompactLayout === this.compactLayout && nextThreePaneLayout === this.threePaneLayout) {
      this.viewportWidth = width;
      return;
    }
    this.getUIContext().animateTo({
      duration: 300,
      curve: Curve.FastOutSlowIn,
    }, (): void => {
      this.viewportWidth = width;
      this.compactLayout = nextCompactLayout;
      this.threePaneLayout = nextThreePaneLayout;
    });
  }

  private recentTransfers(limit: number): TransferItem[] {
    const recent: TransferItem[] = [];
    for (let index = this.transfers.length - 1; index >= 0 && recent.length < limit; index -= 1) {
      recent.push(this.transfers[index]);
    }
    return recent;
  }

  private summaryTransferLimit(): number {
    return this.compactLayout ? 1 : 2;
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
    if (key === 'all-transfers') {
      return this.transfers.length > 0;
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
  private LocalEntry(entry: LocalFileEntry) {
    Stack() {
      FloatingActionSurface({
        actionEnabled: true,
        compact: true,
        subtleDepth: true,
        stopTouchPropagation: true,
        accessibilityLabel: entry.name,
        onActivate: (): void => this.onSelectLocal(entry.name),
      }) {
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
        .borderRadius($r('app.float.radius_14'))
        .clip(true);
      }
    }
    .width('100%')
    .height($r('app.float.control_large'))
    .borderRadius($r('app.float.radius_14'))
    .clip(false);
  }

  @Builder
  private RemoteEntry(entry: RemoteFileEntry) {
    Stack() {
      FloatingActionSurface({
        actionEnabled: true,
        compact: true,
        subtleDepth: true,
        stopTouchPropagation: true,
        accessibilityLabel: this.isDirectory(entry) ? `打开文件夹 ${entry.name}` : entry.name,
        onActivate: (): void => {
          if (this.isDirectory(entry)) {
            this.onOpenRemoteDirectory(entry.name);
          } else {
            this.onSelectRemote(entry.name);
          }
        },
      }) {
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
        .borderRadius($r('app.float.radius_14'))
        .clip(true);
      }
    }
    .width('100%')
    .height($r('app.float.control_large'))
    .borderRadius($r('app.float.radius_14'))
    .clip(false);
  }

  @Builder
  private TransferRow(item: TransferItem, showDivider: boolean) {
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
    .border({ width: { bottom: showDivider ? 0.5 : 0 }, color: $r('app.color.divider') });
  }

  @Builder
  private TransferSummaryRow(item: TransferItem) {
    Column({ space: $r('app.float.space_4') }) {
      Text(`${item.direction === 'upload' ? '上传' : '下载'} · ${item.fileName}`)
        .width('100%')
        .fontSize($r('app.float.font_body'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
      Text(this.transferDetail(item))
        .width('100%')
        .fontSize($r('app.float.font_caption'))
        .fontColor($r('app.color.text_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
      if ((item.state === 'queued' || item.state === 'running') && item.totalBytes > 0) {
        Progress({
          value: this.transferProgressValue(item),
          total: item.totalBytes,
          type: ProgressType.Linear,
        })
          .width('100%')
          .height(4)
          .color($r('app.color.brand_primary'))
          .backgroundColor($r('app.color.surface_secondary'));
      }
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
    .padding({
      left: $r('app.float.space_12'),
      right: $r('app.float.space_12'),
      top: $r('app.float.space_8'),
      bottom: $r('app.float.space_8'),
    });
  }

  @Builder
  private LocalEntriesList() {
    List({ space: 8 }) {
      ForEach(this.localEntries, (entry: LocalFileEntry) => {
        ListItem() {
          this.LocalEntry(entry);
        }
        .width('100%')
        .clip(false)
      }, (entry: LocalFileEntry) => entry.path)
      if (this.localEntries.length === 0) {
        ListItem() {
          Text('下载位置中没有可直接上传的文件')
            .width('100%')
            .fontSize($r('app.float.font_body'))
            .fontColor($r('app.color.text_secondary'))
            .textAlign(TextAlign.Center)
            .padding($r('app.float.space_20'));
        }
      }
    }
    .width('100%')
    .height('100%')
    .padding({
      left: $r('app.float.space_8'),
      right: $r('app.float.space_8'),
      top: $r('app.float.space_12'),
      bottom: $r('app.float.space_12'),
    })
    .clip(false)
    .clipContent(ContentClipMode.BOUNDARY)
    .scrollBar(BarState.Off)
    .alignListItem(ListItemAlign.Start);
  }

  @Builder
  private LocalPaneContent(fillAvailable: boolean) {
    Row({ space: $r('app.float.space_8') }) {
      Text('本机文件')
        .fontSize($r('app.float.font_body_large'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      .layoutWeight(1)

      if (this.compactLayout) {
        this.FloatingAction('show-remote', '远端', false, (): void => this.switchPrimaryPane('remote'))
      }
      this.FloatingAction('upload', '上传', true, () => this.onUpload())
    }
    .width('100%')
    .padding({ right: $r('app.float.space_16') })
    .alignItems(VerticalAlign.Center);

    Stack() {
      FloatingGlassSurface({
        compact: true,
        inset: true,
        radius: $r('app.float.radius_10'),
        surfaceHeight: 34,
      }) {
        Row() {
          Text(this.downloadRootPath.length > 0 ? this.downloadRootPath : '未选择下载位置')
            .layoutWeight(1)
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
        }
          .width('100%')
          .height(34)
          .padding({ left: $r('app.float.space_12'), right: $r('app.float.space_12') })
          .alignItems(VerticalAlign.Center);
      }
    }
    .width('100%')
    .height(34)
    .margin({ top: $r('app.float.space_6'), bottom: $r('app.float.space_6') })
    .clip(false);

    Stack({ alignContent: Alignment.TopStart }) {
      FloatingDepthOverlay({
        inset: true,
        radius: $r('app.float.radius_14'),
      });
      this.LocalEntriesList();
    }
    .height(fillAvailable ? 0 : 176)
    .layoutWeight(fillAvailable ? 1 : 0)
    .width('100%')
    .backgroundColor($r('app.color.transparent'))
    .borderRadius($r('app.float.radius_14'))
    .clip(false);
  }

  @Builder
  private RemoteEntriesList() {
    List({ space: 8 }) {
      ForEach(this.remoteEntries, (entry: RemoteFileEntry) => {
        ListItem() {
          this.RemoteEntry(entry);
        }
        .width('100%')
        .clip(false)
      }, (entry: RemoteFileEntry) => `${entry.entry_type}-${entry.name}`)
      if (this.remoteEntries.length === 0) {
        ListItem() {
          Text('远端目录为空或正在加载')
            .width('100%')
            .fontSize($r('app.float.font_body'))
            .fontColor($r('app.color.text_secondary'))
            .textAlign(TextAlign.Center)
            .padding($r('app.float.space_20'));
        }
      }
    }
    .width('100%')
    .height('100%')
    .padding({
      left: $r('app.float.space_8'),
      right: $r('app.float.space_8'),
      top: $r('app.float.space_12'),
      bottom: $r('app.float.space_12'),
    })
    .clip(false)
    .clipContent(ContentClipMode.BOUNDARY)
    .scrollBar(BarState.Off)
    .alignListItem(ListItemAlign.Start);
  }

  @Builder
  private RemotePaneContent(fillAvailable: boolean) {
    Row({ space: $r('app.float.space_8') }) {
      Text('远端文件')
        .fontSize($r('app.float.font_body_large'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      .layoutWeight(1)

      if (this.compactLayout) {
        this.FloatingAction('show-local', '本机', false, (): void => this.switchPrimaryPane('local'))
      }
      this.FloatingAction('remote-back', '上级', false, () => this.onRemoteBack())
      this.FloatingAction('download', '下载', true, () => this.onDownload())
    }
    .width('100%')
    .padding({ right: $r('app.float.space_16') })
    .alignItems(VerticalAlign.Center);

    Stack() {
      FloatingGlassSurface({
        compact: true,
        inset: true,
        radius: $r('app.float.radius_10'),
        surfaceHeight: 34,
      }) {
        Row() {
          Text(this.remoteDirectory)
            .layoutWeight(1)
            .fontSize($r('app.float.font_caption'))
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
        }
          .width('100%')
          .height(34)
          .padding({ left: $r('app.float.space_12'), right: $r('app.float.space_12') })
          .alignItems(VerticalAlign.Center);
      }
    }
    .width('100%')
    .height(34)
    .margin({ top: $r('app.float.space_6'), bottom: $r('app.float.space_6') })
    .clip(false);

    Stack({ alignContent: Alignment.TopStart }) {
      FloatingDepthOverlay({
        inset: true,
        radius: $r('app.float.radius_14'),
      });
      this.RemoteEntriesList();
    }
    .height(fillAvailable ? 0 : 176)
    .layoutWeight(fillAvailable ? 1 : 0)
    .width('100%')
    .backgroundColor($r('app.color.transparent'))
    .borderRadius($r('app.float.radius_14'))
    .clip(false);
  }

  @Builder
  private TransferRowsContent() {
    Column() {
      ForEach(this.transfers, (item: TransferItem) => {
        this.TransferRow(item, true);
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
  private TransferSummaryContent() {
    if (this.transfers.length === 0) {
      Row() {
        Text('暂无传输任务')
          .fontSize($r('app.float.font_body'))
          .fontColor($r('app.color.text_secondary'));
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: $r('app.float.space_16'), right: $r('app.float.space_16') })
      .alignItems(VerticalAlign.Center);
    } else {
      Row({ space: this.paneGap() }) {
        ForEach(this.recentTransfers(this.summaryTransferLimit()), (item: TransferItem) => {
          this.TransferSummaryRow(item);
        }, (item: TransferItem) =>
          `summary-${item.id}-${item.fileNum}-${item.state}-${Math.round(item.transferredBytes)}`)
        if (!this.compactLayout && this.transfers.length < 2) {
          Blank()
            .layoutWeight(1);
        }
      }
      .width('100%')
      .layoutWeight(1)
      .alignItems(VerticalAlign.Top);
    }
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
      .align(Alignment.TopStart)
      .scrollBar(BarState.Off);
    } else {
      this.TransferRowsContent();
    }
  }

  @Builder
  private TransferTray() {
    Column() {
      Row({ space: $r('app.float.space_8') }) {
        Text('传输任务')
          .layoutWeight(1)
          .fontSize($r('app.float.font_body'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'));
        this.FloatingAction('all-transfers', '全部', false, (): void => {
          this.transferSheetVisible = true;
        })
      }
      .width('100%')
      .height(56)
      .padding({ left: $r('app.float.space_16'), right: $r('app.float.space_16') })
      .alignItems(VerticalAlign.Center);

      this.TransferSummaryContent();
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'));
  }

  @Builder
  private AllTransfersSheet() {
    HdsNavigation() {
      Scroll(this.transferSheetScroller) {
        Column() {
          this.TransferRowsContent();
        }
        .width('100%')
        .padding({
          left: $r('app.float.space_20'),
          right: $r('app.float.space_20'),
          top: $r('app.float.space_8'),
          bottom: $r('app.float.space_24'),
        })
        .backgroundColor($r('app.color.neu_base'));
      }
      .width('100%')
      .height('100%')
      .align(Alignment.TopStart)
      .clip(false)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .nestedScroll({
        scrollForward: NestedScrollMode.PARENT_FIRST,
        scrollBackward: NestedScrollMode.SELF_FIRST,
      })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM]);
    }
    .mode(NavigationMode.Stack)
    .titleMode(HdsNavigationTitleMode.MODAL)
    .hideBackButton(true)
    .titleBar({
      enableComponentSafeArea: true,
      content: {
        title: {
          mainTitle: '全部传输任务',
        },
        menu: {
          value: [{
            content: {
              label: '关闭',
              icon: $r('sys.symbol.xmark'),
              type: IconStyleMode.SMALL,
              action: (): void => {
                this.transferSheetVisible = false;
              },
            },
          }],
        },
      },
      style: {
        scrollEffectOpts: {
          enableScrollEffect: false,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE,
        },
      },
    })
    .bindToScrollable([this.transferSheetScroller])
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.neu_base'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM]);
  }

  @Builder
  private LocalWorkspacePane() {
    Column() {
      this.LocalPaneContent(true);
    }
    .width(this.paneWidth())
    .height('100%')
    .padding({
      left: 0,
      right: this.localPaneContentRightPadding(),
      top: $r('app.float.space_20'),
      bottom: $r('app.float.space_8'),
    })
    .backgroundColor($r('app.color.background'))
    .translate({ x: this.localPaneOffset() })
    .renderGroup(true)
    .animation({ duration: 320, curve: Curve.FastOutSlowIn });
  }

  @Builder
  private RemoteWorkspacePane() {
    Column() {
      this.RemotePaneContent(true);
    }
    .width(this.paneWidth())
    .height('100%')
    .padding({
      left: this.remotePaneContentLeftPadding(),
      right: this.remotePaneContentRightPadding(),
      top: $r('app.float.space_20'),
      bottom: $r('app.float.space_8'),
    })
    .backgroundColor($r('app.color.background'))
    .translate({ x: this.remotePaneOffset() })
    .renderGroup(true)
    .animation({ duration: 320, curve: Curve.FastOutSlowIn });
  }

  @Builder
  private TransferWorkspacePane() {
    Column() {
      this.TransferPaneContent(true);
    }
    .width(this.paneWidth())
    .height('100%')
    .padding({
      left: $r('app.float.space_8'),
      right: $r('app.float.space_8'),
      top: $r('app.float.space_20'),
      bottom: $r('app.float.space_8'),
    })
    .backgroundColor($r('app.color.background'))
    .translate({ x: this.transferPaneOffset() })
    .renderGroup(true)
    .animation({ duration: 320, curve: Curve.FastOutSlowIn });
  }

  @Builder
  private FileWorkspace() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.LocalWorkspacePane();
      this.RemoteWorkspacePane();
      if (this.threePaneLayout) {
        this.TransferWorkspacePane();
      }
    }
    .width('100%')
    .height('100%')
    .clip(true);
  }

  build() {
    Column() {
      Blank()
        .width('100%')
        .height(this.titleSpacerHeight)
        .flexShrink(0);

      Column() {
        Stack() {
          this.FileWorkspace();
        }
        .layoutWeight(1)
        .width('100%')
        .clip(true);

        if (!this.threePaneLayout) {
          Column()
            .width('100%')
            .height(1)
            .backgroundColor($r('app.color.divider'));

          Column() {
            this.TransferTray();
          }
          .width('100%')
          .height(this.transferTrayHeight())
          .animation({ duration: 260, curve: Curve.FastOutSlowIn });
        }
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ bottom: this.bottomAvoidInset });
    }
    .width('100%')
    .height('100%')
    .layoutWeight(1)
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      const width = Number(newArea.width);
      this.updateViewportWidth(width);
    })
    .bindSheet(this.transferSheetVisible!!, this.AllTransfersSheet(), {
      height: SheetSize.LARGE,
      preferType: SheetType.CENTER,
      showClose: false,
      dragBar: false,
      enableFloatingDragBar: false,
      backgroundColor: $r('app.color.neu_base'),
    });
  }
}
