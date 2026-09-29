/// A growing toolkit of Flutter UI helpers.
///
/// Features:
/// * Remembered emails: [RememberedEmailStore], [EmailFieldController],
///   [EmailSuggestionEngine], [RememberedEmailField].
/// * OTP input: [OtpCodeField] and [OtpCodeController].
/// * Swipeable cards: [SwipeCardStack], [SwipeCardController], per-direction
///   [SwipeBehavior]s, spring physics ([SwipePhysics]) and custom stack looks
///   ([SwipeStackLayout]).
library;

export 'src/email/email_input_formatter.dart';
export 'src/email/email_validator.dart';
export 'src/email/logic/email_field_controller.dart';
export 'src/email/logic/email_suggestion_engine.dart';
export 'src/email/logic/remembered_email_entry.dart';
export 'src/email/logic/remembered_email_store.dart';
export 'src/email/widgets/email_suggestions_view.dart';
export 'src/email/widgets/remembered_email_field.dart';
export 'src/otp/animation/otp_animation_spec.dart';
export 'src/otp/controller/otp_code_controller.dart' hide OtpCodeFieldHandle;
export 'src/otp/logic/otp_phase.dart';
export 'src/otp/style/otp_haptics.dart';
export 'src/otp/style/otp_labels.dart';
export 'src/otp/style/otp_style.dart';
export 'src/otp/widgets/otp_code_field.dart';
export 'src/storage/craft_storage.dart';
export 'src/swipe_card/engine/swipe_genie.dart';
export 'src/swipe_card/engine/swipe_math.dart';
export 'src/swipe_card/engine/swipe_moves.dart';
export 'src/swipe_card/swipe_behavior.dart';
export 'src/swipe_card/swipe_card_controller.dart' hide SwipeHandle;
export 'src/swipe_card/swipe_card_stack.dart' hide debugLiveGenieImages;
export 'src/swipe_card/swipe_direction.dart';
export 'src/swipe_card/swipe_haptics.dart';
export 'src/swipe_card/swipe_intent_overlay.dart';
export 'src/swipe_card/swipe_layout.dart';
export 'src/swipe_card/swipe_physics.dart';
export 'src/swipe_card/swipe_progress.dart';
export 'src/swipe_card/swipe_reaction.dart';
export 'src/swipe_card/swipe_stamp_overlay.dart';
