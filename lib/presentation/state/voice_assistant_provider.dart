import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calimind/core/services/audio_recorder_service.dart';
import 'package:calimind/core/services/groq_service.dart';
import 'package:calimind/core/services/speech_recognition_service.dart';
import 'package:calimind/core/services/tts_service.dart';
import 'package:calimind/core/utils/haptic_feedback_utils.dart';
import 'package:calimind/domain/models/parsed_command.dart';
import 'package:calimind/domain/models/task.dart';
import 'package:calimind/domain/use_cases/parse_voice_command_use_case.dart';

enum VoiceState { idle, listening, processing, error }

class VoiceAssistantState {
  final VoiceState voiceState;
  final String interimTranscript;
  final String finalTranscript;
  final double soundLevel;
  final ParsedCommand? parsedCommand;
  final NewTask? draftTask;
  final String? errorMessage;
  final bool usedAiParser;

  const VoiceAssistantState({
    this.voiceState = VoiceState.idle,
    this.interimTranscript = '',
    this.finalTranscript = '',
    this.soundLevel = 0.0,
    this.parsedCommand,
    this.draftTask,
    this.errorMessage,
    this.usedAiParser = false,
  });

  VoiceAssistantState copyWith({
    VoiceState? voiceState,
    String? interimTranscript,
    String? finalTranscript,
    double? soundLevel,
    ParsedCommand? parsedCommand,
    NewTask? draftTask,
    String? errorMessage,
    bool? usedAiParser,
    bool clearError = false,
    bool clearDraft = false,
    bool clearParsedCommand = false,
  }) =>
      VoiceAssistantState(
        voiceState: voiceState ?? this.voiceState,
        interimTranscript: interimTranscript ?? this.interimTranscript,
        finalTranscript: finalTranscript ?? this.finalTranscript,
        soundLevel: soundLevel ?? this.soundLevel,
        parsedCommand:
            clearParsedCommand ? null : (parsedCommand ?? this.parsedCommand),
        draftTask: clearDraft ? null : (draftTask ?? this.draftTask),
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        usedAiParser: usedAiParser ?? this.usedAiParser,
      );
}

class VoiceAssistantNotifier extends StateNotifier<VoiceAssistantState> {
  late final SpeechRecognitionService _speech = SpeechRecognitionService();
  late final AudioRecorderService _recorder = AudioRecorderService();
  final GroqService _groq;
  late final TtsService _tts = TtsService();
  final VoiceParserUseCase _fallbackParser = VoiceParserUseCase();
  bool _isFinalizing = false;
  int _parseSequence = 0;
  bool _recordingAvailable = false;

  VoiceAssistantNotifier({GroqService? groq})
      : _groq = groq ?? GroqService(),
        super(const VoiceAssistantState());

  bool get isListening => state.voiceState == VoiceState.listening;

  Future<void> startListening({String? currentFocusRole}) async {
    if (state.voiceState == VoiceState.listening ||
        state.voiceState == VoiceState.processing ||
        _isFinalizing) {
      return;
    }
    await HapticFeedbackUtils.mediumImpact();

    state = state.copyWith(
      voiceState: VoiceState.listening,
      interimTranscript: '',
      finalTranscript: '',
      soundLevel: 0.0,
      clearError: true,
      clearDraft: true,
      clearParsedCommand: true,
      usedAiParser: false,
    );

    // Use one microphone pipeline at a time; the recorder and native speech
    // recognizer compete for microphone input on several Android devices.
    try {
      _recordingAvailable = await _recorder.startRecording() != null;
    } catch (error) {
      debugPrint('Could not start voice recording: $error');
      _recordingAvailable = false;
    }

    if (_recordingAvailable) return;

    final ok = await _speech.initialize();
    if (!ok) {
      state = state.copyWith(
        voiceState: VoiceState.error,
        errorMessage: 'Microphone or speech recognition not available.',
      );
      return;
    }

    await _speech.startListening(
      onResult: (words, isFinal) {
        if (isFinal) {
          state = state.copyWith(
            finalTranscript: words,
            interimTranscript: words,
          );
        } else {
          state = state.copyWith(interimTranscript: words);
        }
      },
      onSoundLevelChange: (level) {
        state =
            state.copyWith(soundLevel: ((level + 2.0) / 12.0).clamp(0.0, 1.0));
      },
    );
  }

  Future<void> stopListening({String? currentFocusRole}) async {
    await _finishCapture(currentFocusRole: currentFocusRole);
  }

  Future<void> _finishCapture({
    String? currentFocusRole,
  }) async {
    if (_isFinalizing) return;
    _isFinalizing = true;
    try {
      final wasRecording = _recordingAvailable;
      if (!wasRecording) await _speech.stopListening();
      final audioPath = await _recorder.stopRecording();
      state = state.copyWith(voiceState: VoiceState.processing);

      String capturedTranscript;
      if (wasRecording) {
        if (audioPath == null) {
          state = state.copyWith(
            voiceState: VoiceState.error,
            errorMessage:
                'The recording could not be opened. Please try speaking again.',
          );
          return;
        }
        try {
          final groqTranscript = await _groq.transcribeAudio(audioPath);
          if (groqTranscript == null || groqTranscript.trim().isEmpty) {
            state = state.copyWith(
              voiceState: VoiceState.error,
              errorMessage:
                  'I couldn’t transcribe that recording. Check your connection and try again.',
            );
            return;
          }
          capturedTranscript = groqTranscript.trim();
        } catch (error) {
          debugPrint('Groq voice transcription failed: $error');
          state = state.copyWith(
            voiceState: VoiceState.error,
            errorMessage:
                'I couldn’t transcribe that recording. Check your connection and try again.',
          );
          return;
        }
      } else {
        capturedTranscript = state.finalTranscript.trim().isNotEmpty
            ? state.finalTranscript.trim()
            : state.interimTranscript.trim();
      }

      if (capturedTranscript.isEmpty) {
        state = state.copyWith(
          voiceState: VoiceState.error,
          errorMessage:
              'I didn’t catch that. Tap the microphone and try again.',
        );
        return;
      }
      state = state.copyWith(finalTranscript: capturedTranscript);
      await processTranscript(
        capturedTranscript,
        currentFocusRole: currentFocusRole,
      );
    } catch (error) {
      debugPrint('Could not finish voice capture: $error');
      state = state.copyWith(
        voiceState: VoiceState.error,
        errorMessage: 'I couldn’t process that recording. Please try again.',
      );
    } finally {
      _isFinalizing = false;
      _recordingAvailable = false;
    }
  }

  Future<void> processTranscript(
    String transcript, {
    String? currentFocusRole,
  }  ) async {
    final requestSequence = ++_parseSequence;
    final cleanTranscript = transcript.trim();
    state = state.copyWith(
      voiceState: VoiceState.processing,
      finalTranscript: cleanTranscript,
    );

    ParsedCommand? command;
    var usedAi = false;
    var aiUnavailable = false;

    try {
      command = await _groq.parseVoiceCommandWithAI(
        cleanTranscript,
        currentFocusRole: currentFocusRole,
      );
      if (command != null) {
        usedAi = true;
      } else {
        aiUnavailable = true;
      }
    } catch (error) {
      debugPrint('Groq command parsing failed: $error');
      aiUnavailable = true;
    }

    if (command == null || command is UnknownCommand) {
      final fallbackCommand = _fallbackParser.parse(cleanTranscript);
      if (fallbackCommand is! UnknownCommand) {
        command = fallbackCommand;
        usedAi = false;
      }
    }
    if (requestSequence != _parseSequence) return;

    NewTask? draft;
    if (command is AddTaskCommand) {
      draft = command.task;
    }

    state = state.copyWith(
      voiceState: draft == null ? VoiceState.error : VoiceState.idle,
      parsedCommand: command,
      draftTask: draft,
      usedAiParser: usedAi,
      errorMessage: draft == null
          ? aiUnavailable
              ? 'The AI assistant could not be reached, and I could not structure that request. Check your connection and try again.'
              : _couldNotFindTaskMessage(cleanTranscript)
          : null,
      clearError: draft != null,
    );
  }

  String _couldNotFindTaskMessage(String transcript) {
    final excerpt =
        transcript.length > 80 ? '${transcript.substring(0, 77)}…' : transcript;
    return 'I heard “$excerpt” but couldn’t find an action to turn into a task. Try describing what you need to do in your own words.';
  }

  Future<void> speakConfirmation(String taskTitle) async {
    await HapticFeedbackUtils.heavyImpact();
    await _tts.speak('Added $taskTitle');
  }

  Future<void> speakScheduleReady(String summary) async {
    await _tts.speak(summary);
  }

  void updateDraftTask(NewTask updated) {
    state = state.copyWith(draftTask: updated);
  }

  void reset() {
    state = const VoiceAssistantState();
  }

  void dismiss() {
    _parseSequence++;
    state = state.copyWith(
      interimTranscript: '',
      finalTranscript: '',
      usedAiParser: false,
      clearDraft: true,
      clearParsedCommand: true,
    );
  }
}

final aventorVoiceServiceProvider =
    Provider<GroqService>((ref) => GroqService());

final voiceAssistantProvider =
    StateNotifierProvider<VoiceAssistantNotifier, VoiceAssistantState>(
  (ref) => VoiceAssistantNotifier(),
);
