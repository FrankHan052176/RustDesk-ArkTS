import chatStoreTest from './ChatStore.test';
import downloadRootManagerTest from './DownloadRootManager.test';
import pressedButtonStateTest from './RustDeskPressedButtonState.test';
import rustDeskPeerDirectoryModelTest from './RustDeskPeerDirectoryModel.test';
import rustDeskImeInputControllerTest from './RustDeskImeInputController.test';
import remoteSessionOrientationPolicyTest from './RemoteSessionOrientationPolicy.test';
import remoteSessionHandoffServiceTest from './RemoteSessionHandoffService.test';
import remoteSessionTabsControllerTest from './RemoteSessionTabsController.test';
import sessionDisplayControllerTest from './SessionDisplayController.test';
import sessionOverlayStateTest from './SessionOverlayState.test';
import sessionToolbarMetricsTest from './SessionToolbarMetrics.test';
import transferProgressTest from './TransferProgress.test';
import touchGestureStateTest from './RustDeskTouchGestureState.test';
import transferManagerTest from './TransferManager.test';
import viewportModelTest from './RustDeskViewportModel.test';

export default function testsuite(): void {
  chatStoreTest();
  downloadRootManagerTest();
  pressedButtonStateTest();
  rustDeskPeerDirectoryModelTest();
  rustDeskImeInputControllerTest();
  remoteSessionOrientationPolicyTest();
  remoteSessionHandoffServiceTest();
  remoteSessionTabsControllerTest();
  sessionDisplayControllerTest();
  sessionOverlayStateTest();
  sessionToolbarMetricsTest();
  transferProgressTest();
  touchGestureStateTest();
  transferManagerTest();
  viewportModelTest();
}
