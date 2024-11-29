# Contributing to `panther-core`

## Issue tracking

Feedback on the code is very welcome; please first check that your bug
/ issue / enhancement request is not already listed here:

- https://github.com/pantherprotocol/panther-core/issues

and if not then [file a new issue](https://github.com/pantherprotocol/panther-core/issues/new).

## Helping with development

Any [pull request](https://help.github.com/articles/using-pull-requests/)
is extremely welcome!

However, given the complexity of the codebase, it is strongly recommended to communicate with members of Panther's development community via the [Discord server](https://discord.gg/WZuRnMCZ4c) or in the [web forums (Discourse)](https://forum.pantherprotocol.io/)
in advance of working on any changes.

Thanks in advance!

## Code submission and review

Before submitting MRs / PRs, please:

- Carefully review each commit to ensure it conforms to coding standards.
  > For PVL developers, see https://docs.google.com/document/d/1cZfuY1isGjatnHO_M3T9D7niqKJXwxztQ48ypctb33c
- Run yarn lint and yarn test to ensure there will be no CI failures on submission.
- Test the changes carefully. For example, for UI changes, compare the UI before and after the changes to catch any potential regressions.
- If the changes are still WIP, it is fine (and often useful) to submit for early review, but in this case, the MR / PR must be marked as Draft.

### Pull request / merge request workflow

We develop using triangular workflows on git. Commits should typically be pushed to branches in a developer’s personal fork of the upstream GitHub or GitLab repository, and then a merge request created from that for others to review. Using personal forks helps keep the list of branches in the upstream repository free from clutter, so that it only tracks shared branches used by multiple team members.

To contribute to this repository, please align with the following standards:

#### Git commit grouping

- A commit should never break the tests or other CI
- A commit in a PR or MR should not rely on another commit later in the same PR / MR to fix a bug or any technical debt or other issue which it introduces.
- A commit should be as small as possible, but no smaller.
- For example, when adding a new feature, the new tests for that feature should be in the same commit.
- Ideally include updates to the documentation too, at least if the documentation changes are small.
- A single commit should never mix unrelated changes.
  > For example, refactorings should never be mixed with bug fixes or enhancements.

#### Git commit messages

We aim for high-quality commit messages which always have both a title and a body, and always clearly explain the “why”, i.e. the context and motivation for the change, not just the “how”.

##### Title

According to the Conventional Commits standard, the title of the commit message should be structured as follows:
<type>(<scope>): <description>

###### List of types:

feat - new feature
fix - tag for fixing bugs
build - changes related to build of the apps
deploy - changes related to the deployment
ci - continuous integration
docs - documentation
style - css, etc
refactor - refactoring changes
perf - performance, working with optimization of the code
test - tests
bump - update version of the packages

Because this repository contains multiple workspaces, the title should contain the scope (i.e. name of the workspace) to make it clear to what component / workspace this commit is related to:

- contracts
- dapp
- circuits
- crypto
- subgraph
- integration
- monorepo or root (this is related to whole monorepo)

The type should be followed by the scope in the parentheses.
Example of a good git commit:

```
refactor(subgraph): enhance subgraph configuration and deployment process

Refactor subgraph setup and deployment to improve flexibility and
maintainability.

- Removed hardcoded configurations from `subgraph.yaml` and replaced
  them with a template file (`subgraph.template.yaml`) using
  placeholders for dynamic values.
- Added scripts to generate environment-specific configurations
  (`generate:staging:internal`, `generate:staging:public`, etc.).
- Introduced new `.env` files (`.env.staging.internal`,
  `.env.staging.public`, `.env.canary.internal`) to manage
  environment-specific variables.
- Updated `setupSubgraph.ts` to validate `.env` files, generate
  `subgraph.yaml` dynamically, and handle errors gracefully.
- Enhanced `package.json` scripts to streamline building and deploying
  subgraphs for multiple environments.
- Updated `README.md` with detailed instructions for setup, building,
  and deployment.
- Improved TypeScript configuration (`tsconfig.json`) for better type
  checking and compatibility.
- Added `.gitignore` entries to exclude generated and unnecessary files.
- Deprecated and removed redundant scripts related to the previous
  subgraph deployment flow.

These changes make the subgraph setup process more modular and easier to
manage across different environments.
```
