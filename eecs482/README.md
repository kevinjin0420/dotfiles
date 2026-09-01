# EECS 482

Class-specific setup, installed opt-in via `./ansible.sh eecs482.yml`.

## `version482.vim`

Editor plugin from the EECS 482 course staff. On every save/edit of a
`.cpp/.cc/.h/.hpp/.py` file inside an `eecs482/*` GitHub repo, it maintains a
sibling `.version482.<branch>` clone and auto-commits/pushes snapshots to the
matching `*.version482` remote. Requires working GitHub access to that remote.

Vendored here rather than fetched at install time so the exact version is
pinned and diffable across terms.

- Current file version: `vim-20260824`
- To update: replace the file with the new copy the course distributes, commit.

The playbook symlinks it into `~/.vim/plugin/` and `~/.config/nvim/plugin/`,
which both Vim and Neovim source automatically at startup.
