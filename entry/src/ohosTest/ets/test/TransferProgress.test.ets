import { describe, expect, it } from '@ohos/hypium';
import { TransferProgress } from '../../../main/ets/pages/rustdesk/TransferProgress';
import { TransferItem } from '../../../main/ets/pages/rustdesk/RustDeskSessionTypes';

function activeTransfers(): TransferItem[] {
  return [
    {
      id: 1,
      fileNum: 0,
      direction: 'upload',
      sourcePath: 'a',
      destinationPath: 'b',
      fileName: 'a',
      totalBytes: 100,
      transferredBytes: 25,
      speedBytesPerSecond: 10,
      state: 'running',
      errorText: '',
    },
    {
      id: 2,
      fileNum: 0,
      direction: 'download',
      sourcePath: 'c',
      destinationPath: 'd',
      fileName: 'c',
      totalBytes: 300,
      transferredBytes: 75,
      speedBytesPerSecond: 30,
      state: 'running',
      errorText: '',
    },
  ];
}

export default function transferProgressTest(): void {
  describe('TransferProgressTest', () => {
    it('aggregates active transfer progress by bytes', 0, () => {
      const items = activeTransfers();
      expect(TransferProgress.percent(items)).assertEqual(25);
      expect(TransferProgress.activeCount(items)).assertEqual(2);
    });

    it('does not invent progress when active totals are unavailable', 0, () => {
      const items = activeTransfers();
      items[0].totalBytes = 0;
      items[1].totalBytes = 0;
      expect(TransferProgress.percent(items)).assertUndefined();
    });

    it('does not count completed failed or cancelled transfers as active', 0, () => {
      const items = activeTransfers();
      items[0].state = 'completed';
      items[1].state = 'failed';
      expect(TransferProgress.activeCount(items)).assertEqual(0);
    });
  });
}
