#### Custom bash aliases ####
alias la="ls -a"
alias lla="ll -a"

#### Custom bash functions for utilities ####
contains() {
  [[ $1 =~ (^|[[:space:]])$2($|[[:space:]]) ]] && true || false
}

quit () {
  echo >&2 "$@"
}
