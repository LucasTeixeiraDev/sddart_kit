import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loja_app/core/result/result.dart';
import 'package:loja_app/features/profile/domain/entities/profile.dart';
import 'package:loja_app/features/profile/domain/failures/profile_failure.dart';
import 'package:loja_app/features/profile/domain/usecases/fetch_profile_use_case.dart';
import 'package:loja_app/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:mocktail/mocktail.dart';

class _MockUseCase extends Mock implements FetchProfileUseCase {}

void main() {
  late _MockUseCase useCase;

  setUp(() => useCase = _MockUseCase());

  blocTest<ProfileCubit, ProfileState>(
    'emite Loading e Success com o perfil',
    build: () {
      when(() => useCase()).thenAnswer(
        (_) async => const Ok<Profile, ProfileFailure>(
          Profile(name: 'Ana', email: 'ana@loja.dev'),
        ),
      );
      return ProfileCubit(useCase);
    },
    act: (cubit) => cubit.load(),
    expect: () => [
      const ProfileLoading(),
      isA<ProfileSuccess>().having((s) => s.profile.name, 'name', 'Ana'),
    ],
  );

  blocTest<ProfileCubit, ProfileState>(
    'emite Loading e Error com a falha',
    build: () {
      when(() => useCase()).thenAnswer(
        (_) async =>
            const Err<Profile, ProfileFailure>(ProfileNotFoundFailure()),
      );
      return ProfileCubit(useCase);
    },
    act: (cubit) => cubit.load(),
    expect: () => [
      const ProfileLoading(),
      isA<ProfileError>().having(
        (s) => s.failure,
        'failure',
        isA<ProfileNotFoundFailure>(),
      ),
    ],
  );
}
