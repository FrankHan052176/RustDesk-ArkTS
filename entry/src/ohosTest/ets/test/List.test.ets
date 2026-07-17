import backgroundTaskStateTest from './BackgroundTaskState.test';
import chatStoreTest from './ChatStore.test';
import downloadRootManagerTest from './DownloadRootManager.test';
import pressedButtonStateTest from './RustDeskPressedButtonState.test';
import sessionDisplayControllerTest from './SessionDisplayController.test';
import sessionOverlayStateTest from './SessionOverlayState.test';
import sessionToolbarMetricsTest from './SessionToolbarMetrics.test';
import transferProgressTest from './TransferProgress.test';
import touchGestureStateTest from './RustDeskTouchGestureState.test';
import transferManagerTest from './TransferManager.test';
import viewportModelTest from './RustDeskViewportModel.test';

export default function testsuite(): void {
  backgroundTaskStateTest();
  chatStoreTest();
  downloadRootManagerTest();
  pressedButtonStateTest();
  sessionDisplayControllerTest();
  sessionOverlayStateTest();
  sessionToolbarMetricsTest();
  transferProgressTest();
  touchGestureStateTest();
  transferManagerTest();
  viewportModelTest();
}
