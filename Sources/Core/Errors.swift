import Foundation

public enum GnomonError: Error {
  case undefined(message: String?)

  case nonHTTPResponse(response: URLResponse)
  case invalidResponse
  case errorStatusCode(Int, Data)

  case unableToParseModel(Error)
  case dataContainerDoesNotSupportArrays(containerType: String)

  case invalidURLString(String)
  case localCacheWasDisabledInRequest
  case invalidRelativeURL(URL)
}

public enum URLRequestError: Error {
  case methodDoesNotSupportBody(Method)
}

public enum MultipartEncodingError: Error {
  case invalidKeyString(String)
  case invalidValueString(String)
  case invalidKeyOrFileName(key: String, fileName: String)
  case invalidContentTypeString(String)
}

public struct StringParseError: LocalizedError {
  public let encoding: String.Encoding

  public var errorDescription: String? {
    "can't parse StringModel from Data with required encoding \(encoding)"
  }
}

#if JSON
import struct SwiftyJSON.JSON

public enum JSONParseError: Error {
  case emptyXPath
  case noKeyInJSON(key: String, json: JSON)
}
#endif

#if DECODABLE
public struct DecodableXPathError: Error {
  public let xpath: String
}
#endif
