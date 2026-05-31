import Foundation

/// MediaDomain 全体で共有するエラー。
public enum MediaError: Error, Equatable {
    /// 入力バイト列が空。
    case emptyInput
    /// 画像/動画のデコードに失敗（壊れたデータ・非対応形式）。
    case decodeFailed
    /// エンコード（再圧縮）に失敗。
    case encodeFailed
    /// 解像度・品質を最大限下げても byte 上限に収まらない。
    case cannotFitBudget
    /// 許可リスト外の MIME タイプ。
    case unsupportedMIME(String)
    /// ローカル保存に失敗。
    case storageFailed
    /// 動画トランスコードに失敗。
    case transcodeFailed
}
