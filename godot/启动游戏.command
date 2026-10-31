#!/bin/zsh
# Start an independent game window, without the editor's node-selection mode.
set -eu
project_dir="${0:A:h}"
if [[ ! -f "$project_dir/project.godot" ]]; then
  print -u2 "找不到 project.godot，请将启动器保留在项目目录中。"
  exit 1
fi
godot_bin="${GODOT_BIN:-}"
if [[ -z "$godot_bin" ]]; then
  for candidate in /Applications/Godot.app/Contents/MacOS/Godot "$HOME/Applications/Godot.app/Contents/MacOS/Godot" "$HOME/Downloads/Godot.app/Contents/MacOS/Godot"; do
    if [[ -x "$candidate" ]]; then
      godot_bin="$candidate"
      break
    fi
  done
fi
if [[ -z "$godot_bin" ]] && command -v godot >/dev/null 2>&1; then
  godot_bin="$(command -v godot)"
fi
if [[ -z "$godot_bin" || ! -x "$godot_bin" ]]; then
  print -u2 "未找到 Godot 4。请将 Godot.app 放入“应用程序”或“下载”文件夹。"
  print -u2 "也可在 Godot 中打开 project.godot，F5 运行后选择顶部的“输入”。"
  read -r '?按回车键关闭。'
  exit 1
fi
# A freshly unzipped project needs its bundled fonts imported before first play.
if [[ ! -d "$project_dir/.godot/imported" ]]; then
  "$godot_bin" --headless --editor --path "$project_dir" --quit
fi
exec "$godot_bin" --path "$project_dir" "$@"
