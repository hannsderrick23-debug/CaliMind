import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/speech_recognition_service.dart';
import '../../core/services/tts_service.dart';
import '../../core/utils/haptic_feedback_utils.dart';
import '../../domain/models/parsed_command.dart';
import '../../domain/models/task.dart';
import '../../domain/use_cases/parse_voice_command_use_case.dart';

enum VoiceState { idle, listening, processing, error }

class VoiceAssistantState {
  final VoiceState voiceState;
  final String interimTranscript;
  final String finalTranscript;
  final double soundLevel;
  final ParsedCommand? parsedCommand;
  final NewTask? draftTask;
  final String? errorMessage;

  const VoiceAssistantState({
    this.voiceState = VoiceState.idle,
    this.interimTranscript = '',
    this.finalTranscript = '',
    this.soundLevel = 0.0,
    this.parsedCommand,
    this.draftTask,
    this.errorMessage,
  });

  VoiceAssistantState copyWith({
    VoiceState? voiceState,
    String? interimTranscript,
    String? finalTranscript,
    double? soundLevel,
    ParsedCommand? parsedCommand,
    NewTask? draftTask,
    String? errorMessage,
    bool clearError = false,
  }) =>
      VoiceAssistantState(
        voiceState: voiceState ?? this.voiceState,
        interimTranscript: interimTranscript ?? this.interimTranscript,
        finalTranscript: finalTranscript ?? this.finalTranscript,
        soundLevel: soundLevel ?? this.soundLevel,
        parsedCommand: parsedCommand ?? this.parsedCommand,
        draftTask: draftTask ?? this.draftTask,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      );
}

class VoiceAssistantNotifier extends StateNotifier<VoiceAssistantState> {
  final SpeechRecognitionService _speech = SpeechRecognitionService();
  final TtsService _tts = TtsService();
  final VoiceParserUseCase _parser = VoiceParserUseCase();

  VoiceAssistantNotifier() : super(const VoiceAssistantState());

  bool get isListening => state.voiceState == VoiceState.listening;

  Future<void> startListening() async {
    if (state.voiceState == VoiceState.listening) return;
    await HapticFeedbackUtils.mediumImpact();

    state = state.copyWith(
      voiceState: VoiceState.listening,
      interimTranscript: '',
      finalTranscript: '',
      soundLevel: 0.0,
      parsedCommand: null,
      draftTask: null,
      clearError: true,
    );

    final ok = await _speech.initialize();
    if (!ok) {
      state = state.copyWith(
        voiceState: VoiceState.error,
        errorMessage: 'Speech recognition not available on this device.',
      );
      return;
    }

    await _speech.startListening(
      onResult: (words, isFinal) {
        if (isFinal) {
          _onFinalTranscript(words);
        } else {
          state = state.copyWith(interimTranscript: words);
        }
      },
      onSoundLevelChange: (level) {
        state = state.copyWith(soundLevel: (level + 2.0) / 12.0); // normalize 0..1
      },
    );
  }

  Future<void> stopListening() async {
    await _speech.stopListening();
    if (state.voiceState == VoiceState.listening && state.interimTranscript.isNotEmpty) {
      _onFinalTranscript(state.interimTranscript);
    } else if (state.voiceState == VoiceState.listening) {
      state = state.copyWith(voiceState: VoiceState.idle);
    }
  }

  void _onFinalTranscript(String transcript) {
    state = state.copyWith(
      voiceState: VoiceState.processing,
      finalTranscript: transcript,
    );
    final command = _parser.parse(transcript);
    
    NewTask? draft;
    if (command is AddTaskCommand) {
      draft = command.task;
    }

    state = state.copyWith(
      voiceState: VoiceState.idle,
      parsedCommand: command,
      draftTask: draft,
    );
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
    state = state.copyWith(
      parsedCommand: null,
      draftTask: null,
      interimTranscript: '',
      finalTranscript: '',
    );
  }
}

final voiceAssistantProvider =
    StateNotifierProvider<VoiceAssistantNotifier, VoiceAssistantState>(
  (ref) => VoiceAssistantNotifier(),
);
