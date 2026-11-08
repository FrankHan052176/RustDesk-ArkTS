import { describe, expect, it } from '@ohos/hypium';
import { ApprovedServerProfile, ServerConfig } from '../../../main/ets/pages/rustdesk/RustDeskDirectoryTypes';
import {
  RememberedPasswordBinding,
  RememberedPasswordState,
  rememberedPasswordIdentity,
} from '../../../main/ets/pages/rustdesk/RememberedPasswordState';
import { ActionResponse, NativeEvent } from '../../../main/ets/pages/rustdesk/RustDeskTypes';

function profile(server: string, revision: number = 1): ApprovedServerProfile {
  const config = new ServerConfig();
  config.mode = 'custom';
  config.idServer = server;
  config.relayServer = 'relay.example.test';
  config.key = 'synthetic-public-key';
  return new ApprovedServerProfile(config, revision);
}

function binding(sessionId: string = 'session-a', epoch: string = '11', dial: number = 1,
  target: string = '198.51.100.8'): RememberedPasswordBinding {
  return new RememberedPasswordBinding(sessionId, `core-${sessionId}`, epoch, dial, target);
}

function reply(owner: RememberedPasswordBinding, authenticated: boolean = false,
  events: NativeEvent[] = []): ActionResponse {
  return {
    ok: true,
    action: 'session_poll_events',
    authenticated,
    events,
    session: {
      sessionId: owner.sessionId,
      coreSessionId: owner.coreSessionId,
      lifecycleEpoch: owner.lifecycleEpoch,
      target: owner.target,
      kind: 'rustdesk',
      phase: authenticated ? 'streaming' : 'authenticating',
    },
  };
}

function queuedReply(owner: RememberedPasswordBinding, queued: boolean = true): ActionResponse {
  const result = reply(owner);
  result.action = 'session_login';
  result.queued = queued;
  return result;
}

export default function rememberedPasswordTest(): void {
  describe('RememberedPasswordTest', () => {
    it('separates actual RustDesk routes and excludes temporary or other-protocol credentials', 0, () => {
      const direct = rememberedPasswordIdentity('remote_control', '198.51.100.8', 'ip', undefined, false);
      const first = rememberedPasswordIdentity('remote_control', '123456789', 'target', profile('one.example.test'), false);
      const second = rememberedPasswordIdentity('remote_control', '123456789', 'target', profile('two.example.test'), false);
      expect(direct.length > 0).assertTrue();
      expect(first.length > 0 && first !== second).assertTrue();
      expect(rememberedPasswordIdentity('remote_control', '123456789', 'target', profile('one.example.test', 2), false))
        .assertEqual(first);
      const changedKey = new ServerConfig();
      changedKey.mode = 'custom';
      changedKey.idServer = 'one.example.test';
      changedKey.relayServer = 'relay.example.test';
      changedKey.key = 'different-public-key';
      expect(rememberedPasswordIdentity('remote_control', '123456789', 'target',
        new ApprovedServerProfile(changedKey, 3), false) !== first).assertTrue();
      expect(rememberedPasswordIdentity('remote_control', '198.51.100.8', 'target', profile('one.example.test'), false)
        !== direct).assertTrue();
      expect(rememberedPasswordIdentity('remote_control', '123456789', 'target', undefined, false)).assertEqual('');
      expect(rememberedPasswordIdentity('remote_control', '123456789', 'target', profile('one.example.test'), true))
        .assertEqual('');
      expect(rememberedPasswordIdentity('rdp', '198.51.100.8', 'ip', undefined, false)).assertEqual('');
      expect(rememberedPasswordIdentity('vnc', '198.51.100.8', 'ip', undefined, false)).assertEqual('');
      expect(rememberedPasswordIdentity('file_transfer', '123456789', 'target', profile('one.example.test'), false))
        .assertEqual('');
    });

    it('saves exactly once only after an admitted password and real poll authentication', 0, () => {
      const state = new RememberedPasswordState();
      const owner = binding();
      state.begin(owner, 'identity-a', false);
      state.choose(owner, true);
      const queued = queuedReply(owner);
      state.queued(owner, 'synthetic-password-a', queued);
      expect(state.observe(queued) === undefined).assertTrue();
      const ready = reply(owner, false, [{ name: 'connection_ready' }, { name: 'peer_info' }]);
      expect(state.observe(ready) === undefined).assertTrue();
      const success = reply(owner, true);
      const effect = state.observe(success);
      expect(effect?.kind).assertEqual('save');
      expect(effect?.identity).assertEqual('identity-a');
      expect(effect?.password).assertEqual('synthetic-password-a');
      expect(state.observe(success) === undefined).assertTrue();
    });

    it('never saves a refused or unchecked answer, and unchecking removes the old target asset', 0, () => {
      const state = new RememberedPasswordState();
      const owner = binding();
      state.begin(owner, 'identity-a', true);
      state.choose(owner, true);
      state.queued(owner, 'synthetic-refused', queuedReply(owner, false));
      expect(state.observe(reply(owner, true)) === undefined).assertTrue();
      state.begin(owner, 'identity-a', true);
      const forget = state.choose(owner, false);
      expect(forget?.kind).assertEqual('remove');
      expect(forget?.identity).assertEqual('identity-a');
      state.queued(owner, 'synthetic-unchecked', queuedReply(owner));
      expect(state.observe(reply(owner, true)) === undefined).assertTrue();
      expect(state.rememberChoice(owner.sessionId)).assertFalse();
    });

    it('rejects stale session/core/lifecycle/target and previous dial submissions', 0, () => {
      const state = new RememberedPasswordState();
      const owner = binding();
      state.begin(owner, 'identity-a', false);
      state.choose(owner, true);
      state.queued(binding('session-a', '11', 99), 'synthetic-stale-dial', queuedReply(owner));
      expect(state.observe(reply(owner, true)) === undefined).assertTrue();
      state.begin(owner, 'identity-a', false);
      state.choose(owner, true);
      state.queued(owner, 'synthetic-current', queuedReply(owner));
      expect(state.observe(reply(binding('session-b'), true)) === undefined).assertTrue();
      expect(state.observe(reply(binding('session-a', '10'), true)) === undefined).assertTrue();
      expect(state.observe(reply(binding('session-a', '11', 1, '198.51.100.9'), true)) === undefined).assertTrue();
      const wrongCore = new RememberedPasswordBinding('session-a', 'other-core', '11', 1, owner.target);
      expect(state.observe(reply(wrongCore, true)) === undefined).assertTrue();
      const wrongWire = reply(owner, true);
      if (wrongWire.session !== undefined) {
        wrongWire.session.kind = 'rdp';
      }
      expect(state.observe(wrongWire) === undefined).assertTrue();
      expect(state.observe(reply(owner, true))?.password).assertEqual('synthetic-current');
    });

    it('keeps background tabs candidates and choices isolated from the active target', 0, () => {
      const state = new RememberedPasswordState();
      const first = binding();
      const second = binding('session-b', '12', 2, '198.51.100.9');
      state.begin(first, 'identity-route-one', false);
      state.choose(first, true);
      state.queued(first, 'synthetic-first', queuedReply(first));
      state.begin(second, 'identity-route-two', false);
      state.choose(second, false);
      state.queued(second, 'synthetic-second', queuedReply(second));
      expect(state.observe(reply(second, true)) === undefined).assertTrue();
      const backgroundSuccess = state.observe(reply(first, true));
      expect(backgroundSuccess?.identity).assertEqual('identity-route-one');
      expect(backgroundSuccess?.password).assertEqual('synthetic-first');
      expect(state.rememberChoice(first.sessionId)).assertTrue();
      expect(state.rememberChoice(second.sessionId)).assertFalse();
    });

    it('invalidates a wrong remembered password and waits for a new manual queued answer', 0, () => {
      const state = new RememberedPasswordState();
      const owner = binding();
      // A saved password was read once into sessionAdd; no pending copy is held.
      state.begin(owner, 'identity-a', true);
      const rejected = reply(owner, false, [{ name: 'msgbox', type: 're-input-password' }]);
      const forget = state.observe(rejected);
      expect(forget?.kind).assertEqual('remove');
      expect(forget?.identity).assertEqual('identity-a');
      expect(forget?.password).assertEqual('');
      expect(state.observe(reply(owner, false, [{ name: 'msgbox', type: 'input-password' }])) === undefined).assertTrue();
      state.choose(owner, true);
      state.queued(owner, 'synthetic-corrected', queuedReply(owner));
      expect(state.observe(reply(owner, true))?.password).assertEqual('synthetic-corrected');
    });

    it('retains an admitted password across the mandatory second factor without saving early', 0, () => {
      const state = new RememberedPasswordState();
      const owner = binding();
      state.begin(owner, 'identity-a', false);
      state.choose(owner, true);
      state.queued(owner, 'synthetic-with-2fa', queuedReply(owner));
      expect(state.observe(reply(owner, false, [{ name: 'msgbox', type: 'input-2fa' }])) === undefined).assertTrue();
      expect(state.observe(reply(owner, true))?.password).assertEqual('synthetic-with-2fa');
    });

    it('drops uncommitted secrets on background and removes owners at close before late success', 0, () => {
      const state = new RememberedPasswordState();
      const owner = binding();
      state.begin(owner, 'identity-a', true);
      state.choose(owner, true);
      state.queued(owner, 'synthetic-before-background', queuedReply(owner));
      state.clearPending();
      expect(state.observe(reply(owner, true)) === undefined).assertTrue();
      state.begin(owner, 'identity-a', false);
      state.choose(owner, true);
      state.queued(owner, 'synthetic-before-close', queuedReply(owner));
      state.forget(owner.sessionId);
      expect(state.observe(reply(owner, true)) === undefined).assertTrue();
      state.begin(owner, 'identity-a', true);
      state.choose(owner, true);
      state.queued(owner, 'synthetic-terminal', queuedReply(owner));
      const terminal = reply(owner, true, [{ name: 'close' }]);
      terminal.closed = true;
      expect(state.observe(terminal) === undefined).assertTrue();
      expect(state.canRemember(owner.sessionId)).assertFalse();
    });
  });
}
