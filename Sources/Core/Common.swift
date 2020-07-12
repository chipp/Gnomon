//
//  Created by Vladimir Burdukov on 7/6/16.
//  Copyright © 2016 NetcoSports. All rights reserved.
//

import Foundation
import RxSwift

extension HTTPURLResponse {

  private static var cacheFlagKey = "X-ResultFromHttpCache"

  var httpCachedResponse: HTTPURLResponse? {
    guard let url = url else { return nil }
    var headers = allHeaderFields as? [String: String] ?? [:]
    headers[HTTPURLResponse.cacheFlagKey] = "true"
    return HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: headers)
  }

  var resultFromHTTPCache: Bool {
    guard let headers = allHeaderFields as? [String: String] else { return false }
    return headers[HTTPURLResponse.cacheFlagKey] == "true"
  }

}

func cachePolicy<U>(for request: Request<U>, localCache: Bool) throws -> URLRequest.CachePolicy {
  if localCache {
    guard !request.disableLocalCache else { throw GnomonError.localCacheWasDisabledInRequest }
    return .returnCacheDataDontLoad
  } else {
    return request.disableHttpCache ? .reloadIgnoringLocalCacheData : .useProtocolCachePolicy
  }
}

func prepareURLRequest<U>(
    from request: Request<U>, cachePolicy: URLRequest.CachePolicy, interceptors: [AsyncInterceptor]
) throws -> Observable<URLRequest> {
  var urlRequest = URLRequest(url: request.url, cachePolicy: cachePolicy, timeoutInterval: request.timeout)
  urlRequest.httpMethod = request.method.description
  if let headers = request.headers {
    for (key, value) in headers {
      urlRequest.setValue(value, forHTTPHeaderField: key)
    }
  }

  switch (request.method.hasBody, request.params) {
  case (_, .skipURLEncoding):
    urlRequest.url = request.url
  case (_, .none):
    urlRequest.url = try prepareURL(with: request.url, params: nil)
  case let (_, .query(params)):
    urlRequest.url = try prepareURL(with: request.url, params: params)
  case (false, _):
    throw URLRequestError.methodDoesNotSupportBody(request.method)
  case (true, let .urlEncoded(params)):
    let queryItems = prepare(value: params, with: nil)
    var components = URLComponents()
    components.queryItems = queryItems
    urlRequest.httpBody = components.percentEncodedQuery?.data(using: String.Encoding.utf8)
    urlRequest.url = try prepareURL(with: request.url, params: nil)
    urlRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
  case (true, let .json(params)):
    urlRequest.httpBody = try JSONSerialization.data(withJSONObject: params, options: [])
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    urlRequest.url = try prepareURL(with: request.url, params: nil)
  case (true, let .multipart(form, files)):
    let (data, contentType) = try prepareMultipartData(with: form, files)
    urlRequest.httpBody = data
    urlRequest.setValue(contentType, forHTTPHeaderField: "Content-Type")
    urlRequest.url = try prepareURL(with: request.url, params: nil)
  case (true, let .data(data, contentType)):
    urlRequest.httpBody = data
    urlRequest.setValue(contentType, forHTTPHeaderField: "Content-Type")
    urlRequest.url = try prepareURL(with: request.url, params: nil)
  }

  urlRequest.httpShouldHandleCookies = request.shouldHandleCookies

  return process(urlRequest, for: request, with: interceptors)
}

private func process<U>(
    _ urlRequest: URLRequest, for request: Request<U>, with interceptors: [AsyncInterceptor]
) -> Observable<URLRequest> {
  if let asyncInterceptor = request.asyncInterceptor ?? request.interceptor.map(asynchronizeInterceptor) {
    if request.isInterceptorExclusive {
      return asyncInterceptor(urlRequest)
    } else {
      var urlRequest = asyncInterceptor(urlRequest)
      urlRequest = interceptors.reduce(urlRequest) { request, interceptor in
        request.flatMap { interceptor($0) }
      }
      return urlRequest
    }
  } else {
    return interceptors.reduce(.just(urlRequest)) { request, interceptor in
      request.flatMap { interceptor($0) }
    }
  }
}

private func asynchronizeInterceptor(_ interceptor: @escaping Interceptor) -> AsyncInterceptor {
  { request in
    Observable.deferred { .just(interceptor(request)) }
  }
}

func prepareURL(with url: URL, params: [String: Any]?) throws -> URL {
  var queryItems = [URLQueryItem]()
  if let params = params {
    queryItems.append(contentsOf: prepare(value: params, with: nil))
  }

  guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
    throw GnomonError.invalidRelativeURL(url)
  }

  queryItems.append(contentsOf: components.queryItems ?? [])
  components.queryItems = queryItems.count > 0 ? queryItems : nil
  return components.url!
}

private func prepare(value: Any, with key: String?) -> [URLQueryItem] {
  switch value {
  case let dictionary as [String: Any]:
    return dictionary.sorted { $0.0 < $1.0 }.flatMap { nestedKey, nestedValue -> [URLQueryItem] in
      if let key = key {
        return prepare(value: nestedValue, with: "\(key)[\(nestedKey)]")
      } else {
        return prepare(value: nestedValue, with: nestedKey)
      }
    }
  case let array as [Any]:
    if let key = key {
      return array.flatMap { prepare(value: $0, with: "\(key)[]") }
    } else {
      return []
    }
  case let string as String:
    if let key = key {
      return [URLQueryItem(name: key, value: string)]
    } else {
      return []
    }
  case let stringConvertible as CustomStringConvertible:
    if let key = key {
      return [URLQueryItem(name: key, value: stringConvertible.description)]
    } else {
      return []
    }
  default: return []
  }
}

func prepareMultipartData(
    with form: [String: String], _ files: [String: MultipartFile]
) throws -> (data: Data, contentType: String) {
  let boundary = "__X_NST_BOUNDARY__"
  var data = Data()

  let boundaryData = "--\(boundary)\r\n".data(using: .utf8)!

  try form.sorted { $0.key < $1.key }.forEach { key, value in
    data.append(boundaryData)

    guard let dispositionData = "Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8) else {
      throw MultipartEncodingError.invalidKeyString(key)
    }
    data.append(dispositionData)

    guard let valueData = (value + "\r\n").data(using: .utf8) else {
      throw MultipartEncodingError.invalidValueString(value)
    }
    data.append(valueData)
  }

  try files.sorted { $0.key < $1.key }.forEach { key, file in
    data.append(boundaryData)

    guard let dispositionData = "Content-Disposition: form-data; name=\"\(key)\"; filename=\"\(file.filename)\"\r\n".data(using: .utf8) else {
        throw MultipartEncodingError.invalidKeyOrFileName(key: key, fileName: file.filename)
    }
    data.append(dispositionData)

    guard let contentTypeData = "Content-Type: \(file.contentType)\r\n\r\n".data(using: .utf8) else {
      throw MultipartEncodingError.invalidContentTypeString(file.contentType)
    }
    data.append(contentTypeData)

    data.append(file.data)
    data.append("\r\n".data(using: .utf8)!)
  }

  data.append("--\(boundary)--\r\n".data(using: .utf8)!)
  return (data, "multipart/form-data; boundary=\(boundary)")
}

func processedResult<U>(from data: Data, for request: Request<U>) throws -> U {
  let container = try U.dataContainer(with: data, at: request.xpath)
  return try U(container)
}

public typealias Interceptor = (URLRequest) -> URLRequest
public typealias AsyncInterceptor = (URLRequest) -> Observable<URLRequest>

public func + (left: @escaping (URLRequest) -> URLRequest,
               right: @escaping (URLRequest) -> URLRequest) -> (URLRequest) -> URLRequest {
  return { input in
    return right(left(input))
  }
}

extension Result {

    var value: Success? {
        switch self {
        case let .success(value): return value
        case .failure: return nil
        }
    }

}

extension ObservableType {

  func asResult() -> Observable<Result<Element, Error>> {
    return materialize().map { event -> Event<Result<Element, Error>> in
      switch event {
      case let .next(element): return .next(.success(element))
      case let .error(error): return .next(.failure(error))
      case .completed: return .completed
      }
    }.dematerialize()
  }

}
