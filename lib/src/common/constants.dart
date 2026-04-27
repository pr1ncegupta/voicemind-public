import 'package:flutter/material.dart';

const String kBackendUrl = String.fromEnvironment(
  'BACKEND_URL',
  defaultValue: 'http://localhost:8000',
);

const List<String> kCrisisKeywords = [
  'suicide',
  'suicidal',
  'kill myself',
  'kill me',
  'end it all',
  'end it',
  'no reason to live',
  'better off dead',
  'want to die',
  "don't want to live",
  'want to disappear',
  'ending my life',
  'end my life',
  'take my life',
  'take my own life',
  'end my existence',
  'suicide plan',
  'hurt myself',
  'self harm',
  'self-harm',
  'cut myself',
  'overdose',
  "don't want to be alive",
  "can't go on",
  "can't go on anymore",
  'no hope left',
  'give up',
  'jump off',
  'hang myself',
  'rather be dead',
  'wish i was dead',
  "life isn't worth",
  'not worth living',
  'nothing to live for',
  'everyone would be better',
];

class HelplineEntry {
  final String region;
  final String name;
  final String number;
  final String telUri;

  const HelplineEntry({
    required this.region,
    required this.name,
    required this.number,
    required this.telUri,
  });
}

const List<HelplineEntry> kIndiaHelplines = [
  HelplineEntry(region: 'India', name: 'AASRA', number: '91-9820466726', telUri: 'tel:+919820466726'),
  HelplineEntry(region: 'India', name: 'Vandrevala Foundation', number: '1860-2662-345', telUri: 'tel:18602662345'),
  HelplineEntry(region: 'India', name: 'iCall', number: '91-22-25521111', telUri: 'tel:+912225521111'),
  HelplineEntry(region: 'India', name: 'NIMHANS', number: '080-46110007', telUri: 'tel:08046110007'),
  HelplineEntry(region: 'India', name: 'Sneha India', number: '91-44-24640050', telUri: 'tel:+914424640050'),
];

const List<HelplineEntry> kInternationalHelplines = [
  HelplineEntry(region: 'International', name: '988 Suicide & Crisis Lifeline (US)', number: '988', telUri: 'tel:988'),
  HelplineEntry(region: 'International', name: 'Samaritans (UK)', number: '116 123', telUri: 'tel:116123'),
  HelplineEntry(region: 'International', name: 'Lifeline (Australia)', number: '13 11 14', telUri: 'tel:131114'),
  HelplineEntry(region: 'International', name: 'Crisis Services Canada', number: '1-833-456-4566', telUri: 'tel:18334564566'),
];

const HelplineEntry kPrimaryHelplineUs = HelplineEntry(
  region: 'International',
  name: 'Call 988 Lifeline (US)',
  number: '988',
  telUri: 'tel:988',
);

const HelplineEntry kPrimaryHelplineIndia = HelplineEntry(
  region: 'India',
  name: 'Call AASRA (India)',
  number: '91-9820466726',
  telUri: 'tel:+919820466726',
);

const Color kBrandPrimary = Color(0xFFD97757);

/// Shared TTS warm-voice setup used across Talk, Coping, and Wellness screens.
/// Picks the best available natural voice on each platform.
Future<void> configureTtsVoice(dynamic tts) async {
  await tts.setLanguage("en-US");
  await tts.setSpeechRate(0.5);
  await tts.setPitch(0.92);
  try {
    final voices = await tts.getVoices;
    if (voices != null && voices is List) {
      final enVoices = voices
          .where((v) =>
              v is Map &&
              ((v['locale'] as String?)?.startsWith('en') ?? false))
          .toList();
      const preferred = [
        'Samantha (Enhanced)',
        'Samantha',
        'Zoe (Enhanced)',
        'Zoe',
        'Karen (Enhanced)',
        'Karen',
        'Moira (Enhanced)',
        'Moira',
        'Tessa (Enhanced)',
        'Tessa',
        'en-us-x-sfg#female_2-local',
        'en-us-x-sfg#female_1-local',
        'en-us-x-tpc#female_2-local',
      ];
      for (final pref in preferred) {
        final match = enVoices.firstWhere(
          (v) => v is Map && (v['name'] as String?) == pref,
          orElse: () => null,
        );
        if (match != null && match is Map) {
          tts.setVoice({
            "name": match['name'] as String,
            "locale": match['locale'] as String,
          });
          break;
        }
      }
    }
  } catch (_) {}
}
