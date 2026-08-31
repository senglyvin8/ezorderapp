import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_qr_ordering/data/backend/supabase_backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Telling "this database is older than this build" apart from "the database
/// said no".
///
/// The app and the schema are deployed separately, so there is no moment when
/// both are certainly in step. A build that sends an argument the database has
/// not got does not degrade on its own: PostgREST resolves functions by
/// argument name, fails to find any match, and every order in the restaurant is
/// refused. That failure has to be recognised and worked around, and it must
/// not be confused with a refusal, which has to be passed straight through.
void main() {
  test('a missing function signature is recognised', () {
    // What PostgREST returns for place_order with p_client_key against a
    // schema that predates 0013.
    const error = PostgrestException(
      message: 'Could not find the function public.place_order('
          'p_client_key, p_items, p_note, p_restaurant_id, p_table_id, p_type)',
      code: 'PGRST202',
    );
    expect(SupabaseBackend.isMissingSignature(error), isTrue);
  });

  test('a refusal from inside the function is not', () {
    // A dish that sold out, a table that does not exist, a suspended
    // merchant. Retrying these differently would be wrong — they are answers.
    for (final code in ['P0001', '23505', '42501', '42703']) {
      final error = PostgrestException(message: 'X is sold out', code: code);
      expect(SupabaseBackend.isMissingSignature(error), isFalse,
          reason: 'code $code is the database answering, not a bad signature');
    }
  });

  test('an error with no code at all is not treated as a signature problem',
      () {
    const error = PostgrestException(message: 'something went wrong');
    expect(SupabaseBackend.isMissingSignature(error), isFalse);
  });
}
