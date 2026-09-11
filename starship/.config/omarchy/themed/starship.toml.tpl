# oh-my-chy: Starship prompt, rendered with the active Omarchy theme palette.
# This template lives in ~/.config/omarchy/themed/ and gets re-rendered by
# Omarchy on every `omarchy theme set` (placeholders like {{ accent }} are
# replaced with the current theme's colors).
#
# ~/.config/starship.toml is a symlink to the rendered file in
# ~/.local/state/omarchy/current/theme/starship.toml

"$schema" = 'https://starship.rs/config-schema.json'

add_newline = true
command_timeout = 200

format = "$directory$git_branch$git_status$nodejs$php$python$cmd_duration$line_break$character"

[directory]
truncation_length = 2
truncation_symbol = "…/"
style = "bold {{ accent }}"
read_only = " "
read_only_style = "{{ red }}"

[git_branch]
symbol = ""
style = "italic {{ blue }}"
format = "[$branch]($style) "

[git_status]
style = "{{ yellow }}"
format = '([$all_status$ahead_behind]($style) )'

[nodejs]
symbol = ""
style = "{{ green }}"
format = "[$symbol$version]($style) "

[php]
symbol = ""
style = "{{ magenta }}"
format = "[$symbol$version]($style) "

[python]
symbol = ""
style = "{{ yellow }}"
format = "[$symbol$version]($style) "

[cmd_duration]
min_time = 2000
style = "{{ yellow }}"
format = "[ $duration]($style)"

[character]
success_symbol = "[❯](bold {{ accent }})"
error_symbol = "[❯](bold {{ red }})"
