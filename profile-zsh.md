# Profile ZSH

The best tool for the job, by far and away is: https://github.com/romkatv/zsh-bench.

References:
- https://github.com/romkatv/zsh-bench
- https://gist.github.com/laggardkernel/4a4c4986ccdcaf47b91e8227f9868ded

# Older thinking
The simplest and most productive tool I found leveraged was `hyperfine`. It's like
running `time zsh -ic exit`, except it's statistically significant results only (trust
me, it makes a difference).

```sh
$ hyperfine --warmup 3 'zsh -ic exit'
```

There are times where it's not enough, and you need to profile a lot deeper. Read
this blog: https://xebia.com/blog/profiling-zsh-shell-scripts/.

- if using parallel code, zprof is the only choice
```zsh
# .zshrc Begining:
zmodload zsh/zprof

...

# .zshrc End:
zprof
```

- else use the xtrace/qcachegrind beast from the blog, its so much better.
```zsh
# .zshrc Begining:
PS4=$'\\\011%D{%s%6.}\011%x\011%I\011%N\011%e\011'
exec 3>&2 2>/tmp/zshstart.$$.log
setopt xtrace prompt_subst

...

# .zshrc End:
unsetopt xtrace
exec 2>&3 3>&-
```
