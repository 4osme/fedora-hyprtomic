# HyprTomic ユーザー設定レイヤ設計（USR / HOST）

> 目的: イメージ（IMG）と `/etc/skel`（SKEL）の外側にある「ユーザー個人の設定」と
> 「マシン固有の差分」を、git で管理し再構築時に一括で戻せる形にする。
> rpm-ostree で後から積んだパッケージ・カーネル引数は、設定とは**別のマニフェスト**で扱う。

関連: `docs/design/new-order-inventory.md`（レイヤ分類の全体像）

## 確定事項（2026-11-23）

| 項目 | 決定 |
|---|---|
| 設定の配布 | **全部 symlink**（`$HOME` へリンク） |
| 設定リポジトリの既定パス | `~/.config/hyprtomic-user` |
| rpm-ostree の追跡 | **設定とは別のマニフェスト**（`~/.config/hyprtomic-machine/machine.json`） |
| 設計ドキュメント | `docs/design/` のみ git 管理 |

## 1. 方針

1. **IMG は全マシン共通**。`recipes/recipe.yml` に置くのは「どのマシンでも同じにしたいもの」だけ。
2. **SKEL は全ユーザー共通の初期値**。`/etc/skel` に置き、`sync-skel-config` で `$HOME` に配る。
3. **USR はユーザー個人**。git リポジトリの `home/` を `$HOME` に symlink する。
4. **HOST はマシン固有**。rpm-ostree のレイヤ済みパッケージ・kargs・COPR を別マニフェストで管理する。
5. **rpm-ostree は「追加」のみ自動化**。削除は明示操作にする。

| やりたいこと | 置き場所 |
|---|---|
| 全マシンに DMS を入れたい | IMG（`recipe.yml`） |
| 全ユーザーの既定キーバインドを変えたい | SKEL（`/etc/skel`） |
| 自分の hyprland キーバインドだけ変えたい | USR（`home/.config/hypr/user.lua`） |
| このマシンだけモニタ構成を固定したい | USR の `home/.config/hypr/host.lua` |
| このマシンだけ `amdgpu.ppfeaturemask` を足したい | HOST（`machine.json`） |
| このマシンだけ CS9711 指紋ドライバを積みたい | HOST（`machine.json` の `copr` + `packages`） |

## 2. レイヤと管理主体

| レイヤ | 実体 | 管理 | 変更頻度 | 再構築時 |
|---|---|---|---|---|
| **IMG** | bootc/ostree イメージ | このリポジトリ（CI） | 低 | `rpm-ostree rebase` |
| **SKEL** | `/etc/skel` | このリポジトリ | 中 | イメージ更新 + `ujust sync-skel-config` |
| **USR** | `$HOME` の設定 | `hyprtomic-user` リポジトリ | 高 | `git clone` + `ujust user-config-apply` |
| **HOST** | rpm-ostree の差分 | `hyprtomic-machine` リポジトリ | マシンごと | `git clone` + `ujust machine-apply` |
| **RUNTIME** | DMS が生成する配色・outputs・セッション状態 | アプリ | 自動 | 再生成（git 管理外） |

### rpm-ostree を別マニフェストにする理由

- 設定ファイルとホスト状態では**更新のタイミングが違う**。設定は日常的に変わるが、
  rpm-ostree のレイヤは滅多に変わらない。
- レイヤ済みパッケージは **ostree のデプロイに保存されるが、イメージには含まれない**。
  再インストールや `rpm-ostree rebase` の後に手で思い出す必要がある。
- 別ファイル・別コマンドにしておけば、設定だけを適用したいときに rpm-ostree を触らずに済む。
- 削除は依存解決を壊しうるので、**自動は追加のみ、削除は手動**とする。

## 3. 設定リポジトリ（`hyprtomic-user`）

既定パス: `~/.config/hyprtomic-user`（`HYPRTOMIC_USER_DIR` で上書き可）。

```
hyprtomic-user/                  # git リポジトリ
├── README.md                    # 適用方法・マシン一覧
├── .gitignore
└── home/                        # この中身が $HOME に symlink される
    ├── .zshrc
    ├── .config/
    │   ├── hypr/
    │   │   ├── user.lua         # SKEL の hyprland.lua が最後に読む
    │   │   ├── workspaces.lua   # 任意
    │   │   └── host.lua         # マシン固有（hosts で分けたい場合）
    │   ├── nvim/
    │   └── opencode/
    └── .local/
        └── bin/
```

- `home/` の**ファイルはすべて symlink**。ディレクトリは `mkdir -p` してからリンクする。
- リポジトリ直下（`.git`、`README.md` など）はリンク対象にしない。
- アプリが実行時に書き換えるファイル（`~/.config/fcitx5/profile` など）を symlink すると、
  変更がリポジトリにそのまま現れる。これは「設定の変更が git に見える」利点でもあるが、
  意図しない書き換えが差分になる点は許容する。気になるファイルは `.gitignore` に入れる。
- 秘密情報（SSH 秘密鍵、トークン）は置かない。

### マシン固有の設定

`host.lua` のように**ファイル単位**で分ける。複数マシンで同じリポジトリを使う場合は、
`~/.config/hypr/user.lua` から `hostname` を見て分岐するか、
マシンごとにブランチを分ける。`hosts/<hostname>/` の自動切替は行わない（v1）。

## 4. ホストマニフェスト（`hyprtomic-machine`）

既定パス: `~/.config/hyprtomic-machine/machine.json`（`HYPRTOMIC_MACHINE_FILE` で上書き可）。
設定リポジトリとは別の git リポジトリにする（公開したくないホスト情報を分離できる）。

```json
{
  "common": {
    "packages": ["gh", "neovim", "android-tools"],
    "kargs": [],
    "copr": [],
    "flatpaks": ["com.obsproject.Studio"],
    "units": ["sunshine.service"]
  },
  "hosts": {
    "main-desktop": {
      "packages": ["libfprint-cs9711"],
      "kargs": ["amdgpu.ppfeaturemask=0xffffffff"],
      "copr": ["cwt/libfprint-cs9711"],
      "flatpaks": [],
      "units": []
    }
  }
}
```

- `hosts.<hostname>` は `hostname -s` と一致させる。無ければ `common` だけ適用する。
- `common` と `hosts.<host>` は**加算**（上書きではない）。
- `packages` はパッケージ名のみ。バージョンは追わない。
- `kargs` は `key=value` をそのまま。既存引数は消さず `--append-if-missing` で足す。
- `copr` は `owner/project`。
- `flatpaks` は application ID。`--user` スコープで入れる。
- `units` は `systemctl --user` のユニット名。

`machine.json` は JSON なので `jq` で読み書きする（Fedora に標準で入る）。

## 5. コマンド

`ujust` はフラグではなく変数で受ける（既存の `overwrite := "0"` と同じ流儀）。

### 設定（`hyprtomic-user`）

| コマンド | 動作 |
|---|---|
| `ujust user-config-init` | `~/.config/hyprtomic-user` の雛形を作る（`git init` 含む） |
| `ujust user-config-status` | リンクの欠落・張り替え・競合を表示 |
| `ujust user-config-apply` | `home/` を `$HOME` に symlink する |
| `ujust dry_run=1 user-config-apply` | 変更内容の表示のみ |
| `ujust prune=1 user-config-apply` | リポジトリから消えたリンクを外す |
| `ujust user-config-update` | `git pull` してから `user-config-apply` |

### ホスト（`hyprtomic-machine`）

| コマンド | 動作 |
|---|---|
| `ujust machine-init` | 空の `machine.json` を作る（`git init` 含む） |
| `ujust machine-status` | マニフェストと実体の差分を表示 |
| `ujust machine-apply` | COPR 有効化 → パッケージ → kargs → flatpak → units の順に適用 |
| `ujust dry_run=1 machine-apply` | 実行内容の表示のみ |
| `ujust machine-export` | 現在のホスト状態を `machine.json` に書き戻す（kargs は手動のまま） |

### 適用アルゴリズム（`user-config-apply`）

1. リポジトリのルートを解決（既定パス or `HYPRTOMIC_USER_DIR`）。
2. `home/` 配下のファイル一覧を取得し、前回の manifest と比較。
3. `prune=1` のとき、前回リンクしたが今回消えたパスを、**リンク先がリポジトリを指している場合のみ**削除。
4. 各ファイルについて:
   - 親ディレクトリを `mkdir -p`。
   - 既存が通常ファイルなら `~/.local/state/hyprtomic/backup/<timestamp>/` に退避。
   - `ln -sfn <repo>/home/<rel> $HOME/<rel>`。
5. 適用一覧を `~/.local/state/hyprtomic/user-manifest` に保存。

### 適用アルゴリズム（`machine-apply`）

1. `machine.json` を `jq` で読み、`common` + `hosts.$(hostname -s)` を合成。
2. `copr` → リポジトリファイルが無ければ `sudo dnf copr enable -y <owner/project>`。
3. `packages` → 未インストールのものだけ `sudo rpm-ostree install --idempotent -y`。
4. `kargs` → `sudo rpm-ostree kargs --append-if-missing="<arg>"`（1 引数ずつ）。
5. `flatpaks` → `flatpak install --user -y --noninteractive`。
6. `units` → `systemctl --user enable --now`。
7. rpm-ostree を変更した場合は「再起動が必要」と表示する。

すべて冪等。2 回目以降は差分ゼロで終わる。

## 6. 安全規則

- **rpm-ostree の削除は自動化しない。** `machine-apply` は追加のみ。削除は手動で
  `rpm-ostree uninstall` し、`machine-export` でマニフェストを更新する。
- **kargs も削除しない。** 追加のみ。削除は `rpm-ostree kargs --delete=` を手動で。
- **既存ファイルは退避してからリンク。** 上書き前に `~/.local/state/hyprtomic/backup/` へ。
- **SKEL と USR の同一パスは USR を優先。** `sync-skel-config` は USR 管理パスを触らない。
- **秘密情報を置かない。**
- **`override replace` は追跡しない。** 一時的な回避策は手動。恒久化するなら IMG に入れる。

## 7. sync-skel-config との関係

- SKEL は「配るだけ」。USR が常に勝つ。
- `sync-skel-config` は次を**除外**する。
  - `hyprtomic-user/home/` に存在する相対パス
  - `~/.config/hypr/user.lua`
  - `~/.config/hypr/workspaces.lua`
  - `~/.config/hypr/local.conf`
  - `~/.config/hypr/host.lua`
- `overwrite=1` の manifest 方式は維持するが、上記の除外パスは削除対象にもしない。
- SKEL 側に `local.conf` は置かない（旧 hyprtomic の運用を維持）。

## 8. hyprland.lua の include 順（SKEL 側）

```
theme.lua            (SKEL)    既定配色
workspaces.lua       (USR)     任意。ワークスペース割当
dms/outputs.lua      (RUNTIME) DMS が生成
dms/colors.lua       (RUNTIME) DMS が生成
host.lua             (USR)     モニタ・GPU 固有
user.lua             (USR)     最後。何でも上書きできる
```

`user.lua` / `host.lua` は「テーブルを返す」形式にすると、SKEL 側の既定値を安全に上書きできる。
`local.conf` は後方互換のため残すが、新規は `user.lua` を使う。

## 9. 再構築の流れ

```sh
# 1. イメージを入れる（ISO or rebase）
# 2. 設定とホスト状態を取得
git clone <dotfiles-repo> ~/.config/hyprtomic-user
git clone <machine-repo> ~/.config/hyprtomic-machine
# 3. 設定をリンク
ujust user-config-apply
# 4. ホスト差分を適用
ujust machine-apply
# 5. 再起動（rpm-ostree の差分がある場合）
systemctl reboot
# 6. ログインして確認
ujust user-config-status
ujust machine-status
```
