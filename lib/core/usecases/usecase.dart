
// T is the return type and params is what it takes
abstract class UseCase<T, Params> {
  Future<T> call(Params params);
}

// used when getall api is called and similar
abstract class NoParamUseCase<T> {
  Future<T> call();
}
