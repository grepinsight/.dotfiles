

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
