import 'package:calimind/data/datasources/profile_remote_datasource.dart';
import 'package:calimind/domain/models/profile.dart';

class ProfileRepositoryImpl {
  final ProfileRemoteDatasource _datasource;

  ProfileRepositoryImpl({ProfileRemoteDatasource? datasource})
      : _datasource = datasource ?? ProfileRemoteDatasourceImpl();

  Future<PrivacyProfile> getProfile() => _datasource.fetchProfile();

  Future<PrivacyProfile> updateProfile(PrivacyProfile profile) =>
      _datasource.updateProfile(profile);
}
