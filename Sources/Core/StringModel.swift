//
//  Created by Vladimir Burdukov on 23/02/2018.
//

import Foundation

public protocol StringModel: BaseModel where DataContainer == String {
  static var encoding: String.Encoding { get }
}

extension StringModel {

  public static func dataContainer(with data: Data, at path: String?) throws -> DataContainer {
    guard let string = String(data: data, encoding: encoding) else {
      throw StringParseError(encoding: encoding)
    }
    return string
  }

}

extension String: DataContainerProtocol {

  public typealias Iterator = GenericDataContainerIterator<String>

  public static func container(with data: Data, at path: String?) throws -> String {
    preconditionFailure("this method should not be called since StringModel.dataContainer is implemented")
  }

  public func multiple() -> GenericDataContainerIterator<String>? {
    return .init(components(separatedBy: .newlines))
  }

  public static func empty() -> String {
    return ""
  }

}

extension String: StringModel {
  public static var encoding: String.Encoding { return .utf8 }
}
