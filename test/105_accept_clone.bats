load common
load_fixtures
status=;output=; #; populated by bats run()

IN_REPO=(.bash_profile .vimrc)
T_DIR_REMOTE="$T_TMP/remote"
REMOTE_URL="file:///$T_TMP/remote"

setup() {
  destroy_tmp
  build_repo "${IN_REPO[@]}"
  cp -rp "$T_DIR_REPO" "$T_DIR_REMOTE"
}

@test "Command 'clone' (bad remote)" {
  echo "
    When 'clone' command is provided,
    and the remote is bad,
      Report error
      Remove the YADM_REPO
      Exit with 1
  "

  #; remove existing worktree and repo
  rm -rf "$T_DIR_WORK"
  mkdir -p "$T_DIR_WORK"
  rm -rf "$T_DIR_REPO"

  #; run clone
  run "${T_YADM_Y[@]}" clone -w "$T_DIR_WORK" "file:///bogus-repo"

  #; validate status and output
  [ "$status" -eq 1 ]
  [[ "$output" =~ Unable\ to\ fetch\ origin ]]

  #; confirm repo directory is removed
  [ ! -d "$T_DIR_REPO" ]
}

@test "Command 'clone'" {
  echo "
    When 'clone' command is provided,
      Create new repo with attributes:
        - 0600 permissions
        - not bare
        - worktree = \$YADM_WORK
        - showUntrackedFiles = no
        - yadm.managed = true
      Report the repo as cloned
      A remote named origin exists
      Exit with 0
  "

  #; remove existing worktree and repo
  rm -rf "$T_DIR_WORK"
  mkdir -p "$T_DIR_WORK"
  rm -rf "$T_DIR_REPO"

  #; run clone
  run "${T_YADM_Y[@]}" clone -w "$T_DIR_WORK" "$REMOTE_URL"

  #; validate status and output
  [ "$status" -eq 0 ]
  [[ "$output" =~ Initialized ]]

  #; validate repo attributes
  test_perms "$T_DIR_REPO" "drw.--.--."
  test_repo_attribute "$T_DIR_REPO" core.bare false
  test_repo_attribute "$T_DIR_REPO" core.worktree "$T_DIR_WORK"
  test_repo_attribute "$T_DIR_REPO" status.showUntrackedFiles no
  test_repo_attribute "$T_DIR_REPO" yadm.managed true

  #; test the remote
  local remote_output
  remote_output=$(GIT_DIR="$T_DIR_REPO" git remote show)
  [ "$remote_output" = "origin" ]
}

@test "Command 'clone' (existing repo)" {
  echo "
    When 'clone' command is provided,
    and a repo already exists,
      Report error
      Exit with 1
  "

  #; run clone
  run "${T_YADM_Y[@]}" clone -w "$T_DIR_WORK" "$REMOTE_URL"

  #; validate status and output
  [ "$status" -eq 1 ]
  [[ "$output" =~ Git\ repo\ already\ exists ]]
}

@test "Command 'clone' -f (force overwrite)" {
  echo "
    When 'clone' command is provided,
    and '-f' is provided,
    and a repo already exists,
      Overwrite the repo with attributes:
        - 0600 permissions
        - not bare
        - worktree = \$YADM_WORK
        - showUntrackedFiles = no
        - yadm.managed = true
      Report the repo as cloned
      A remote named origin exists
      Exit with 0
  "

  #; remove existing worktree
  rm -rf "$T_DIR_WORK"
  mkdir -p "$T_DIR_WORK"

  #; run clone
  run "${T_YADM_Y[@]}" clone -w "$T_DIR_WORK" -f "$REMOTE_URL"

  #; validate status and output
  [ "$status" -eq 0 ]
  [[ "$output" =~ Initialized ]]

  #; validate repo attributes
  test_perms "$T_DIR_REPO" "drw.--.--."
  test_repo_attribute "$T_DIR_REPO" core.bare false
  test_repo_attribute "$T_DIR_REPO" core.worktree "$T_DIR_WORK"
  test_repo_attribute "$T_DIR_REPO" status.showUntrackedFiles no
  test_repo_attribute "$T_DIR_REPO" yadm.managed true

  #; test the remote
  local remote_output
  remote_output=$(GIT_DIR="$T_DIR_REPO" git remote show)
  [ "$remote_output" = "origin" ]
}

@test "Command 'clone' (existing conflicts)" {
  echo "
    When 'clone' command is provided,
    and '-f' is provided,
    and a repo already exists,
      Overwrite the repo with attributes:
        - 0600 permissions
        - not bare
        - worktree = \$YADM_WORK
        - showUntrackedFiles = no
        - yadm.managed = true
      Report the repo as cloned
      A remote named origin exists
      Exit with 0
  "

  #; remove existing repo
  rm -rf "$T_DIR_REPO"

  #; cause a conflict
  echo "conflict" >> "$T_DIR_WORK/.bash_profile"

  #; run clone
  run "${T_YADM_Y[@]}" clone -w "$T_DIR_WORK" "$REMOTE_URL"

  #; validate status and output
  [ "$status" -eq 0 ]
  [[ "$output" =~ Initialized ]]

  #; validate merging note
  [[ "$output" =~ Merging\ origin/master\ failed ]]
  [[ "$output" =~ NOTE ]]

  #; validate repo attributes
  test_perms "$T_DIR_REPO" "drw.--.--."
  test_repo_attribute "$T_DIR_REPO" core.bare false
  test_repo_attribute "$T_DIR_REPO" core.worktree "$T_DIR_WORK"
  test_repo_attribute "$T_DIR_REPO" status.showUntrackedFiles no
  test_repo_attribute "$T_DIR_REPO" yadm.managed true

  #; test the remote
  local remote_output
  remote_output=$(GIT_DIR="$T_DIR_REPO" git remote show)
  [ "$remote_output" = "origin" ]
}

@test "Command 'clone' (local insecure .ssh and .gnupg data, no related data in repo)" {
  echo "
    Local .ssh/.gnupg data exists and is insecure
    but yadm repo contains no .ssh/.gnupg data
      local insecure data should remain accessible
      (yadm is hands-off)
  "
  #; setup scenario
  rm -rf "$T_DIR_WORK" "$T_DIR_REPO"
  mkdir -p "$T_DIR_WORK/.ssh"
  mkdir -p "$T_DIR_WORK/.gnupg"
  touch "$T_DIR_WORK/.ssh/testfile"
  touch "$T_DIR_WORK/.gnupg/testfile"
  find "$T_DIR_WORK" -exec chmod a+rw '{}' ';'

  #; run clone (with debug on)
  run "${T_YADM_Y[@]}" clone -d -w "$T_DIR_WORK" "$REMOTE_URL"

  #; validate status and output
  [ "$status" -eq 0 ]
  [[ "$output" =~ Initialized ]]
  [[ "$output" =~ initial\ private\ dir\ perms\ drwxrwxrwx.+\.ssh ]]
  [[ "$output" =~ initial\ private\ dir\ perms\ drwxrwxrwx.+\.gnupg ]]
  [[ "$output" =~ pre-merge\ private\ dir\ perms\ drwxrwxrwx.+\.ssh ]]
  [[ "$output" =~ pre-merge\ private\ dir\ perms\ drwxrwxrwx.+\.gnupg ]]
  [[ "$output" =~ post-merge\ private\ dir\ perms\ drwxrwxrwx.+\.ssh ]]
  [[ "$output" =~ post-merge\ private\ dir\ perms\ drwxrwxrwx.+\.gnupg ]]
  # standard perms still apply afterwards unless disabled with auto.perms
  test_perms "$T_DIR_WORK/.gnupg" "drwx------"
  test_perms "$T_DIR_WORK/.ssh" "drwx------"

}

@test "Command 'clone' (local insecure .gnupg data, related data in repo)" {
  echo "
    Local .gnupg data exists and is insecure
    and yadm repo contains .gnupg data
      .gnupg dir should be secured post merge
  "
  #; setup scenario
  IN_REPO=(.bash_profile .vimrc .gnupg/gpg.conf)
  setup
  rm -rf "$T_DIR_WORK" "$T_DIR_REPO"
  mkdir -p "$T_DIR_WORK/.gnupg"
  touch "$T_DIR_WORK/.gnupg/testfile"
  find "$T_DIR_WORK" -exec chmod a+rw '{}' ';'

  #; run clone (with debug on)
  run "${T_YADM_Y[@]}" clone -d -w "$T_DIR_WORK" "$REMOTE_URL"

  #; validate status and output
  [ "$status" -eq 0 ]
  [[ "$output" =~ Initialized ]]
  [[ "$output" =~ initial\ private\ dir\ perms\ drwxrwxrwx.+\.gnupg ]]
  [[ "$output" =~ pre-merge\ private\ dir\ perms\ drwxrwxrwx.+\.gnupg ]]
  [[ "$output" =~ post-merge\ private\ dir\ perms\ drwxrwxrwx.+\.gnupg ]]
  test_perms "$T_DIR_WORK/.gnupg" "drwx------"
}

@test "Command 'clone' (local insecure .ssh data, related data in repo)" {
  echo "
    Local .ssh data exists and is insecure
    and yadm repo contains .ssh data
      .ssh dir should be secured post merge
  "
  #; setup scenario
  IN_REPO=(.bash_profile .vimrc .ssh/config)
  setup
  rm -rf "$T_DIR_WORK" "$T_DIR_REPO"
  mkdir -p "$T_DIR_WORK/.ssh"
  touch "$T_DIR_WORK/.ssh/testfile"
  find "$T_DIR_WORK" -exec chmod a+rw '{}' ';'

  #; run clone (with debug on)
  run "${T_YADM_Y[@]}" clone -d -w "$T_DIR_WORK" "$REMOTE_URL"

  #; validate status and output
  [ "$status" -eq 0 ]
  [[ "$output" =~ Initialized ]]
  [[ "$output" =~ initial\ private\ dir\ perms\ drwxrwxrwx.+\.ssh ]]
  [[ "$output" =~ pre-merge\ private\ dir\ perms\ drwxrwxrwx.+\.ssh ]]
  [[ "$output" =~ post-merge\ private\ dir\ perms\ drwxrwxrwx.+\.ssh ]]
  test_perms "$T_DIR_WORK/.ssh" "drwx------"
}

@test "Command 'clone' (no existing .gnupg, .gnupg data tracked in repo)" {
  echo "
    Local .gnupg does not exist
    and yadm repo contains .gnupg data
      .gnupg dir should be created and secured prior to merge
      tracked .gnupg data should be user accessible only
  "
  #; setup scenario
  IN_REPO=(.bash_profile .vimrc .gnupg/gpg.conf)
  setup
  rm -rf "$T_DIR_WORK"
  mkdir -p "$T_DIR_WORK"
  rm -rf "$T_DIR_REPO"

  #; run clone (with debug on)
  run "${T_YADM_Y[@]}" clone -d -w "$T_DIR_WORK" "$REMOTE_URL"

  #; validate status and output
  [ "$status" -eq 0 ]
  [[ "$output" =~ Initialized ]]
  [[ ! "$output" =~ initial\ private\ dir\ perms ]]
  [[ "$output" =~ pre-merge\ private\ dir\ perms\ drwx------.+\.gnupg ]]
  [[ "$output" =~ post-merge\ private\ dir\ perms\ drwx------.+\.gnupg ]]
  test_perms "$T_DIR_WORK/.gnupg" "drwx------"
}

@test "Command 'clone' (no existing .ssh, .ssh data tracked in repo)" {
  echo "
    Local .ssh does not exist
    and yadm repo contains .ssh data
      .ssh dir should be created and secured prior to merge
      tracked .ssh data should be user accessible only
  "
  #; setup scenario
  IN_REPO=(.bash_profile .vimrc .ssh/config)
  setup
  rm -rf "$T_DIR_WORK"
  mkdir -p "$T_DIR_WORK"
  rm -rf "$T_DIR_REPO"

  #; run clone (with debug on)
  run "${T_YADM_Y[@]}" clone -d -w "$T_DIR_WORK" "$REMOTE_URL"

  #; validate status and output
  [ "$status" -eq 0 ]
  [[ "$output" =~ Initialized ]]
  [[ ! "$output" =~ initial\ private\ dir\ perms ]]
  [[ "$output" =~ pre-merge\ private\ dir\ perms\ drwx------.+\.ssh ]]
  [[ "$output" =~ post-merge\ private\ dir\ perms\ drwx------.+\.ssh ]]
  test_perms "$T_DIR_WORK/.ssh" "drwx------"
}
