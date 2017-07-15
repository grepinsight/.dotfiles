

# Git Log

Show the entire history of the file [^1]

    git log --follow -p -- <file>

[^1]: http://stackoverflow.com/questions/278192/view-the-change-history-of-a-file-using-git-versioning

# Git Commmit

## Commit only part of a file in Git

    git add --patch/-p <filename>

    y: stage this hunk for the next commit
    n: do not stage this hunk for the next commit
    q: quit; do not stage this hunk or any of the remaining hunks
    a: stage this hunk and all later hunks in the file
    d: do not stage this hunk or any of the later hunks in the file
    g: select a hunk to go to
    /: search for a hunk matching the given regex
    j: leave this hunk undecided, see next undecided hunk
    J: leave this hunk undecided, see next hunk
    k: leave this hunk undecided, see previous undecided hunk
    K: leave this hunk undecided, see previous hunk
    s: split the current hunk into smaller hunks
    e: manually edit the current hunk
    ?: print hunk help


# Git Reset

```
git reset HEAD~
```
## Break a previous commit into multiple commits

https://stackoverflow.com/questions/6217156/break-a-previous-commit-into-multiple-commits


# Git Grep Search

<https://stackoverflow.com/questions/2928584/how-to-grep-search-committed-code-in-the-git-history>

    git grep <PATTERN> $(git rev-list --all)

# Git Rm

When you want remove a file that has been committed 

    git rm --cached /path/to/file
