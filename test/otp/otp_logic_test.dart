import 'package:craft_kit/craft_kit.dart';
import 'package:craft_kit/src/otp/logic/otp_input_coordinator.dart';
import 'package:craft_kit/src/otp/logic/otp_state_machine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OtpInputCoordinator.normalizeDigits', () {
    final c = OtpInputCoordinator(length: 6, allowPaste: true);

    test('strips separators', () {
      expect(c.normalizeDigits('123 456'), '123456');
      expect(c.normalizeDigits('12-34-56'), '123456');
    });

    test('finds a standalone code inside a message', () {
      expect(c.normalizeDigits('Order 22, code 654321'), '654321');
      expect(c.normalizeDigits('Your code is 482913.'), '482913');
    });

    test('truncates to length and drops letters', () {
      expect(c.normalizeDigits('1234567890'), '123456');
      expect(c.normalizeDigits('ab12cd'), '12');
    });

    test('converts Arabic-Indic and Persian digits', () {
      expect(c.normalizeDigits('١٢٣۴۵۶'), '123456');
    });

    test('reports deletion and paste-like edits', () {
      final u = c.handleRawText(previousCode: '123', rawText: '12');
      expect(u.isDeletion, isTrue);
      final p = c.handleRawText(previousCode: '', rawText: '123456');
      expect(p.isPasteLike, isTrue);
    });
  });

  group('OtpStateMachine', () {
    test('caps the code at length and tracks completion', () {
      final m = OtpStateMachine(length: 4)..markEntering();
      m.settleAfterEntrance();
      m.applyCode('12');
      expect(m.state.phase, OtpPhase.editing);
      m.applyCode('123456');
      expect(m.state.code, '1234');
      expect(m.state.phase, OtpPhase.complete);
      expect(m.state.isComplete, isTrue);
    });

    test('ignores edits while busy', () {
      final m = OtpStateMachine(length: 4)..applyCode('1234');
      m.markCollapsing();
      m.applyCode('9');
      expect(m.state.code, '1234');
      expect(m.state.phase.isBusy, isTrue);
    });

    test('failure restore can keep or clear the code', () {
      final m = OtpStateMachine(length: 4)..applyCode('1234');
      m.markFailure();
      m.restore(keepCode: false);
      expect(m.state.code, '');
      expect(m.state.phase, OtpPhase.editing);
    });

    test('focused index follows the next empty box', () {
      final m = OtpStateMachine(length: 4)
        ..updateFocus(true)
        ..applyCode('12');
      expect(m.state.focusedIndex, 2);
      m.applyCode('1234');
      expect(m.state.focusedIndex, 3);
    });
  });

  group('OtpCodeController (detached)', () {
    test('holds and sanitizes a code without a field', () {
      final c = OtpCodeController();
      var notified = 0;
      c.addListener(() => notified++);
      c.setCode('12ab34');
      expect(c.code, '1234');
      c.clear();
      expect(c.code, '');
      expect(notified, 2);
      c.dispose();
    });

    test('initial code is sanitized', () {
      final c = OtpCodeController(initialCode: '9x8');
      expect(c.code, '98');
      c.dispose();
    });
  });

  test('OtpStyle.copyWith keeps untouched values', () {
    final s = const OtpStyle().copyWith(boxWidth: 60);
    expect(s.boxWidth, 60);
    expect(s.gap, const OtpStyle().gap);
  });
}
