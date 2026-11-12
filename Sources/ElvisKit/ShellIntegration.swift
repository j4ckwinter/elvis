public enum ShellIntegration {
    public enum Shell: String, CaseIterable, Sendable {
        case zsh
    }

    public static func script(for shell: Shell, elvis path: String) -> String {
        switch shell {
        case .zsh:
            return """
                # Elvis: tells the dog how your own test runs went. Add to ~/.zshrc:  eval "$(\(path) shell-init zsh)"
                autoload -Uz add-zsh-hook
                _elvis_preexec() { _elvis_command=$1 }
                _elvis_precmd() {
                  local last=$?
                  [[ -n $_elvis_command ]] || return 0
                  ( '\(path)' ran $last "$_elvis_command" &>/dev/null & )
                  _elvis_command=
                }
                add-zsh-hook preexec _elvis_preexec
                add-zsh-hook precmd _elvis_precmd
                """
        }
    }
}
