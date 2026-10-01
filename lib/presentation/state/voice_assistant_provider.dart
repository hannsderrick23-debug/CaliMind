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
  }) =>
      VoiceAssistantState(
        voiceState: voiceState ?? this.voiceState,
        interimTranscript: interimTranscript ?? this.interimTranscript,
        finalTranscript: finalTranscript ?? this.finalTranscript,
        soundLevel: soundLevel ?? this.soundLevel,
        parsedCommand: parsedCommand ?? this.parsedCommand,
        draftTask: draftTask ?? this.draftTask,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        usedAiParser: usedAiParser ?? this.usedAiParser,
      );
}

class VoiceAssistantNotifier extends StateNotifier<VoiceAssistantState> {
  final SpeechRecognitionService _speech = SpeechRecognitionService();
  final AudioRecorderService _recorder = AudioRecorderService();
  final GroqService _groq = GroqService();
  final TtsService _tts = TtsService();
  final VoiceParserUseCase _fallbackParser = VoiceParserUseCase();

  VoiceAssistantNotifier() : super(const VoiceAssistantState());

  bool get isListening => state.voiceState == VoiceState.listening;

  Future<void> startListening({String? currentFocusRole}) async {
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
      usedAiParser: false,
    );

    // Concurrently start high-fidelity recorder for Groq Whisper
    await _recorder.startRecording();

    final ok = await _speech.initialize();
    if (!ok) {
      // SpeechToText not available on some environments (e.g. desktop/simulator without mic dictation)
      // Check if recorder is active - if so, user can still speak and transcribe via Groq
      if (_recorder.isRecording) {
        state = state.copyWith(
          interimTranscript: 'Listening with Groq Whisper...',
        );
        return;
      }

      state = state.copyWith(
        voiceState: VoiceState.error,
        errorMessage: 'Microphone or speech recognition not available.',
      );
      return;
    }

    await _speech.startListening(
      onResult: (words, isFinal) {
        if (isFinal) {
          _onFinalTranscript(words, currentFocusRole: currentFocusRole);
        } else {
          state = state.copyWith(interimTranscript: words);
        }
      },
      onSoundLevelChange: (level) {
        state = state.copyWith(soundLevel: ((level + 2.0) / 12.0).clamp(0.0, 1.0));
      },
    );
  }

  Future<void> stopListening({String? currentFocusRole}) async {
    await _speech.stopListening();
    final audioPath = await _recorder.stopRecording();

    state = state.copyWith(voiceState: VoiceState.processing);

    String transcript = state.interimTranscript;

    // If Groq API key is configured, transcribe audio with Whisper for maximum precision
    if (audioPath != null) {
      final groqTranscript = await _groq.transcribeAudio(audioPath);
      if (groqTranscript != null && groqTranscript.isNotEmpty) {
        transcript = groqTranscript;
      }
    }

    if (transcript.isNotEmpty) {
      await _onFinalTranscript(transcript, currentFocusRole: currentFocusRole);
    } else {
      state = state.copyWith(voiceState: VoiceState.idle);
    }
  }

  Future<void> _onFinalTranscript(
    String transcript, {
    String? currentFocusRole,
  }) async {
    state = state.copyWith(
      voiceState: VoiceState.processing,
      finalTranscript: transcript,
    );

    ParsedCommand? command;
    var usedAi = false;

    // 1. Try intelligent Groq LLaMA 3.3 parsing
    try {
      command = await _groq.parseVoiceCommandWithAI(
        transcript,
        currentFocusRole: currentFocusRole,
      );
      if (command != null) {
        usedAi = true;
      }
    } catch (_) {}

    // 2. Fallback to deterministic regex parser if offline or API key absent
    command ??= _fallbackParser.parse(transcript);

    NewTask? draft;
    if (command is AddTaskCommand) {
      draft = command.task;
    }

    state = state.copyWith(
      voiceState: VoiceState.idle,
      parsedCommand: command,
      draftTask: draft,
      usedAiParser: usedAi,
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
      usedAiParser: false,
    );
  }
}

final groqServiceProvider = Provider<GroqService>((ref) => GroqService());

final voiceAssistantProvider =
    StateNotifierProvider<VoiceAssistantNotifier, VoiceAssistantState>(
  (ref) => VoiceAssistantNotifier(),
);
