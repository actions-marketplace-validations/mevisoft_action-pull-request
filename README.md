## Usage

Set up a workflow in *.github/workflows/crowdin.yml* (or add a job to your existing workflows).

Read the [Configuring a workflow](https://help.github.com/en/articles/configuring-a-workflow) article for more details on creating and setting up GitHub workflows.

```yaml
name: Crowdin Action

on:
  push:
    branches: [ main ]

jobs:
  synchronize-with-crowdin:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v3

      - name: mevisoft action
        uses: mevisoft/action-pull-request@v1
        with:
          pull_request_branch_name: build_mevisoft
          create_pull_request: true
          pull_request_title: 'New Mevisoft Build'
          pull_request_body: 'New Mevisoft Builds by [Mevisoft GH Action](https://github.com/mevisoft/action-pull-request)'
          pull_request_base_branch_name: 'main'
        env:
          GITHUB_TOKEN: ${{ secrets.GH_TOKEN }}
```

`secrets.GH_TOKEN` - a GitHub Personal Access Token with the `repo` scope selected (the user should have write access to the repository).

## Supported options

The default action is to upload sources. However, you can set different actions using the "with" options. If you don't want to upload your sources to Crowdin, just set the `upload_sources` option to false.

By default, sources and translations are being uploaded to the root of your Crowdin project. Still, if you use branches, you can set the preferred source branch.

You can also specify what GitHub branch you’d like to download your translations to (default translation branch is `l10n_crowdin_action`).

In case you don’t want to download translations from Crowdin (`download_translations: false`), `pull_request_branch_name` and `create_pull_request` options aren't required either.

```yaml
- name: mevisoft action
  uses: mevisoft/action-pull-request@v1
  with:
    # Upload sources option
    upload_sources: true
    # Upload translations options
    upload_translations: true
    upload_language: 'uk'
    auto_approve_imported: true
    import_eq_suggestions: true

    # Download sources options
    download_sources: true
    push_sources: true
 
    push_translations: true
    commit_message: 'New Mevisoft translations by GitHub Action'
    # this can be used to pass down any supported argument of the `download translations` cli command, e.g.
    # This is the name of the git branch that Crowdin will create when opening a pull request.
    # This branch does NOT need to be manually created. It will be created automatically by the action.
    pull_request_branch_name: l10n_crowdin_action
    create_pull_request: true
    pull_request_title: 'New Mevisoft translations'
    pull_request_body: 'New Mevisoft pull request with translations'
    pull_request_labels: 'enhancement, good first issue'
    pull_request_assignees: 'mevisoft-bot'
    pull_request_reviewers: 'mevisoft-user-reviewer'
    pull_request_team_reviewers: 'mevisoft-team-reviewer'

    # This is the name of the git branch to with pull request will be created.
    # If not specified default repository branch will be used.
    pull_request_base_branch_name: not_default_branch

    # Global options

    # This is the name of the top-level directory that Crowdin will use for files.
    # Note that this is not a "branch" in the git sense, but more like a top-level directory in your Crowdin project.
    # This branch does NOT need to be manually created. It will be created automatically by the action.
    mevisoft_branch_name: mevisoft_build_branch
    identity: 'path/to/your/credentials/file'
    dryrun_action: true

    # GitHub (Enterprise) configuration
    github_base_url: github.com
    github_api_base_url: api.[github_base_url]
    github_user_name: Mevisoft Bot
    github_user_email: support+bot@crowdin.com
    
    # For signed commits, add your ASCII-armored key and export "gpg --armor --export-secret-key GPG_KEY_ID"
    # Ensure that all emails are the same: for account profile that holds private key, the one specified during key generation, and for commit author (github_user_email parameter)
    gpg_private_key: ${{ secrets.GPG_PRIVATE_KEY }}
    gpg_passphrase: ${{ secrets.GPG_PASSPHRASE }}
```

For more detailed descriptions of these options, see [`action.yml`](https://github.com/crowdin/github-action/blob/master/action.yml).

> **Note**
> The `base_url` is required For Crowdin Enterprise and should be passed in the following way: `base_url: 'https://{organization-name}.api.crowdin.com'`

### Crowdin CLI command

You can also run any other Crowdin CLI command by specifying the `command` and `command_args` _(optional)_ options. For example:

```yaml
- name: crowdin action
  uses: crowdin/github-action@v1
  with:
    command: 'pre-translate'
    command_args: '-l uk --method tm --branch main'
```

To see the full list of available commands, visit the [official documentation](https://crowdin.github.io/crowdin-cli/).

### Crowdin configuration file

If your workflow file specifies the `config` property, you'll need to add the following to your [Crowdin configuration file](https://support.crowdin.com/configuration-file/) (e.g. `crowdin.yml`):

```yml
project_id_env: CROWDIN_PROJECT_ID
api_token_env: CROWDIN_PERSONAL_TOKEN
```

When the workflow runs, the real values of your token and project ID will be injected into the config using the secrets in the environment.

## Permissions

In order to push translations and create pull requests, the Crowdin GitHub Action requires the `GITHUB_TOKEN` to have the write permission on the `content` and `pull-requests`.

In case you want to use an [automatic GitHub authentication token](https://docs.github.com/en/actions/security-guides/automatic-token-authentication), you need to assign the [`write` permission to your job](https://docs.github.com/en/actions/using-jobs/assigning-permissions-to-jobs) and [allow GH Actions to create Pull Requests](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository#preventing-github-actions-from-creating-or-approving-pull-requests).

## Contributing

If you would like to contribute please read the [Contributing](/CONTRIBUTING.md) guidelines.

## Seeking Assistance

If you find any problems or would like to suggest a feature, please feel free to file an issue on GitHub at [Issues Page](https://github.com/crowdin/github-action/issues).

## License

<pre>
The Crowdin GitHub Action is licensed under the MIT License.
See the LICENSE file distributed with this work for additional
information regarding copyright ownership.

Except as contained in the LICENSE file, the name(s) of the above copyright
holders shall not be used in advertising or otherwise to promote the sale,
use or other dealings in this Software without prior written authorization.
</pre>
