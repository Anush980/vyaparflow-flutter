import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:vyaparflow_flutter/core/common/constants/api_endpoints.dart';
import '../error/exceptions.dart';
import 'token_store.dart';

class DioClient {

  late final Dio dio;
  
  final String baseUrl = dotenv.env['BACKEND_API_URL'] ?? "http://localhost:8080/api";

  // Constructor initializes Dio and attaches global configurations and interceptors.
  DioClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10), 
        receiveTimeout: const Duration(seconds: 10),
        headers: {"Content-Type": "application/json"},
      ),
    );

    // Add custom interceptors to handle outgoing requests and incoming errors globally.
    dio.interceptors.add(
      InterceptorsWrapper(
        
        onRequest: (options, handler) async {
          
          final requiresAuth = options.extra['auth'] ?? true;
          
          if (requiresAuth) {
           
            final token = await TokenStore.getAccessToken();
            
            if (token != null) {
              options.headers["Authorization"] = "Bearer $token";
            }
          }
          
          return handler.next(options);
        },
        
       
        onError: (DioException e, handler) async {
          
         
          if (e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout) {
          
            return handler.next(
              DioException(
                requestOptions: e.requestOptions,
                error: const NetworkFailure(),
              ),
            );
          }

         
          if (e.response?.statusCode == 401 && (e.requestOptions.extra['auth'] ?? true)) {
            try {
             
              final refreshed = await _tryRefreshToken();
              
              if (refreshed) {
                
                final newToken = await TokenStore.getAccessToken();
                
                e.requestOptions.headers["Authorization"] = "Bearer $newToken";
                
                
                final clonedRequest = await dio.fetch(e.requestOptions);
               
                return handler.resolve(clonedRequest);
              } else {
               
                await TokenStore.clear();
               
                return handler.next(
                  DioException(
                    requestOptions: e.requestOptions,
                    error: const ServerFailure(message: "Session expired. Please log in again."),
                  ),
                );
              }
            } catch (_) {
              // If a network drop occurs during the refresh token request
              return handler.next(
                DioException(
                  requestOptions: e.requestOptions,
                  error: const NetworkFailure(message: "Can't reach server during token refresh."),
                ),
              );
            }
          }

          
          final responseData = e.response?.data;
          if (responseData is Map<String, dynamic>) {
            final message = responseData['message'] ?? 'Request failed';
           
            final errors = responseData['error'] != null 
                ? List<String>.from(responseData['error']) 
                : <String>[];

            // Wrap backend response error into a clean ServerFailure.
            return handler.next(
              DioException(
                requestOptions: e.requestOptions,
                error: ServerFailure(
                  message: message,
                  errors: errors,
                ),
              ),
            );
          }

          // Fallback: pass any unhandled error through as-is.
          return handler.next(e);
        },
      ),
    );
  }


  Future<bool> _tryRefreshToken() async {
    try {
     
      final refreshToken = await TokenStore.getRefreshToken();
      if (refreshToken == null) return false;

      // Create a separate, plain Dio instance to prevent infinite interceptor loops
      final plainDio = Dio(BaseOptions(baseUrl: baseUrl));

      // Send the refresh token to the backend auth endpoint
      final response = await plainDio.post(
        ApiEndpoints.version+ApiEndpoints.refreshToken,
        data: {'refreshToken': refreshToken},
      );

      // Check if the backend successfully issued a new token pair.
      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        if (data?['accessToken'] != null && data?['refreshToken'] != null) {
          // Save the new tokens securely into device storage.
          await TokenStore.setTokens(data['accessToken'], data['refreshToken']);
          return true; // Refresh successful
        }
      }
      return false; // Refresh failed
    } catch (_) {
      return false;
    }
  }
}