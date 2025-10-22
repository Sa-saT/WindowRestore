import Foundation

// この関数はRustのFFI関数を呼び出して、現在のウィンドウレイアウトを保存します。
// これはSwiftがRustとどのように連携するかの簡単な例です。
func callRustFFI() {
    // Rustの関数を呼び出して、現在のレイアウトを保存します。レイアウト名をパラメータとして渡します。
    // この関数は成功/エラーコードとしてIntを返します。
    let result = save_current_layout("Default Layout")
    
    // 結果をチェックして、Rustの関数が成功したかどうかを確認します。
    if result == 0 {
        // 成功ケース: 結果が0の場合、レイアウトは正常に保存されました。
        print("レイアウトが正常に保存されました")
    } else {
        // 失敗ケース: 結果が0でない場合、エラーがありました。
        // Rustからエラーメッセージを取得しようとします。
        if let errorMessage = String(cString: get_last_error_message(), encoding: .utf8) {
            print("エラー: \(errorMessage)") // Rustから取得したエラーメッセージを表示します。
        } else {
            // 特定のエラーメッセージがない場合は、一般的なエラーを表示します。
            print("未知のエラーが発生しました")
        }
    }
}

// このダミーのメイン関数は、プログラム開始時にFFI呼び出しを実行します。
callRustFFI() // プログラム開始時にFFI関数を実行します。
