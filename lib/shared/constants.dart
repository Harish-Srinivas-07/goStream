import 'package:package_info_plus/package_info_plus.dart';

import '../models/movie.dart';

List<String> favouriteMovieIds = [];
List<Movie> topMovies = [];
List<String> recentWatchIds = [];
PackageInfo packageInfo = PackageInfo(
  appName: 'Go Stream',
  packageName: 'com.hivemind.gostream',
  version: '1.0.0',
  buildNumber: 'h07',
);
