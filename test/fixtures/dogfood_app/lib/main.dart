import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:loja_app/core/di/dependencies.dart';
import 'package:loja_app/features/profile/presentation/pages/profile_page.dart';

void main() {
  final deps = Dependencies(Dio(BaseOptions(baseUrl: 'https://api.loja.dev')));
  runApp(
    MaterialApp(
      home: Scaffold(
        body: BlocProvider(
          create: (_) {
            final cubit = deps.profileCubit();
            unawaited(cubit.load());
            return cubit;
          },
          child: const ProfilePage(),
        ),
      ),
    ),
  );
}
