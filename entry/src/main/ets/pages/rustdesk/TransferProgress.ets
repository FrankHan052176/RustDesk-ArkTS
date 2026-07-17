import { TransferItem } from './RustDeskSessionTypes';

function isActiveTransfer(item: TransferItem): boolean {
  return item.state === 'queued' || item.state === 'running' || item.state === 'awaiting_override';
}

export class TransferProgress {
  public static percent(items: TransferItem[]): number | undefined {
    let totalBytes = 0;
    let transferredBytes = 0;
    for (let index = 0; index < items.length; index += 1) {
      const item = items[index];
      if (!isActiveTransfer(item) || !Number.isFinite(item.totalBytes) || item.totalBytes <= 0) {
        continue;
      }
      totalBytes += item.totalBytes;
      transferredBytes += Math.min(Math.max(item.transferredBytes, 0), item.totalBytes);
    }
    if (totalBytes <= 0) {
      return undefined;
    }
    return Math.round((transferredBytes * 100) / totalBytes);
  }

  public static activeCount(items: TransferItem[]): number {
    let count = 0;
    for (let index = 0; index < items.length; index += 1) {
      if (isActiveTransfer(items[index])) {
        count += 1;
      }
    }
    return count;
  }

}
