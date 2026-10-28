import 'package:flutter_test/flutter_test.dart';
import 'package:loja_app/core/result/result.dart';
import 'package:loja_app/features/profile/domain/entities/profile.dart';
import 'package:loja_app/features/profile/domain/failures/profile_failure.dart';
import 'package:loja_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:loja_app/features/profile/domain/usecases/fetch_profile_use_case.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements ProfileRepository {}

void main() {
  test('delega ao repository', () async {
    final repository = _MockRepository();
    when(repository.fetchProfile).thenAnswer(
      (_) async => const Ok<Profile, ProfileFailure>(
        Profile(name: 'Ana', email: 'ana@loja.dev'),
      ),
    );

    final result = await FetchProfileUseCase(repository)();

    expect(result, isA<Ok<Profile, ProfileFailure>>());
    verify(repository.fetchProfile).called(1);
  });
}
