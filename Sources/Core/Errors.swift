import Foundation

public enum GnomonError: Error {
  case undefined(message: String?)

  case nonHTTPResponse(response: URLResponse)
  case invalidResponse
  case errorStatusCode(Int, Data)

  case unableToParseModel(Error)
}

public enum MultipartEncodingError: Error {
  case invalidKeyString(String)
  case invalidValueString(String)
  case invalidKeyOrFileName(key: String, fileName: String)
  case invalidContentTypeString(String)
}
