import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:salahly/features/calls/domain/entities/call.dart';
import 'package:salahly/features/calls/domain/services/call_engine.dart';

/// The voice link over WebRTC. The audio goes straight between the two
/// phones when they can reach each other; otherwise a relay carries it.
class WebRtcCallEngine implements CallEngine {
  final _outgoing = StreamController<CallSignalDraft>.broadcast();
  final _link = StreamController<CallLink>.broadcast();
  final _early = <RTCIceCandidate>[];
  RTCPeerConnection? _peer;
  MediaStream? _microphone;
  bool _hasRemote = false;

  @override
  Stream<CallSignalDraft> get outgoing => _outgoing.stream;

  @override
  Stream<CallLink> get link => _link.stream;

  @override
  Future<bool> open(List<Map<String, dynamic>> iceServers) async {
    try {
      _microphone = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });
    } on Object {
      return false;
    }
    final RTCPeerConnection peer;
    try {
      peer = await createPeerConnection({'iceServers': iceServers});
      _peer = peer;
      for (final track in _microphone!.getAudioTracks()) {
        await peer.addTrack(track, _microphone!);
      }
    } on Object {
      return false;
    }
    peer
      ..onIceCandidate = (candidate) {
        final text = candidate.candidate;
        if (text == null || text.isEmpty) return;
        if (_outgoing.isClosed) return;
        _outgoing.add(
          CallSignalDraft(CallSignalKind.candidate, {
            'candidate': text,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          }),
        );
      }
      ..onIceConnectionState = (state) {
        switch (state) {
          case RTCIceConnectionState.RTCIceConnectionStateConnected:
          case RTCIceConnectionState.RTCIceConnectionStateCompleted:
            _emit(CallLink.connected);
          case RTCIceConnectionState.RTCIceConnectionStateFailed:
            _emit(CallLink.failed);
          case RTCIceConnectionState.RTCIceConnectionStateNew:
          case RTCIceConnectionState.RTCIceConnectionStateChecking:
          case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          case RTCIceConnectionState.RTCIceConnectionStateClosed:
          case RTCIceConnectionState.RTCIceConnectionStateCount:
            break;
        }
      }
      ..onConnectionState = (state) {
        switch (state) {
          case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
            _emit(CallLink.connected);
          case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
            _emit(CallLink.failed);
          case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
          case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
          case RTCPeerConnectionState.RTCPeerConnectionStateNew:
          case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
            break;
        }
      };
    return true;
  }

  @override
  Future<void> offer() async {
    final peer = _peer!;
    final description = await peer.createOffer({'offerToReceiveAudio': true});
    await peer.setLocalDescription(description);
    _outgoing.add(
      CallSignalDraft(CallSignalKind.offer, {
        'sdp': description.sdp,
        'type': description.type,
      }),
    );
  }

  @override
  Future<void> receive(CallSignal signal) async {
    final peer = _peer;
    if (peer == null) return;
    switch (signal.kind) {
      case CallSignalKind.offer:
        await peer.setRemoteDescription(_description(signal.payload));
        _hasRemote = true;
        await _flushEarly(peer);
        final answer = await peer.createAnswer();
        await peer.setLocalDescription(answer);
        _outgoing.add(
          CallSignalDraft(CallSignalKind.answer, {
            'sdp': answer.sdp,
            'type': answer.type,
          }),
        );
      case CallSignalKind.answer:
        await peer.setRemoteDescription(_description(signal.payload));
        _hasRemote = true;
        await _flushEarly(peer);
      case CallSignalKind.candidate:
        final candidate = RTCIceCandidate(
          signal.payload['candidate'] as String?,
          signal.payload['sdpMid'] as String?,
          signal.payload['sdpMLineIndex'] as int?,
        );
        if (_hasRemote) {
          await peer.addCandidate(candidate);
        } else {
          _early.add(candidate);
        }
    }
  }

  static RTCSessionDescription _description(Map<String, dynamic> payload) =>
      RTCSessionDescription(
        payload['sdp'] as String?,
        payload['type'] as String?,
      );

  /// Routes that arrived before the other side's description wait for it.
  Future<void> _flushEarly(RTCPeerConnection peer) async {
    for (final candidate in _early) {
      await peer.addCandidate(candidate);
    }
    _early.clear();
  }

  @override
  void setMuted({required bool muted}) {
    for (final track in _microphone?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = !muted;
    }
  }

  @override
  Future<void> setSpeaker({required bool on}) => Helper.setSpeakerphoneOn(on);

  void _emit(CallLink link) {
    if (!_link.isClosed) _link.add(link);
  }

  @override
  Future<void> close() async {
    // The peer goes first: its callbacks must not reach a closed stream.
    final peer = _peer;
    _peer = null;
    await peer?.close();
    await peer?.dispose();
    await _outgoing.close();
    await _link.close();
    for (final track in _microphone?.getTracks() ?? <MediaStreamTrack>[]) {
      await track.stop();
    }
    await _microphone?.dispose();
    _peer = null;
    _microphone = null;
  }
}
