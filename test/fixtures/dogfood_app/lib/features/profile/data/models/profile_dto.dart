import 'package:loja_app/features/profile/domain/entities/profile.dart';

/// DTO do endpoint `GET /profile`.
class ProfileDto {
  /// Cria o DTO.
  const ProfileDto({required this.name, required this.email});

  /// Lê o JSON do backend.
  factory ProfileDto.fromJson(Map<String, dynamic> json) =>
      ProfileDto(name: json['name'] as String, email: json['email'] as String);

  /// Nome de exibição.
  final String name;

  /// E-mail.
  final String email;

  /// Converte para a entidade de domínio.
  Profile toEntity() => Profile(name: name, email: email);
}
