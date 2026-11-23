# HyprTomic New Order — 構成ソフトウェア分別

> 目的: 旧 `fedora-hyprtomic` と `nixos-dotfiles` の構成要素を棚卸しし、
> 「イメージに入れるもの / skel で配るもの / ユーザーが git 管理するもの /
> マシン固有 / 廃止」に分類する。実装前の合意形成用ドキュメント。

## 確定事項（2026-11-23）

| 項目 | 決定 |
|---|---|
| DMS スイート | **フルスイートを IMG に導入**: `dms` / `quickshell` / `matugen` / `dgop` / `dsearch` / `dcal` / `dfiles` |
| ファイルマネージャ | **dfiles を標準**。nemo 系（nemo / nemo-extensions / nemo-fileroller / nemo-image-converter / nemo-python）は廃止 |
| Sunshine | **IMG で JIS パッチを当ててソースビルド**。起動スクリプト・モニタ構成・仮想ディスプレイ運用は SKEL |
| CS9711 指紋 | **HOST レイヤ**。PAM gate と fprintd は IMG、CS9711 用 libfprint fork は main-desktop のみ任意導入 |
| IME | **Mozkey IbG**（上流の Fedora RPM をビルド時導入、エンジン名 `mozkey-ibg`）。hazkey は使わない |

## 0. 判定レイヤ

| レイヤ | 実体 | 管理方法 | 変更頻度 |
|---|---|---|---|
| **IMG** | Fedora Atomic イメージ | `recipes/recipe.yml` + `files/` + ビルドスクリプト | 低（CI ビルド） |
| **SKEL** | `/etc/skel` のベース設定 | `sync-skel-config` で `$HOME` へ配布 | 中（イメージ更新時） |
| **USR** | ユーザー設定（git 管理） | ユーザーの dotfiles リポジトリ。ベース設定の include 点から読み込む | 高（ユーザーごと） |
| **HOST** | マシン/ハードウェア固有 | イメージ外（rpm-ostree layer、手動、任意 COPR） | マシンごと |
| **DROP** | 廃止 | — | — |

状態: **継続** / **移設**（レイヤ移動） / **新規** / **廃止** / **要検証**

### 基本方針（AGENTS.md より）

- イメージには「環境共通の設定・GUI コンポーネント・基本 GUI ツール・IME・sync-skel-config」だけを入れる。
- Arch GUI コンテナは廃止し、旧コンテナが担っていた GUI 基盤を Fedora 側へ取り込む。
- コンポジタ設定は DMS（Dux Shell）とユーザー設定を受け入れる include 構造にする。
- ユーザー設定はイメージに焼かず、git 管理しやすい独立レイヤにする。
- NixOS から引き継ぐのは Sunshine ストリーミング/仮想ディスプレイ最適化と DMS 対応の Quickshell 変更。

---

## 1. 旧 fedora-hyprtomic

### 1.1 ホストイメージ（`recipes/recipe.yml`）

| コンポーネント | 旧配置 | 新レイヤ | 判定 | 備考 |
|---|---|---|---|---|
| wayblue hyprland base（hyprland / hyprlock / hypridle / portals / sddm） | base-image | IMG | 継続 | New Order でも土台は wayblue |
| qt6-qtsvg / qtvirtualkeyboard / qtmultimedia / qt5compat | dnf | IMG | 継続 | SDDM テーマ依存 |
| pipewire / pipewire-pulseaudio / wireplumber | dnf | IMG | 継続 | 音声基盤 |
| NetworkManager / bluez | dnf | IMG | 継続 | DMS コントロールセンターが system bus 経由で利用 |
| gnome-keyring | dnf | IMG | 継続 | PAM/秘密情報 |
| qt5-qtwayland | dnf | IMG | 継続 | Qt Wayland |
| Noto CJK / Noto Color Emoji / twemoji | dnf | IMG | 継続 | 日本語・絵文字 |
| papirus-icon-theme | dnf | IMG | 継続 | DMS のアイコンテーマ候補 |
| bibata-cursor-theme（COPR ririko66z） | dnf | IMG | 継続 | カーソルはコンポジタ側で必要 |
| grim / slurp / wl-clipboard | dnf | IMG | 継続 | スクショ・クリップボード基盤 |
| cliphist | dnf | IMG | **廃止候補** | DMS の clipboard に置換 |
| brightnessctl / playerctl / libnotify | dnf | IMG | 継続 | DMS/キーバインドの依存 |
| dex-autostart | dnf | IMG | 継続 | XDG autostart（Flatpak の自動起動） |
| distrobox | dnf | IMG | 継続 | GUI 用ではなくユーザーの任意コンテナ用 |
| python3-gobject / python3-cairo | dnf | IMG | **廃止候補** | 旧 Quickshell の Python 連携用。DMS では不要 |
| fastfetch | dnf | IMG | 継続 | ベースシェル設定が使用 |
| file-roller | dnf | IMG | 継続 | アーカイブ管理（dfiles と独立） |
| nemo / nemo-extensions / nemo-fileroller / nemo-image-converter / nemo-python | dnf | — | **廃止** | dfiles へ移行（確定事項） |
| ffmpegthumbnailer / tumbler | dnf | IMG | **廃止候補** | dfiles が独自サムネイルを持つ場合は削除 |
| wtype / ydotool | dnf | IMG | 継続 | 自動入力・uinput |
| git / git-credential-oauth | dnf | IMG | 継続 | git はベース。credential-oauth は USR でも可 |
| python3-pip / android-tools | dnf | IMG | **移設 → USR** | 開発用途。イメージの根幹ではない |
| zsh / zsh-autosuggestions / zsh-syntax-highlighting | dnf | IMG | 継続 | ログインシェル |
| swaybg | dnf | IMG | **廃止** | DMS が壁紙を管理 |
| default-flatpaks: Firefox / Loupe / Bitwarden | recipe | IMG | 継続 | Bitwarden polkit ルールも維持 |
| ghostty | build script | IMG | 継続 | 端末。COPR は `duxlabs/dux-repo` に統一（`scottames/ghostty` でも可） |
| SDDM astronaut theme（git clone） | build script | IMG | **移設（完了）** | rev + SHA256 を固定し、fingerprint status 付き QML をオーバーレイ |
| dconf system db（`00-desktop`） | files/system | IMG | 継続 | GTK 既定値。DMS が後から上書き |

### 1.2 Arch GUI コンテナ（`recipes/gui.yml` / `files/gui-build/`）

| コンポーネント | 旧配置 | 新レイヤ | 判定 | 備考 |
|---|---|---|---|---|
| quickshell-git（AUR ビルド） | container | IMG | **移設** | Fedora 公式 `quickshell`（F44/F45）または COPR。DMS とのバージョン整合が必須 |
| Arch base / base-devel / yay / builder | container | — | **廃止** | コンテナ自体を廃止 |
| fish / eza / starship / btop / jq / go-yq / ripgrep / wget / rsync / unzip / bc / uv | container | IMG/USR | **分割** | jq/ripgrep 等は USR 基本ツール。uv は旧 Quickshell venv 用なので廃止 |
| python-pip / python-gobject / python-cairo / gtk3 | container | — | **廃止** | 旧シェルの Python 連携 |
| ghostty | container | IMG | **統合** | ホスト側 ghostty に一本化 |
| fuzzel | container | — | **廃止** | DMS spotlight に置換 |
| cava | container | USR | **移設** | 任意の見た目パッケージ |
| libqalculate | container | IMG | **要検証** | DMS の計算機ウィジェットが使う場合のみ |
| songrec / translate-shell | container | USR | **移設** | 任意ツール |
| hyprpicker | container | — | **廃止** | DMS の color pick に置換 |
| wf-recorder | container | USR | **移設** | 画面録画（任意） |
| swappy | container | — | **廃止** | NixOS の satty に置換 |
| rofi | container | IMG | **統合** | DMS に alt-tab が無いためウィンドウスイッチャとして残す |
| tesseract / imagemagick | container | USR | **移設** | OCR・画像処理（任意） |
| kdialog / kirigami / syntax-highlighting | container | — | **廃止** | 旧シェル/Arch 依存 |
| matugen | container | IMG | **移設** | DMS の動的テーマ生成 |
| pavucontrol | container | IMG | **統合** | 基本 GUI ツール |
| uwsm | container | IMG | **要検証** | DMS ランチャの `uwsm app` 起動に必要か確認 |
| networkmanager（nmcli） | container | IMG | **統合** | ホスト NM を利用 |
| hyprlock | container | IMG | **統合** | ホストに一本化 |
| Qt6 stack（base/declarative/wayland/5compat/imageformats/positioning/quicktimeline/sensors/tools/translations/multimedia/svg） | container | IMG | **移設** | quickshell/DMS の依存 |
| qt5ct / qt6ct | container | IMG | **統合** | DMS が配色を生成 |
| kvantum | container | — | **廃止** | DMS は qt6ct 経由。Kvantum テーマ設定も廃止 |
| noto-fonts / noto-fonts-cjk / noto-fonts-emoji / jetbrains-mono-nerd / material-symbols | container | IMG | **統合** | Fedora パッケージ名へ読み替え |
| papirus-icon-theme | container | IMG | **統合** | ホストと重複 |
| nemo / nemo-fileroller / nemo-image-converter / nemo-python | container | — | **廃止** | dfiles へ移行 |
| fcitx5 / fcitx5-gtk / fcitx5-qt / fcitx5-configtool | container | IMG | **移設** | ホストで IME を完結 |
| grim / slurp / wl-clipboard / upower / ddcutil / bluez / bluez-utils | container | IMG | **統合** | ホストに一本化。upower/ddcutil は DMS の電池・輝度用 |
| hyprland（ライブラリ/IPC 用） | container | — | **廃止** | ホストの Hyprland を使用 |
| mozkey-ibg-bin（AUR） | container | IMG | **継続（RPM へ）** | 上流の Fedora RPM `mozkey-ibg` をビルド時導入。AUR 依存は廃止 |
| wlogout | container | — | **廃止** | DMS powermenu |
| hypremoji | container | — | **廃止** | 絵文字は DMS ランチャ/入力から |
| clipse / clipse-gui | container | — | **廃止** | DMS clipboard |
| bibata-cursor-theme（AUR） | container | IMG | **統合** | ホスト COPR と重複 |
| ttf-hackgen-nerd / ttf-twemoji | container | IMG | **統合** | Fedora パッケージへ読み替え |
| hyprbind（prebuilt pacman） | container | — | **廃止** | DMS の keybinds モーダルに置換 |
| Google Sans Flex（COPR RPM 抽出） | container | — | **廃止** | NixOS では Roboto Flex に置換済み |
| hyprtomic-gui-session / uv venv / gui-99-finalize | container | — | **廃止** | コンテナ廃止に伴う |
| hyprtomic-gui-shell（ホスト側管理 CLI） | files/system | — | **廃止** | `ujust gui-container-*` も削除 |

### 1.3 skel / 設定ファイル

| パス | 内容 | 新レイヤ | 判定 | 備考 |
|---|---|---|---|---|
| `.zshrc` | シェル基本設定 | SKEL | 継続 | ユーザー拡張は `zshrc.d/` |
| `.config/fcitx5/classicui.conf` | IME UI | SKEL | 継続 | |
| `.config/fcitx5/profile` | IME グループ/エンジン | SKEL | 継続（seed） | エンジン名は `mozkey-ibg`。実行時に fcitx5 が書き換える前提 |
| `.config/fontconfig/**` | フォント優先度 | SKEL | 継続 | |
| `.config/ghostty/config` / `gtk.css` | 端末 | SKEL | 継続 | `gtk.css` は DMS/matugen が生成。静的版はフォールバック |
| `.config/gtk-3.0` / `gtk-4.0` | GTK 配色 | SKEL | 継続 | DMS が上書き |
| `.config/hypr/hyprland.lua` | コンポジタ基本設定 | SKEL | **継続（改修）** | DMS include・ユーザー include を追加 |
| `.config/hypr/hypridle.conf` | アイドル | SKEL | 継続 | マシン別の緩和は USR |
| `.config/hypr/hyprlock.conf` | ロック画面 | SKEL | 継続 | |
| `.config/hypr/layouts/quadgrid.lua` | レイアウト | SKEL | 継続 | |
| `.config/hypr/scripts/{bright,lock-sleep,on-battery}.sh` | セッション補助 | SKEL | 継続 | DMS の IPC に置換できるものは整理 |
| `.config/hyprbind/hyprbind-theme.css` | キーバインドビューア | — | **廃止** | DMS keybinds に置換 |
| `.config/Kvantum/**` | Kvantum テーマ | — | **廃止** | DMS は qt6ct |
| `.config/opencode/opencode.jsonc` | 開発ツール設定 | USR | **移設（削除済み）** | ユーザー依存。skel から外した |
| `.config/qt5ct` / `qt6ct` | Qt 配色 | SKEL | **縮小** | ベースのみ。配色は DMS が生成 |
| `.config/quickshell/ii/**` | 旧カスタムシェル | — | **廃止** | DMS に置換 |
| `.config/rofi/**` | ウィンドウスイッチャ | SKEL | 継続 | DMS 併用 |
| `.config/xdg-desktop-portal/hyprland-portals.conf` | ポータル | SKEL | 継続 | |
| `.local/share/backgrounds/wallpaper.jpg` | 既定壁紙 | SKEL | 継続 | |
| `.local/share/nemo/actions/**` | Nemo 拡張 | — | **廃止** | nemo 廃止に伴う。dfiles の同等機能は USR で再実装 |
| `.config/fastfetch/config.jsonc` | 見た目 | SKEL/USR | **要決定** | ベースに入れるかは好み |

### 1.4 システムファイル / サービス

| コンポーネント | 旧配置 | 新レイヤ | 判定 | 備考 |
|---|---|---|---|---|
| dconf db / profile | files/system | IMG | 継続 | |
| modules-load.d/uinput.conf / udev 99-uinput.rules | files/system | IMG | 継続 | ydotool 用 |
| sddm.conf.d / テーマアセット | files/system | IMG | 継続 | NixOS の fingerprint status 版へ |
| hyprtomic-hostname.service | files/system | IMG | 継続 | 初回ホスト名 |
| hyprtomic-groups.service | files/system | IMG | 継続 | ユーザーグループ |
| hyprtomic-zsh-default.service | files/system | IMG | 継続 | 既定シェル |
| ydotool.service（user unit） | files/system | IMG | 継続 | |
| setup-groups / setup-hostname / setup-zsh | files/system | IMG | 継続 | |
| Bitwarden polkit action | files/system | IMG | 継続 | Flatpak 既定アプリ用 |
| ujust `sync-skel-config` | files/system | IMG | **継続（v2 へ改修）** | ユーザー設定レイヤの scaffold を追加 |
| ujust `gui-container-*` | files/system | — | **廃止** | |
| ujust `login-wallpaper` | files/system | IMG | 継続 | |
| THIRD-PARTY-NOTICES / licenses | files/system | IMG | 継続 | |

### 1.5 ビルド / CI

| コンポーネント | 判定 | 備考 |
|---|---|---|
| `recipes/recipe.yml` | **継続（全面改修）** | COPR 追加、コンテナ関連削除 |
| `recipes/gui.yml` | **廃止** | |
| `files/gui-build/**` / `files/gui/**` | **廃止** | |
| `install-ghostty.sh` | **削除済み** | COPR `duxlabs/dux-repo` の `ghostty` に置換 |
| `install-sddm-theme.sh` | **更新済み** | rev `abb3163c` + SHA256 を固定。QML オーバーレイを `usr/share/hyprtomic/sddm/` から適用 |
| `finalize.sh` | 継続（整理） | dconf update 等 |
| `.github/workflows/build.yml` | 継続 | GUI イメージ job を削除 |

---

## 2. nixos-dotfiles

### 2.1 system modules（`modules/nixos/`）

| モジュール | 内容 | 新レイヤ | 判定 | 備考 |
|---|---|---|---|---|
| `desktop/hyprland.nix` | Hyprland + uwsm + xwayland | IMG | 継続 | wayblue base が提供 |
| `system/sddm.nix` | SDDM テーマ + fingerprint PAM + fprintd | IMG | **移設** | テーマと PAM gate を RPM/ファイルで |
| `system/locale.nix` | ja_JP、jp106、fcitx5 + mozkey | IMG | **移設（Mozkey）** | 上流の Fedora RPM を IMG に導入 |
| `system/audio.nix` | PipeWire quantum/buffer 調整、rtkit | IMG | **移設** | wireplumber 設定として持ち込む |
| `system/networking.nix` | NetworkManager / Bluetooth | IMG | 継続 | |
| `system/security.nix` | polkit / uinput / udev | IMG | 継続 | |
| `system/portals.nix` | xdg-desktop-portal 構成 | IMG | 継続 | |
| `system/fonts.nix` | Noto / OpenMoji / HackGen / JetBrains / Roboto Flex | IMG | **移設** | Fedora パッケージ名へ |
| `system/dconf.nix` | dconf 有効化 | IMG | 継続 | |
| `system/flatpak.nix` | Flatpak + Firefox/Loupe | IMG | 継続 | default-flatpaks と統合 |
| `system/distrobox.nix` | podman + distrobox | IMG | 継続 | |
| `system/hardware.nix` | firmware / microcode / graphics | IMG | 継続 | Fedora base が担当 |
| `system/kernel.nix` | CachyOS kernel | — | **廃止** | Fedora カーネル |
| `system/boot.nix` | systemd-boot / zram | — | **廃止** | ostree が管理 |
| `system/nix.nix` | Nix 設定 / キャッシュ | — | **廃止** | |
| `home-manager.nix` | Home Manager 接続 | — | **廃止** | sync-skel-config に置換 |
| `hosts/main-desktop/*` | 下記 2.4 | HOST/USR | **分割** | |

### 2.2 home-manager modules（`modules/home-manager/`）

| モジュール | 内容 | 新レイヤ | 判定 | 備考 |
|---|---|---|---|---|
| `desktop.nix` | DMS / dcal / dsearch / dux-files / dgop、壁紙 seed | IMG + SKEL | **移設（フルスイート）** | DMS 一式を IMG。session seed は sync ツール |
| `packages.nix` | ユーザーアプリ一式 | IMG/USR | **分割** | 下記 2.5 |
| `zsh.nix` | Nix 管理 zsh プラグイン | SKEL | **移設** | Fedora RPM のプラグインへ |
| `services.nix` | gnome-keyring / ydotoold | IMG | **移設** | user unit として |
| `sunshine.nix` | Sunshine user unit | IMG + SKEL | **移設（完了）** | unit は IMG、起動スクリプトと `sunshine.lua` は SKEL |
| `matugen.nix` | ghostty 用 matugen テンプレート | SKEL | **移設** | パスは sync 時に `$HOME` 展開 |
| `dotfiles.nix` | Nix store リンク配布 | — | **廃止** | sync-skel-config に置換 |
| `sshfs-nas.nix` | afuse + SSHFS | USR | **移設（任意）** | Nix パス依存を通常スクリプトへ |

### 2.3 `files/home`（ユーザー設定ツリー）

| パス | 新レイヤ | 判定 | 備考 |
|---|---|---|---|
| `.zshrc` / `.zsh_plugins.txt` / `zshrc.d/shortcuts.zsh` | SKEL/USR | **分割** | 基本は SKEL、個人ショートカットは USR |
| `.config/fastfetch/config.jsonc` | SKEL/USR | **要決定** | 見た目設定 |
| `.config/fcitx5/classicui.conf` | SKEL | 継続 | |
| `.config/fontconfig/**` | SKEL | 継続 | |
| `.config/ghostty/config` | SKEL | 継続 | |
| `.config/hypr/hyprland.lua` | SKEL | **継続（DMS 対応版の正）** | NixOS 版をベースに include 構造化 |
| `.config/hypr/theme.lua` | SKEL | 継続 | 既定配色 |
| `.config/hypr/hypridle.conf` / `hyprlock.conf` | SKEL | 継続 | |
| `.config/hypr/layouts/quadgrid.lua` | SKEL | 継続 | |
| `.config/hypr/scripts/*` | SKEL | 継続 | |
| `.config/hyprbind/hyprbind-theme.css` | — | **廃止** | DMS keybinds に置換 |
| `.config/matugen/templates/ghostty-gtk.css` | SKEL | 継続 | |
| `.config/nvim/**` | USR | **移設** | 完全にユーザー依存 |
| `.config/rofi/**` | SKEL | 継続 | |
| `.local/share/applications/org.kde.haruna.desktop` | USR | **移設** | 任意アプリ |
| `.local/share/backgrounds/wallpaper.jpg` | SKEL | 継続 | |
| `home-main-desktop/.config/hypr/host.lua` | USR | **移設** | マシン固有モニタ構成 |
| `home-main-desktop/.config/hypr/workspaces.lua` | USR | **移設** | ワークスペース割当 |
| `home-main-desktop/.config/sunshine/**` | SKEL | **移設（完了）** | `hypr-stream-display.py` |
| `home-main-desktop/.local/bin/sunshine-session` | SKEL | **移設（完了）** | 仮想ディスプレイ運用 |
| `sddm-theme/**`（FingerprintStatus.qml 含む） | IMG | **移設（完了）** | `usr/share/hyprtomic/sddm/` に配置 |
| `system/pam.d/pam-fingerprint-gate` | IMG | **移設（完了）** | `usr/libexec/hyprtomic/pam-fingerprint-gate`。fprintd は IMG、CS9711 ドライバは HOST |

### 2.4 ホスト固有（`hosts/main-desktop/`）

| ファイル | 内容 | 新レイヤ | 判定 | 備考 |
|---|---|---|---|---|
| `gpu.nix` | Intel Arrow Lake GPU / VA-API / oneVPL | HOST | **移設（任意）** | Fedora の intel-media-driver 等 |
| `npu.nix` | Intel NPU driver/firmware | HOST | **移設（任意）** | このマシン専用 |
| `fingerprint.nix` | CS9711 libfprint fork | HOST | **移設（任意）** | COPR `cwt/libfprint-cs9711` 等 |
| `sunshine.nix` | Sunshine パッケージ | IMG + HOST | **分割** | JIS パッチは IMG、導入可否は HOST |
| `storage.nix` / `hardware-configuration.nix` | ディスク構成 | — | **廃止** | ostree が管理 |
| `networking.nix` / `vlan202.sh` | VLAN/固定 IP | HOST | **移設（任意）** | NetworkManager profile へ |
| `users.nix` | ユーザー/グループ | HOST | **移設** | Fedora のユーザー作成・groups service |
| `home.nix` | Home Manager 接続 | — | **廃止** | |

### 2.5 パッケージの分割（`home-manager/packages.nix`）

| パッケージ | 新レイヤ | 判定 | 備考 |
|---|---|---|---|
| fastfetch / git / zsh / ghostty / wl-clipboard / libnotify / dex / wtype / ydotool / jq / pavucontrol | IMG | 継続 | 基本ツール |
| hyprbind / hypremoji / rofi / satty / adw-gtk3 / nwg-displays / papirus / bibata / qt5ct / qt6ct / glib / dconf / xdg-utils / desktop-file-utils / shared-mime-info | IMG | **分割** | rofi / adw-gtk3 / papirus / bibata / qt5ct / qt6ct は IMG。hyprbind / hypremoji は廃止、satty / nwg-displays は USR |
| dgop / dsearch / dcal / dux-files | IMG | **新規（フルスイート）** | DMS のシステム監視・検索・カレンダー・ファイルマネージャ |
| gh / tea / vscode / vesktop / serein / bitwarden / google-chrome / easyeffects / sshfs / neovim / ripgrep / lazygit / gcc / curl / tar / python3 / haruna / tela-circle-icon-theme | USR | **移設** | 個人環境。Flatpak 併用可 |
| sunshine | IMG（ソースビルド）+ SKEL（運用） | **移設（完了）** | JIS パッチを当ててビルド。仮想ディスプレイ運用は `sunshine.lua` / `sunshine-session` |

### 2.6 カスタムパッケージ（`pkgs/`）

| パッケージ | 内容 | 新レイヤ | 判定 | 備考 |
|---|---|---|---|---|
| `hyprbind` | キーバインドビューア | — | **廃止** | DMS keybinds に置換 |
| `hypremoji` | 絵文字ピッカー | — | **廃止** | DMS ランチャ/入力に統合 |
| `mozkey` | fcitx5 mozkey | IMG | **継続（RPM）** | 上流の Fedora RPM を導入（AUR 版は廃止） |
| `libfprint-cs9711` | CS9711 指紋リーダー | HOST | **移設（任意）** | COPR 優先 |
| `sddm-theme` | astronaut + fingerprint status | IMG | **移設（完了）** | ピン留め tarball + QML オーバーレイ |
| `sunshine` patches | JIS キーボード / Wayland retry | IMG | **移設（完了）** | `usr/share/hyprtomic/sunshine/patches` に vendoring |

---

## 3. New Order で新規に決めること

### 3.1 追加するコンポーネント

| コンポーネント | パッケージ名 | 入手元 | 用途 | 備考 |
|---|---|---|---|---|
| DMS 本体 | `dms` / `dms-cli` | COPR `duxlabs/dms` | バー・ランチャ・CC・通知・電源・OSD | v2.1.0（2026-11 時点）。`quickshell` / `accountsservice` / `qt6-qtmultimedia` に依存 |
| quickshell | `quickshell` | COPR `duxlabs/dux-repo` | DMS ランタイム | Fedora 公式は 0.2.1 で DMS 2.1 に古い可能性。DMS と同じ COPR で揃える |
| matugen | `matugen` | COPR `duxlabs/dux-repo` | 壁紙起点の配色生成 | DMS の動的テーマ |
| dgop | `dux-gop` | COPR `duxlabs/dux-repo` | DMS システム監視 | dms の Suggests |
| dsearch | `dux-search` | COPR `duxlabs/dux-repo` | 検索 | dms の Recommends（`dux-search` or `danksearch`） |
| dcal | `dux-calendar` | COPR `duxlabs/dux-repo` | カレンダー | |
| dfiles | `dux-files` | COPR `duxlabs/dux-repo` | ファイルマネージャ（**標準**） | `inode/directory` の既定に設定。nemo を置換 |
| アイコン/フォント | `dux-icons` / `material-symbols-fonts` | COPR `duxlabs/dux-repo` | DMS の見た目 | |
| ghostty | `ghostty` | COPR `duxlabs/dux-repo` または `scottames/ghostty` | 端末 | 既存の scottames を継続しても可 |
| Qt テーマ | `qt6ct-kde` | COPR `duxlabs/dux-repo` | Qt 配色 | Fedora 公式 `qt6ct` で足りるなら不要 |
| Mozkey IbG | `mozkey-ibg` | 上流 GitHub Releases の Fedora RPM | 日本語 IME | v0.11.0（prerelease）。`fcitx5 >= 5.1.0` のみ要求。`install-mozkey.sh` で SHA256 検証 |
| satty | `satty` | 要検証（Fedora 公式に無し） | スクショ注釈 | COPR を探す。無ければ USR |
| adw-gtk3 | `adw-gtk3` | 要検証（Fedora 公式に無し） | DMS GTK テーマ | COPR を探す。無ければ USR |
| nwg-displays | `nwg-displays` | 要検証（Fedora 公式に無し） | モニタ/ワークスペース設定（任意） | DMS outputs と役割分担 |

#### 3.1.1 COPR 構成（案）

```yaml
# recipe.yml の dnf モジュールに追加する COPR
- duxlabs/dms        # dms, dms-cli
- duxlabs/dux-repo   # quickshell, matugen, dux-gop, dux-search,
                     # dux-calendar, dux-files, dux-icons,
                     # material-symbols-fonts, ghostty, qt6ct-kde
- ririko66z/dots-hyprland  # bibata-cursor-theme（既存）
```

- `duxlabs/dux-repo` は Fedora 43/44/45 と EL10 を提供。F44 の x86_64 で quickshell / matugen / dux-* のビルドを確認済み（2026-11）。
- `duxlabs/dms` の `dms.spec` は `Requires: (quickshell or quickshell-git)`、`Recommends: (dux-search or danksearch)`、`Recommends: (dux-gop or dgop)`。フルスイートはこの推奨群を明示的に入れる。
- **Mozkey は COPR を使わない。** 上流が Fedora 44 x86_64 RPM をリリースしているので、
  `files/scripts/install-mozkey.sh` が version と SHA256 を固定して導入する。
  RPM は `fcitx5 >= 5.1.0` のみ要求し、`mozkey-ibg` アドオンと Zenz ランタイムを同梱する。

### 3.2 ベース設定の include 構造（DMS + ユーザー設定）

`~/.config/hypr/hyprland.lua`（SKEL）の読み込み順を固定する:

1. `theme.lua`（SKEL の既定配色）
2. `workspaces.lua`（USR、任意）
3. `dms/outputs.lua` / `dms/colors.lua`（DMS が実行時生成）
4. `user.lua` または `local.conf`（USR、最後に読み込み・上書き可能）

- `sync-skel-config` の管理対象は SKEL のみ。`user.lua` / `local.conf` / `workspaces.lua` は**絶対に上書きしない**。
- `ujust user-config-init` で `~/.config/hypr/user.lua` と `~/.config/hypr/user/` の雛形を作り、そのまま git 管理できるようにする。
- DMS のランタイム生成物（`dms/outputs.lua`、`dms/colors.lua`、`session.json`）は git 管理対象外と明記する。
- `dfiles` を `inode/directory` の既定ハンドラに設定する（`/etc/xdg/mimeapps.list` または SKEL の `mimeapps.list`）。

### 3.3 sync-skel-config v2 の要件

- 既存の `overwrite=1` + manifest による削除追従は維持。
- 追加:
  - `user-config-init`: USR レイヤの雛形（`hypr/user.lua`、`zshrc.d/`、`README`）を生成。
  - `user-config-status`: SKEL 管理ファイルと USR ファイルの衝突を検査。
  - `--dry-run`: 上書き・削除の予告。
- `/etc/skel` に `local.conf` を置かない（旧 hyprtomic の運用を維持）。

USR / HOST レイヤの詳細（rpm-ostree のレイヤ済みパッケージ・kargs を含む）は
`docs/design/user-config-layer.md` に分離した。SKEL と USR の衝突回避ルールもそちらで定義する。

---

## 4. 廃止リスト（確定）

- Arch GUI コンテナ一式: `recipes/gui.yml`、`files/gui/**`、`files/gui-build/**`、`hyprtomic-gui-shell`、`hyprtomic-gui-session`、`ujust gui-container-*`。
- 旧カスタム Quickshell シェル `~/.config/quickshell/ii/**`。
- `quickshell-git` の AUR ビルド、yay/builder、Python venv、uv。
- clipse / clipse-gui、wlogout、fuzzel、hyprpicker、swappy、kvantum、swaybg。
- nemo 系一式（nemo / nemo-extensions / nemo-fileroller / nemo-image-converter / nemo-python）。dfiles へ移行。
- Google Sans Flex、Kvantum テーマ。
- NixOS 専用: flake / Home Manager / overlays / nix 設定 / CachyOS kernel / systemd-boot / zram / hardware-configuration / storage。
- 旧 `hyprtomic-gui-shell` の ghostty shim 削除処理。

---

## 5. 未決事項・リスク

| 項目 | 内容 | 対応案 |
|---|---|---|
| DMS × quickshell のバージョン | Fedora 公式 quickshell は 0.2.1。DMS 2.1 はより新しい API を要求する可能性 | `duxlabs/dux-repo` の quickshell を採用し、dms と同じ COPR で NEVR を固定。CI で `dms --version` / `qs --version` を検証 |
| Mozkey の入手元 | Fedora 公式にも COPR にも無い。上流 GitHub Releases が Fedora 44 x86_64 RPM を提供（v0.11.0、105 MB、prerelease） | `install-mozkey.sh` で version + SHA256 を固定。更新は手動で bump |
| Mozkey の F45 追随 | 上流 RPM は Fedora 44 ビルド。F45 でも glibc 互換なら動く可能性が高いが未検証 | base が F45 に上がる前に上流の F45 ビルド有無を確認 |
| Mozkey の起動・プロファイル | アドオン名・IM 名は `mozkey-ibg`。`DefaultIM=mozkey-ibg` を seed | 実機で `fcitx5-diagnose` と `~/.config/fcitx5/profile` を確認 |
| Mozkey をソースビルドしたい場合 | `Masterisk-F/fcitx-mozkey` は Bazel ビルドで、エンジン名は `Mozc`。ビルドに 30〜60 分かかる | 現状は RPM を採用。切り替える場合は `install-mozkey.sh` を差し替え、profile も `Mozc` にする |
| DMS の起動順 | `dms.service` は `Requisite=graphical-session.target`。`default.target` で enable するとログイン直後に失敗する | `hyprland-session.target.wants` にバインド（`finalize.sh`）。SKEL の `hyprland.lua` が `hyprland-session.target` を start |
| dgop / dsearch / dcal / dfiles の入手元 | `duxlabs/dux-repo` に `dux-gop` / `dux-search` / `dux-calendar` / `dux-files` として収録済み（2026-11 確認） | フルスイートを IMG に導入。更新は COPR 追随 |
| satty / adw-gtk3 / nwg-displays | `adw-gtk3-theme` は Fedora 公式にあり（IMG に追加済み）。`satty` / `nwg-displays` は Fedora にも主要 COPR にも無い | satty は USR の任意導入（または後日 RPM 化）。nwg-displays は DMS outputs に置換 |
| DMS の依存 | `dms` は `accountsservice` / `qt6-qtmultimedia` に依存し、`cava` / `cups-pk-helper` / `qt6ct` を推奨 | dnf の install に明示的に含める |
| Sunshine の JIS パッチ | upstream 未マージ。v2026.914.233613 / commit `63d35f70` に 0001–0003 を適用。libvirtualhid の pin が変わると 0003 が外れる | `install-sunshine.sh` で commit 固定。更新時は README の手順で 0003 をリベース |
| Sunshine のビルド | CMake 4.x + node/npm + Qt6 devel が必要。ビルドに 10〜20 分 | ビルド専用パッケージは完了後に削除。失敗時は upstream の fc44 RPM にフォールバック（JIS なし） |
| SDDM テーマの追従 | `LoginForm.qml` は rev `abb3163c` のレイアウトに合わせたオーバーレイ | テーマ更新時は差分を確認して `LoginForm.qml` を更新 |
| CS9711 指紋 | COPR `cwt/libfprint-cs9711` の現行性 | HOST レイヤで任意導入。失敗してもイメージは健全に |
| DMS と IME | fcitx5 の Wayland frontend を使うか、GTK/Qt immodule を維持するか | DMS の text-input 対応を確認。まずは immodule 維持 |
| uwsm | `uwsm` は Fedora 公式にも主要 COPR にも無い（2026-11 確認）。wayblue は Hyprland を直接起動する | 導入しない。DMS が `uwsm app` 前提なら USR で個別対応 |
| rofi / hypremoji の重複 | DMS に alt-tab が無いため rofi はウィンドウスイッチャとして残す。hypremoji は廃止 | rofi を IMG に追加済み。絵文字は DMS ランチャ/入力から |
| SDDM テーマのライセンス | astronaut テーマ + 同梱 wallpaper | THIRD-PARTY-NOTICES を更新 |
| /etc/skel と Flatpak | Flatpak アプリの `.desktop` が skel に混ざらないか | sync 対象を明示 manifest 化 |

---

## 6. 次フェーズ

1. **本ドキュメントの確定**（レイヤ境界と 3.1 の採否）→ 2026-11-23 に確定済み。
2. ~~`recipes/recipe.yml` v2~~ 完了（2026-11-23）。COPR 2 本 + repo ファイル 1 本、DMS フルスイート、Mozkey（上流 RPM）、dfiles、`dms.service` を `hyprland-session.target` にバインド。`install-ghostty.sh` は COPR に置換して削除済み。
3. ~~`files/system/etc/skel` の再構成~~ 完了（2026-11-23）。DMS 対応 `hyprland.lua`（include 構造・DMS IPC キーバインド・`dms:*` レイヤールール）、Mozkey profile、dfiles の MIME 既定、`hyprland-session.target`、壁紙 seed、nemo / Kvantum / quickshell ii / hyprbind の削除。
4. ~~`sync-skel-config` v2 と `user-config-*` / `machine-*` の実装~~ 完了（2026-11-23）。設計は `docs/design/user-config-layer.md`。
5. ~~カスタム RPM / COPR の検証~~ 一部完了（2026-11-23）: mozkey（RPM）、sunshine（JIS ソースビルド）、sddm-theme（QML オーバーレイ）、PAM gate を実装。hyprbind / hypremoji は廃止。
6. VM（wayblue）でログイン → DMS 起動 → dfiles → IME → Sunshine（JIS / HEADLESS-1）→ SDDM 指紋ログインの順に検証。
