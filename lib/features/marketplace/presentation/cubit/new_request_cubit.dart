import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/serialization/wire.dart';
import 'package:salahly/core/speech/speech_input.dart';
import 'package:salahly/core/text/text_limit.dart';
import 'package:salahly/features/catalog/domain/entities/service_category.dart';
import 'package:salahly/features/marketplace/domain/entities/consumer_address.dart';
import 'package:salahly/features/marketplace/domain/entities/request_draft.dart';
import 'package:salahly/features/marketplace/domain/entities/request_issue.dart';
import 'package:salahly/features/marketplace/domain/entities/request_window.dart';
import 'package:salahly/features/marketplace/domain/entities/technician_card.dart';
import 'package:salahly/features/marketplace/domain/repositories/consumer_requests_repository.dart';

part 'new_request_state.dart';

/// Asks for a technician in three steps: the problem (typed or said, with
/// photos), the address, and the day and time; then sends the request.
///
/// Photos upload only when sending. One that uploaded before a send failed
/// isn't uploaded again on the next try.
class NewRequestCubit extends Cubit<NewRequestState> {
  NewRequestCubit({
    required this._requests,
    required this._speech,
    this._categoryId,
    this._technicianId,
    this._clock = DateTime.now,
  }) : super(NewRequestState(now: _clock()));

  /// The longest description the server takes.
  static const maxDescriptionLength = 1000;

  /// The most photos a request takes.
  static const maxPhotos = 4;

  final ConsumerRequestsRepository _requests;
  final SpeechInput _speech;
  final DateTime Function() _clock;

  /// The category the form was opened for, if any.
  final String? _categoryId;

  /// Someone the consumer hired before, asked first.
  final String? _technicianId;

  /// Storage paths of photos already uploaded, by their path on the phone.
  final _uploaded = <String, String>{};

  /// Fetches the address book and, when asking someone again, who they are.
  Future<void> start() async {
    final technicianId = _technicianId;
    await Future.wait([
      loadAddresses(),
      if (technicianId != null) _loadTechnician(technicianId),
    ]);
  }

  /// Takes the catalog's categories: the one asked for while it is open
  /// (and, when asking a technician, one they work in), else the first one
  /// that is.
  void useCategories(List<ServiceCategory> categories) {
    final open = [
      for (final category in categories)
        if (category.isActive) category,
    ];
    final next = state.copyWith(categories: open);
    final choices = next.categoryChoices;
    final category =
        choices.where((category) => category.id == _categoryId).firstOrNull ??
        choices
            .where((category) => category.id == state.category?.id)
            .firstOrNull ??
        choices.firstOrNull;
    emit(category == null ? next : _withCategory(next, category));
  }

  /// Picks the trade; the problem picked for another trade is dropped.
  void selectCategory(ServiceCategory category) {
    if (state.categoryChoices.contains(category)) {
      emit(_withCategory(state, category));
    }
  }

  static NewRequestState _withCategory(
    NewRequestState state,
    ServiceCategory category,
  ) {
    final next = state.copyWith(category: category);
    return next.issue != null &&
            !next.issueChoices.any(
              (choice) => choice.issue == next.issue,
            )
        ? next.copyWith(issue: () => null)
        : next;
  }

  Future<void> _loadTechnician(String id) async {
    final result = await _requests.fetchListedTechnician(id);
    if (isClosed) return;
    // Without the profile the request goes out like any other: it only
    // goes to a technician first once the form names them.
    if (result case Ok(value: final profile?)) {
      emit(
        state.copyWith(
          technician: profile.card,
          technicianServiceIds: {
            for (final service in profile.services) service.serviceId,
          },
        ),
      );
      // The trade may have to change to one this technician works in.
      useCategories(state.categories);
    }
  }

  void selectIssue(RequestIssue issue) =>
      emit(state.copyWith(issue: () => issue));

  /// The description as typed. Typing takes over from dictation.
  void editDescription(String text) {
    final wasListening = state.isListening;
    emit(state.copyWith(description: text, isListening: false));
    if (wasListening) unawaited(_speech.stop());
  }

  /// Starts dictation, adding what is said after what is written, or
  /// stops it. Returns false when the phone cannot take dictation.
  Future<bool> toggleListening() async {
    if (state.isListening) {
      await stopListening();
      return true;
    }
    final written = state.description.trimRight();
    emit(state.copyWith(isListening: true));
    final listening = await _speech.listen(
      onWords: (words) {
        if (isClosed || !state.isListening) return;
        final heard = words.trim();
        final text = [
          if (written.isNotEmpty) written,
          if (heard.isNotEmpty) heard,
        ].join(' ');
        emit(
          state.copyWith(
            description: clipToCodePoints(text, maxDescriptionLength),
          ),
        );
      },
    );
    if (!listening && !isClosed) emit(state.copyWith(isListening: false));
    return listening;
  }

  Future<void> stopListening() async {
    if (!state.isListening) return;
    emit(state.copyWith(isListening: false));
    await _speech.stop();
  }

  /// Adds a photo picked on the phone, up to [maxPhotos].
  void addPhoto(String path) {
    if (state.photos.length >= maxPhotos) return;
    emit(state.copyWith(photos: [...state.photos, path]));
  }

  void removePhoto(String path) => emit(
    state.copyWith(
      photos: [
        for (final photo in state.photos)
          if (photo != path) photo,
      ],
    ),
  );

  /// Fetches the address book, picking the first address unless one is
  /// picked already.
  Future<void> loadAddresses() async {
    emit(state.copyWith(addressesFailed: false));
    final result = await _requests.fetchAddresses();
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            addresses: value,
            addressId: state.addressId ?? value.firstOrNull?.id,
          ),
        );
      case Err():
        emit(state.copyWith(addressesFailed: true));
    }
  }

  void selectAddress(String id) => emit(state.copyWith(addressId: id));

  /// Saves a new address to the address book and picks it. Returns why
  /// saving failed, if it did.
  Future<Failure?> addAddress(ConsumerAddressDraft draft) async {
    final result = await _requests.saveAddress(draft);
    if (isClosed) return null;
    switch (result) {
      case Ok(:final value):
        final address = ConsumerAddress(
          id: value,
          label: draft.label,
          areaId: draft.areaId,
          details: draft.details,
        );
        emit(
          state.copyWith(
            addresses: [...?state.addresses, address],
            addressesFailed: false,
            addressId: value,
          ),
        );
        return null;
      case Err(:final failure):
        return failure;
    }
  }

  /// Picks the day, when a window on it can still be asked for, dropping
  /// a picked window that can't.
  void selectDay(DateTime day) {
    final checked = _withClock();
    if (!checked.days.contains(day) || !checked.hasOpenWindow(day)) {
      emit(checked);
      return;
    }
    final window = checked.window;
    emit(
      checked.copyWith(
        day: () => day,
        window: () =>
            window != null && checked.isOpen(day, window) ? window : null,
      ),
    );
  }

  /// Picks the time window, when it can still be asked for on the day.
  void selectWindow(RequestWindow window) {
    final checked = _withClock();
    final day = checked.day;
    emit(
      day == null || checked.isOpen(day, window)
          ? checked.copyWith(window: () => window)
          : checked,
    );
  }

  /// The state with the clock read again, dropping a day that can't be
  /// asked for anymore, and a window that is over on the day kept.
  NewRequestState _withClock() {
    final checked = state.copyWith(now: _clock());
    final day = checked.day;
    final window = checked.window;
    final dayOpen =
        day != null && checked.days.contains(day) && checked.hasOpenWindow(day);
    return checked.copyWith(
      day: () => dayOpen ? day : null,
      window: () => dayOpen && window != null && !checked.isOpen(day, window)
          ? null
          : window,
    );
  }

  /// Moves to the next step once this one is filled in, or marks what is
  /// missing. The last step sends the request.
  Future<void> next() async {
    switch (state.step) {
      case NewRequestStep.problem:
        if (!state.problemDone) {
          emit(state.copyWith(showsErrors: true));
          return;
        }
        await stopListening();
        emit(
          state.copyWith(step: NewRequestStep.address, showsErrors: false),
        );
      case NewRequestStep.address:
        emit(
          state.addressDone
              ? _withClock().copyWith(
                  step: NewRequestStep.time,
                  showsErrors: false,
                )
              : state.copyWith(showsErrors: true),
        );
      case NewRequestStep.time:
        await send();
    }
  }

  /// Goes back a step. Returns false on the first step, where going back
  /// leaves the form.
  bool back() {
    if (state.isSending || state.step == NewRequestStep.problem) return false;
    emit(
      state.copyWith(
        step: NewRequestStep.values[state.step.index - 1],
        showsErrors: false,
      ),
    );
    return true;
  }

  /// Uploads the photos and sends the request.
  Future<void> send() async {
    if (state.isSending || state.status == NewRequestStatus.sent) return;
    final checked = _withClock();
    final category = checked.category;
    final issue = checked.issue;
    final address = checked.address;
    final day = checked.day;
    final window = checked.window;
    if (!checked.timeDone ||
        category == null ||
        issue == null ||
        address == null ||
        day == null ||
        window == null) {
      emit(checked.copyWith(showsErrors: true));
      return;
    }
    emit(
      checked.copyWith(
        status: NewRequestStatus.uploading,
        uploaded: 0,
        failure: () => null,
        isListening: false,
      ),
    );
    if (checked.isListening) await _speech.stop();
    if (isClosed) return;
    final photoPaths = <String>[];
    for (final photo in state.photos) {
      final path = _uploaded[photo] ?? await _upload(photo);
      if (isClosed || path == null) return;
      photoPaths.add(path);
      emit(state.copyWith(uploaded: photoPaths.length));
    }
    emit(state.copyWith(status: NewRequestStatus.sending));
    final description = state.description.trim();
    final result = await _requests.sendRequest(
      RequestDraft(
        categoryId: category.id,
        issue: issue,
        description: description.isEmpty ? null : description,
        photoPaths: photoPaths,
        addressId: address.id,
        day: day,
        window: window,
        technicianId: state.technician?.id,
      ),
    );
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(status: NewRequestStatus.sent, sent: value));
      case Err(:final failure):
        _fail(failure);
    }
  }

  /// The photo's storage path, or null after reporting why it failed.
  Future<String?> _upload(String photo) async {
    final result = await _requests.uploadPhoto(photo);
    if (isClosed) return null;
    switch (result) {
      case Ok(:final value):
        return _uploaded[photo] = value;
      case Err(:final failure):
        _fail(failure);
        return null;
    }
  }

  void _fail(Failure failure) => emit(
    state.copyWith(status: NewRequestStatus.failed, failure: () => failure),
  );

  @override
  Future<void> close() async {
    if (state.isListening) await _speech.stop();
    return super.close();
  }
}
