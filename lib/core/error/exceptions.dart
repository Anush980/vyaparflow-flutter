abstract class Failure {
  final String message;
  final List<String> errors;

  const Failure({required this.message, this.errors = const []});
}

// For API / Server errors
class ServerFailure extends Failure {
  const ServerFailure({
    super.message = 'A server error occurred. Please try again later.',
    super.errors,
  });
}

// For local database / cache errors
class CacheFailure extends Failure {
  const CacheFailure({
    super.message = 'Failed to load or save data locally.',
    super.errors,
  });
}

// For unexpected crashes / connection timeouts
class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'Network connection failed. Please check your internet.',
    super.errors,
  });
}