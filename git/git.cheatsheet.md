

# Git Log

1. Show the entire history of the file [^1]

    git log --follow -p -- <file>

[^1]: http://stackoverflow.com/questions/278192/view-the-change-history-of-a-file-using-git-versioning


2. Show the stat of the changes between two commits(things you see when you pull)

    git log COMIT..COMIT --stat

3. Show the last N commits

    git log -n 5 # show last 5 commits

4. Show the source along with commit messages

    git log -p

# Git Diff

```
git diff ..master --  <FILE_NAME
```


# Git Commmit

How to change commit messages

```
git commit --amend
```

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

## Commit empty commit

    git commit --allow-empty

# Git

# Git Branch

## Rename
```
git branch -m <OLD_NAME> <NEW_NAME>
```

## Delete or remove local/remote branch

```
# delete local branch
git branch -d BRANCH_NAME

# remote
git push origin --delete BRANCH_NAME
```

# Git Reset

```
git reset HEAD~
```

# Break commits into multiple commits


```
git rebase -i COMMIT^
git reset HEAD^
git add -p
git commit
gt rebase --continue
```
## Break a previous commit into multiple commits

https://stackoverflow.com/questions/6217156/break-a-previous-commit-into-multiple-commits


# Git Grep Search

<https://stackoverflow.com/questions/2928584/how-to-grep-search-committed-code-in-the-git-history>

    git grep <PATTERN> $(git rev-list --all)

# Git Rm

When you want remove / forget a file that has been committed

    git rm --cached /path/to/file

# Git Clean

    git clean -f # deletes files
    git clean -df # deletes directory, including empty directory!


# How to find things


https://stackoverflow.com/questions/2928584/how-to-grep-search-committed-code-in-the-git-history

Search commit *message* :

```
git log --grep=<SUBSTRING TO SEARCH IN COMMIT MESSAGE>
```

Search commit *contents* (if a REGEX is different)

```
git log -G REGEX -p
```

Search commit *contents* : (if a REGEX is added or not)

```
git log -S<regex> --pickaxe-regex -p
```

