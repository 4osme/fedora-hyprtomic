
nixos-dotfilesはfedora atomicをベースに新たな変更を加えたものだがnixosの学習コストの高さなどが仇になり没となったためfedora-atomic(hyprtomic)に戻ろうと思う。

# Hyprtomic New Order 計画
既存のfedora-hyprtomicにはいくつかの欠点がありfedoraにhyprlandのコンポーネントが不足していることからarchlinuxをコンポーネントのコンテナとして使用していたが導入の難度が下がった反面安定性に欠いていた。
またパフォーマンスモニターなどもflatpakベースだったので一部distroboxコンテナのプロセスなどの識別が難しかった。
今回の再始動では環境の再現から方針を変更し、GUIなどのシステム根幹のみの再現とし環境やユーザー依存の変更は別途導入とする。

# fedora-atomicコンテナに含むもの
- 環境共通で反映したい設定
- GUIコンポーネント
- 基本的なGUIツール
- IME(fcitx5,mozkey)
- sync-skel-config

# fedora-atomic に新規で追加する要素
- コンポジタなどのconfigにdmsやユーザ設定を受け入れるための変更を加える
- hyprtomic-guiコンテナでカバーしていたコンポーネントをfedora-atomicに加えるためのビルドと取り込み
- コンポジタなどのベース設定に取り込むユーザ設定をsync-skel-configで反映するためのツール
> ユーザ設定はユーザがgit管理などをしやすいように配慮する

# nixos-dotfilesから引き継ぐもの
- sunshineストリーミングと仮想ディスプレイ対応の最適化。
- dms対応に向けたQuickShellの変更
