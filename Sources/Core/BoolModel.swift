//
//  BoolModel.swift
//  Gnomon
//
//  Created by Sergei Mikhan on 3/16/20.
//

import Foundation

public protocol BoolModel: BaseModel where DataContainer == Bool {
  static var encoding: String.Encoding { get }
}

extension BoolModel {

  public static func dataContainer(with data: Data, at path: String?) throws -> Bool {
    guard let value = String(data: data, encoding: encoding)?.lowercased() else {
      throw StringParseError(encoding: encoding)
    }
    return value == "true" || value == "1"
  }
}

extension Bool: DataContainerProtocol {

  public typealias Iterator = GenericDataContainerIterator<Bool>

  public static func container(with data: Data, at path: String?) throws -> Bool {
    preconditionFailure("this method should not be called since StringModel.dataContainer is implemented")
  }

  public func multiple() -> GenericDataContainerIterator<Bool>? {
    return nil
  }

  public static func empty() -> Bool {
    return false
  }

}

extension Bool: BoolModel {
  public static var encoding: String.Encoding { return .utf8 }
}
