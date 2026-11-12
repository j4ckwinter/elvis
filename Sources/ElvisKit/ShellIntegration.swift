public enum ShellIntegration {
    public enum Shell: String, CaseIterable, Sendable {
        case zsh, bash
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
        case .bash:
            return """
                # Elvis: tells the dog how your own test runs went. Add to ~/.bash_profile:  eval "$(\(path) shell-init bash)"
                _elvis_before() {
                  if [[ -z ${COMP_LINE-} && -z ${_elvis_command-} && -n ${_elvis_at_prompt-} ]]; then
                    local number line
                    read -r number line <<< "$(HISTTIMEFORMAT= builtin history 1)"
                    number=${number%\\*}
                    if [[ $number != "${_elvis_seen-}" && ${line%% *} == "${BASH_COMMAND%% *}" ]] || [[ $number == "${_elvis_seen-}" && $line == "$BASH_COMMAND" ]]; then
                      _elvis_seen=$number
                      _elvis_at_prompt=
                      _elvis_command=$line
                    fi
                  fi
                  : "$1"
                }
                _elvis_after() {
                  local last=$?
                  if [[ -n ${_elvis_command-} ]]; then
                    ( '\(path)' ran $last "$_elvis_command" &>/dev/null & )
                  fi
                  _elvis_command=
                  _elvis_at_prompt=1
                  return $last
                }
                case $(trap -p DEBUG) in
                  *_elvis_before*) ;;
                  '')
                    trap '_elvis_before "$_"' DEBUG
                    PROMPT_COMMAND="_elvis_after${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
                    ;;
                  *) echo "elvis: another tool already uses bash's DEBUG trap, so Elvis cannot watch your commands in this shell" >&2 ;;
                esac
                """
        }
    }
}
