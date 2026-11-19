import { describe, expect, it } from '@ohos/hypium';
import {
  SESSION_ENDED_TEXT,
  SessionFailureFacts,
  describeSessionFailure,
  hasSessionFailureFacts,
  sessionFailureFactsFromEnvelope,
} from '../../../main/ets/pages/rustdesk/SessionFailureText';

export default function sessionFailureTextTest(): void {
  describe('SessionFailureTextTest', () => {
    it('reads the engine categories from a poll answer', 0, () => {
      const facts = sessionFailureFactsFromEnvelope(
        '{"ok":true,"error":"RendezvousFailed","rendezvous_failure":"offline","login_failure":null,"peer_close_reason":null}');
      expect(facts.rendezvousFailure).assertEqual('offline');
      expect(facts.error).assertEqual('RendezvousFailed');
      expect(facts.loginFailure).assertEqual('');
      expect(hasSessionFailureFacts(facts)).assertTrue();
    });

    it('carries no facts for an unreadable or empty answer', 0, () => {
      expect(hasSessionFailureFacts(sessionFailureFactsFromEnvelope('not json'))).assertFalse();
      expect(hasSessionFailureFacts(sessionFailureFactsFromEnvelope('null'))).assertFalse();
      expect(hasSessionFailureFacts(sessionFailureFactsFromEnvelope('{"ok":true,"error":null}'))).assertFalse();
    });

    it('names an offline peer and an unknown id differently', 0, () => {
      const offline = new SessionFailureFacts();
      offline.rendezvousFailure = 'offline';
      const unknown = new SessionFailureFacts();
      unknown.rendezvousFailure = 'id_not_exist';
      const offlineText = describeSessionFailure(offline, SESSION_ENDED_TEXT).text;
      const unknownText = describeSessionFailure(unknown, SESSION_ENDED_TEXT).text;
      expect(offlineText === unknownText).assertFalse();
      expect(offlineText === SESSION_ENDED_TEXT).assertFalse();
      expect(unknownText === SESSION_ENDED_TEXT).assertFalse();
    });

    it('offers a relay only when the direct route is what failed', 0, () => {
      const direct = new SessionFailureFacts();
      direct.rendezvousFailure = 'direct_failed';
      expect(describeSessionFailure(direct, SESSION_ENDED_TEXT).relayMayHelp).assertTrue();
      direct.rendezvousFailure = 'direct_handshake';
      expect(describeSessionFailure(direct, SESSION_ENDED_TEXT).relayMayHelp).assertTrue();
      direct.rendezvousFailure = 'relay_failed';
      expect(describeSessionFailure(direct, SESSION_ENDED_TEXT).relayMayHelp).assertFalse();
      direct.rendezvousFailure = 'offline';
      expect(describeSessionFailure(direct, SESSION_ENDED_TEXT).relayMayHelp).assertFalse();
    });

    it('prefers the route verdict, then the login verdict, then the peer close', 0, () => {
      const facts = new SessionFailureFacts();
      facts.loginFailure = 'refused';
      facts.peerCloseReason = 'manual_request';
      const refused = describeSessionFailure(facts, SESSION_ENDED_TEXT).text;
      facts.loginFailure = '';
      const manual = describeSessionFailure(facts, SESSION_ENDED_TEXT).text;
      expect(refused === manual).assertFalse();
      facts.rendezvousFailure = 'key_mismatch';
      facts.loginFailure = 'refused';
      const route = describeSessionFailure(facts, SESSION_ENDED_TEXT).text;
      expect(route === refused).assertFalse();
    });

    it('words a codec this device cannot decode the same way however the engine reports it', 0, () => {
      const viewer = new SessionFailureFacts();
      viewer.error = 'UnsupportedCodec';
      // What the engine's local decoder reports when it refuses a stream.
      const decoder = new SessionFailureFacts();
      decoder.error = 'Surface decoder: UnsupportedCodec';
      const viewerText = describeSessionFailure(viewer, SESSION_ENDED_TEXT).text;
      expect(viewerText === SESSION_ENDED_TEXT).assertFalse();
      expect(describeSessionFailure(decoder, SESSION_ENDED_TEXT).text).assertEqual(viewerText);
    });

    it('keeps the fallback when the engine named nothing it knows', 0, () => {
      const facts = new SessionFailureFacts();
      expect(describeSessionFailure(facts, SESSION_ENDED_TEXT).text).assertEqual(SESSION_ENDED_TEXT);
      facts.error = 'SomethingNew';
      expect(describeSessionFailure(facts, 'fallback').text).assertEqual('fallback');
      // An unknown rendezvous category is still a routed failure, not "ended".
      facts.rendezvousFailure = 'a_future_category';
      expect(describeSessionFailure(facts, SESSION_ENDED_TEXT).text === SESSION_ENDED_TEXT).assertFalse();
    });
  });
}
