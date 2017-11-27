#### Custom bash aliases for git ####
alias gstatus="git status"
alias glog="git-log"
alias gdiff="git diff"
alias gshow="git show --name-status"
alias gadd="git add"
alias gclean="git clean"
alias gcommit="git commit -m"
alias gcommit-amend="git commit --amend -m"
alias gcommit-merge="git-commit-merge"
alias gcheckout="git checkout"
alias gpush="git push"
alias gpush-up="git push --set-upstream origin $1"
alias gpull="git pull --rebase"
alias gbranch="git branch"
alias gstash="git stash"
alias greset="git reset"
alias gmerge="git-merge"

#### Custom bash functions git ####
isGitDirectory() {
  if [[ -d .git ]]; then :
    return 0  # 0 = true
  else :
    # this is not a git repository
    echo "Current directory is not a valid git repo or you're not at the top level root directory of the repo."
    return 1 # 1 = false
  fi
}

git-log() {
  if isGitDirectory; then :
      # This is a valid git repository (but the current working
      # directory may not be the top level.
      # Check the output of the git rev-parse command if you care)
      #if [[ $1 = "one-line" ]]; then :
      if [[ $1 = "graph1" ]]; then :
        git log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(bold yellow)%d%C(reset)' --all
      elif [[ $1 = "graph2" ]]; then :
        git log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold cyan)%aD%C(reset) %C(bold green)(%ar)%C(reset)%C(bold yellow)%d%C(reset)%n'' %C(white)%s%C(reset) %C(dim white)- %an%C(reset)' --all
      elif [[ $1 = "files" ]]; then :
        git log --name-status
      elif [[ $# -eq 0 ]]; then :
        git log --decorate --pretty=format:"%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(bold yellow)%d%C(reset)"
      else
        echo "$1 not recognized. Please choose on of the following: oneline | graph1 | graph2 | files or leave empty"
      fi
  fi
}

git-archive-branch() {
  ((!$#)) && echo "usage: git archive-branch <git-branch-name>" && exit 1

  #if git rev-parse --git-dir > /dev/null 2>&1; then
  if isGitDirectory; then
    : # This is a valid git repository (but the current working
      # directory may not be the top level.
      # Check the output of the git rev-parse command if you care)
      old_branch=$1
      #echo old branch: $branch_name

      new_branch=archive/${old_branch}
      #echo new branch: $new_branch_name

      git branch -M $old_branch $new_branch
      git push origin $new_branch
      git push origin --delete $old_branch
  fi
}

git-unarchive-branch() {
  ((!$#)) && echo "usage: git archive-branch <git-branch-name>" && exit 1

  #if git rev-parse --git-dir > /dev/null 2>&1; then
  if isGitDirectory; then
    : # This is a valid git repository (but the current working
      # directory may not be the top level.
      # Check the output of the git rev-parse command if you care)
      branch_name=$1
      #echo old branch: $branch_name

      new_branch_name=${branch_name##*/}
      #echo new branch: $new_branch_name

      git branch feature/$new_branch_name origin/$branch_name
      git push origin feature/$new_branch_name
      #git push origin --delete $branch_name
  fi
}

git-commit-merge() {
  #((!$#)) && echo "usage: git-commit-merge <from-branch-name>" && exit 1

  if [[ $# -eq 0 ]]; then :
    echo "usage: git-commit-merge <from-branch-name>"
  else
    #if git rev-parse --git-dir > /dev/null 2>&1; then
    if isGitDirectory; then :
        # This is a valid git repository (but the current working
        # directory may not be the top level.
        # Check the output of the git rev-parse command if you care)
        from_branch=$1
        to_branch=$(git rev-parse --abbrev-ref HEAD)
        echo "Committing merge from $from_branch to current branch ($to_branch)."
        git commit -m "Merged from $from_branch to $to_branch. $2"
    fi
  fi
}

git-merge() {
  #((!$#)) && echo "usage: git-merge <from-branch-name>" && exit 1

  if [[ $# -eq 0 ]]; then :
    echo "usage: git-commit-merge <from-branch-name>"
  else
    #if git rev-parse --git-dir > /dev/null 2>&1; then
    if isGitDirectory; then :
        # This is a valid git repository (but the current working
        # directory may not be the top level.
        # Check the output of the git rev-parse command if you care)
        from_branch=$1
        conflict_resolution=""
        if [[ $2 = "ours" ]]; then :
          conflict_resolution="--strategy-option ours"
        elif [[ $2 = "theirs" ]]; then :
          conflict_resolution="--strategy-option theirs"
        fi
        to_branch=$(git rev-parse --abbrev-ref HEAD)
        echo "Merging from $from_branch to current branch ($to_branch)"
        git merge --squash --no-commit $from_branch $conflict_resolution
    fi
  fi
}
