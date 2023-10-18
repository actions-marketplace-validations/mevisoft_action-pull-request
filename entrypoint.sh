#!/bin/sh

if [ "$INPUT_DEBUG_MODE" = true ] || [ -n "$RUNNER_DEBUG" ]; then
  echo '---------------------------'
  printenv
  echo '---------------------------'
fi

create_pull_request() {
  BRANCH="${1}"

  AUTH_HEADER="Authorization: token ${GITHUB_TOKEN}"
  HEADER="Accept: application/vnd.github.v3+json; application/vnd.github.antiope-preview+json; application/vnd.github.shadow-cat-preview+json"

  if [ -n "$INPUT_GITHUB_API_BASE_URL" ]; then
    REPO_URL="https://${INPUT_GITHUB_API_BASE_URL}/repos/${GITHUB_REPOSITORY}"
  else
    REPO_URL="https://api.${INPUT_GITHUB_BASE_URL}/repos/${GITHUB_REPOSITORY}"
  fi

  PULLS_URL="${REPO_URL}/pulls"

  auth_status=$(curl -sL --write-out '%{http_code}' --output /dev/null -H "${AUTH_HEADER}" -H "${HEADER}" "${PULLS_URL}")
  if [[ $auth_status -eq 403 || "$auth_status" -eq 401 ]] ; then
    echo "FAILED TO AUTHENTICATE USING 'GITHUB_TOKEN' CHECK TOKEN IS VALID"
    exit 1
  fi

  echo "CHECK IF ISSET SAME PULL REQUEST"

  if [ -n "$INPUT_PULL_REQUEST_BASE_BRANCH_NAME" ]; then
    BASE_BRANCH="$INPUT_PULL_REQUEST_BASE_BRANCH_NAME"
  else
    if [ -n "$GITHUB_HEAD_REF" ]; then
      BASE_BRANCH=${GITHUB_HEAD_REF}
    else
      BASE_BRANCH=${GITHUB_REF#refs/heads/}
    fi
  fi

  PULL_REQUESTS_QUERY_PARAMS="?base=${BASE_BRANCH}&head=${BRANCH}"

  PULL_REQUESTS=$(echo "$(curl -sSL -H "${AUTH_HEADER}" -H "${HEADER}" -X GET "${PULLS_URL}${PULL_REQUESTS_QUERY_PARAMS}")" | jq --raw-output '.[] | .head.ref ')

  # check if pull request exist
  if echo "$PULL_REQUESTS" | grep -xq "$BRANCH"; then
    echo "PULL REQUEST ALREADY EXIST"
  else
    echo "CREATE PULL REQUEST"

    if [ -n "$INPUT_PULL_REQUEST_BODY" ]; then
      BODY=",\"body\":\"${INPUT_PULL_REQUEST_BODY//$'\n'/\\n}\""
    fi

    PULL_RESPONSE_DATA="{\"title\":\"${INPUT_PULL_REQUEST_TITLE}\", \"base\":\"${BASE_BRANCH}\", \"head\":\"${BRANCH}\" ${BODY}}"
    # create pull request
    PULL_RESPONSE=$(curl -sSL -H "${AUTH_HEADER}" -H "${HEADER}" -X POST --data "${PULL_RESPONSE_DATA}" "${PULLS_URL}")

    set +x
    PULL_REQUESTS_URL=$(echo "${PULL_RESPONSE}" | jq '.html_url')
    PULL_REQUESTS_NUMBER=$(echo "${PULL_RESPONSE}" | jq '.number')
    view_debug_output

    if [ "$PULL_REQUESTS_URL" = null ]; then
      echo "FAILED TO CREATE PULL REQUEST"
      echo "RESPONSE: ${PULL_RESPONSE}"

      exit 1
    fi

    if [ -n "$INPUT_PULL_REQUEST_LABELS" ]; then
      PULL_REQUEST_LABELS=$(echo "[\"${INPUT_PULL_REQUEST_LABELS}\"]" | sed 's/, \|,/","/g')

      if [ "$(echo "$PULL_REQUEST_LABELS" | jq -e . > /dev/null 2>&1; echo $?)" -eq 0 ]; then
        echo "ADD LABELS TO PULL REQUEST"

        ISSUE_URL="${REPO_URL}/issues/${PULL_REQUESTS_NUMBER}"

        LABELS_DATA="{\"labels\":${PULL_REQUEST_LABELS}}"

        # add labels to created pull request
        curl -sSL -H "${AUTH_HEADER}" -H "${HEADER}" -X PATCH --data "${LABELS_DATA}" "${ISSUE_URL}"
      else
        echo "JSON OF pull_request_labels IS INVALID: ${PULL_REQUEST_LABELS}"
      fi
    fi

    if [ -n "$INPUT_PULL_REQUEST_ASSIGNEES" ]; then
      PULL_REQUEST_ASSIGNEES=$(echo "[\"${INPUT_PULL_REQUEST_ASSIGNEES}\"]" | sed 's/, \|,/","/g')

      if [ "$(echo "$PULL_REQUEST_ASSIGNEES" | jq -e . > /dev/null 2>&1; echo $?)" -eq 0 ]; then
        echo "ADD ASSIGNEES TO PULL REQUEST"

        ASSIGNEES_URL="${REPO_URL}/issues/${PULL_REQUESTS_NUMBER}/assignees"

        ASSIGNEES_DATA="{\"assignees\":${PULL_REQUEST_ASSIGNEES}}"

        # add assignees to created pull request
        curl -sSL -H "${AUTH_HEADER}" -H "${HEADER}" -X POST --data "${ASSIGNEES_DATA}" "${ASSIGNEES_URL}"
      else
        echo "JSON OF pull_request_assignees IS INVALID: ${PULL_REQUEST_ASSIGNEES}"
      fi
    fi

    if [ -n "$INPUT_PULL_REQUEST_REVIEWERS" ] || [ -n "$INPUT_PULL_REQUEST_TEAM_REVIEWERS" ]; then
      if [ -n "$INPUT_PULL_REQUEST_REVIEWERS" ]; then
        PULL_REQUEST_REVIEWERS=$(echo "\"${INPUT_PULL_REQUEST_REVIEWERS}\"" | sed 's/, \|,/","/g')

        if [ "$(echo "$PULL_REQUEST_REVIEWERS" | jq -e . > /dev/null 2>&1; echo $?)" -eq 0 ]; then
          echo "ADD REVIEWERS TO PULL REQUEST"
        else
          echo "JSON OF pull_request_reviewers IS INVALID: ${PULL_REQUEST_REVIEWERS}"
        fi
      fi

      if [ -n "$INPUT_PULL_REQUEST_TEAM_REVIEWERS" ]; then
        PULL_REQUEST_TEAM_REVIEWERS=$(echo "\"${INPUT_PULL_REQUEST_TEAM_REVIEWERS}\"" | sed 's/, \|,/","/g')

        if [ "$(echo "$PULL_REQUEST_TEAM_REVIEWERS" | jq -e . > /dev/null 2>&1; echo $?)" -eq 0 ]; then
          echo "ADD TEAM REVIEWERS TO PULL REQUEST"
        else
          echo "JSON OF pull_request_team_reviewers IS INVALID: ${PULL_REQUEST_TEAM_REVIEWERS}"
        fi
      fi

      {
        REVIEWERS_URL="${REPO_URL}/pulls/${PULL_REQUESTS_NUMBER}/requested_reviewers"
        REVIEWERS_DATA="{\"reviewers\":[${PULL_REQUEST_REVIEWERS}],\"team_reviewers\":[${PULL_REQUEST_TEAM_REVIEWERS}]}"
        curl -sSL -H "${AUTH_HEADER}" -H "${HEADER}" -X POST --data "${REVIEWERS_DATA}" "${REVIEWERS_URL}"
      } || {
         echo "Failed to add reviewers."
      }
    fi

    echo "PULL REQUEST CREATED: ${PULL_REQUESTS_URL}"
  fi
}

push_to_branch() {
  BRANCH=${INPUT_PULL_REQUEST_BRANCH_NAME}

  REPO_URL="https://${GITHUB_ACTOR}:${GITHUB_TOKEN}@${INPUT_GITHUB_BASE_URL}/${GITHUB_REPOSITORY}.git"

  echo "CONFIGURATION GIT USER"
  git config --global user.email "${INPUT_GITHUB_USER_EMAIL}"
  git config --global user.name "${INPUT_GITHUB_USER_NAME}"

  if [ -n "$(git show-ref refs/heads/${BRANCH})" ]; then
    git checkout "${BRANCH}"
  else
    git checkout -b "${BRANCH}"
  fi

  git add .

  if [ ! -n "$(git status -s)" ]; then
    echo "NOTHING TO COMMIT"
    return
  fi

  echo "PUSH TO BRANCH ${BRANCH}"
  git commit --no-verify -m "${INPUT_COMMIT_MESSAGE}"
  git push --no-verify --force "${REPO_URL}"

  if [ "$INPUT_CREATE_PULL_REQUEST" = true ]; then
    create_pull_request "${BRANCH}"
  fi
}

view_debug_output() {
  if [ "$INPUT_DEBUG_MODE" = true ] || [ -n "$RUNNER_DEBUG" ]; then
    set -x
  fi
}

setup_commit_signing() {
  echo "FOUND PRIVATE KEY, WILL SETUP GPG KEYSTORE"

  echo "${INPUT_GPG_PRIVATE_KEY}" > private.key

  gpg --import --batch private.key

  GPG_KEY_ID=$(gpg --list-secret-keys --keyid-format=long | grep -o "rsa\d\+\/\(\w\+\)" | head -n1 | sed "s/rsa\d\+\/\(\w\+\)/\1/")
  GPG_KEY_OWNER_NAME=$(gpg --list-secret-keys --keyid-format=long | grep  "uid" | sed "s/.\+] \(.\+\) <\(.\+\)>/\1/")
  GPG_KEY_OWNER_EMAIL=$(gpg --list-secret-keys --keyid-format=long | grep  "uid" | sed "s/.\+] \(.\+\) <\(.\+\)>/\2/")
  echo "Imported key information:"
  echo "      Key id: ${GPG_KEY_ID}"
  echo "  Owner name: ${GPG_KEY_OWNER_NAME}"
  echo " Owner email: ${GPG_KEY_OWNER_EMAIL}"

  git config --global user.signingkey "$GPG_KEY_ID"
  git config --global commit.gpgsign true

  export GPG_TTY=$(tty)
  # generate sign to store passphrase in cache for "git commit"
  echo "test" | gpg --clearsign --pinentry-mode=loopback --passphrase "${INPUT_GPG_PASSPHRASE}" > /dev/null 2>&1

  rm private.key
}

get_branch_available_options() {
  for OPTION in "$@" ; do
    if echo "$OPTION" | egrep -vq "^(--dryrun|--branch)"; then
      AVAILABLE_OPTIONS="${AVAILABLE_OPTIONS} ${OPTION}"
    fi
  done

  echo "$AVAILABLE_OPTIONS"
}

echo "STARTING MEVISOFT ACTION"

cd "${GITHUB_WORKSPACE}" || exit 1

git config --global --add safe.directory $GITHUB_WORKSPACE

view_debug_output

set -e

#SET OPTIONS
set -- --no-progress --no-colors

if [ "$INPUT_DEBUG_MODE" = true ] || [ -n "$RUNNER_DEBUG" ]; then
  set -- "$@" --verbose --debug
fi

if [ -n "$INPUT_MEVISOFT_BRANCH_NAME" ]; then
  set -- "$@" --branch="${INPUT_MEVISOFT_BRANCH_NAME}"
fi

if [ -n "$INPUT_IDENTITY" ]; then
  set -- "$@" --identity="${INPUT_IDENTITY}"
fi

if [ "$INPUT_DRYRUN_ACTION" = true ]; then
  set -- "$@" --dryrun
fi

if [ -n "$INPUT_ADD_MEVISOFT_BRANCH" ]; then
  NEW_BRANCH_OPTIONS=$( get_branch_available_options "$@" )

  if [ -n "$INPUT_NEW_BRANCH_PRIORITY" ]; then
    NEW_BRANCH_OPTIONS="${NEW_BRANCH_OPTIONS} --priority=${INPUT_NEW_BRANCH_PRIORITY}"
  fi

  echo "CREATING BRANCH $INPUT_ADD_MEVISOFT_BRANCH"

  crowdin branch add "$INPUT_ADD_MEVISOFT_BRANCH" $NEW_BRANCH_OPTIONS --title="${INPUT_NEW_BRANCH_TITLE}" --export-pattern="${INPUT_NEW_BRANCH_EXPORT_PATTERN}"
fi

if [ "$INPUT_PUSH_BUILDS" = true ]; then
    [ -z "${GITHUB_TOKEN}" ] && {
      echo "CAN NOT FIND 'GITHUB_TOKEN' IN ENVIRONMENT VARIABLES"
      exit 1
    }

    [ -n "${INPUT_GPG_PRIVATE_KEY}" ] && {
      setup_commit_signing
    }

    push_to_branch
fi

if [ -n "$INPUT_DELETE_MEVISOFT_BRANCH" ]; then
  echo "REMOVING BRANCH $INPUT_DELETE_MEVISOFT_BRANCH"

  crowdin branch delete "$INPUT_DELETE_MEVISOFT_BRANCH" $( get_branch_available_options "$@" )
fi
