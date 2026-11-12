Output demo/work/s06_raw.mp4
Set Shell "bash"
Set FontSize 22
Set FontFamily "Menlo"
Set Width 1920
Set Height 950
Set Padding 36
Set Theme "Catppuccin Mocha"
Set TypingSpeed 15ms
Set Framerate 20
Hide
Type "export PS1='$ ' PS2='> ' && renice -n 15 -p $$ >/dev/null && clear"
Enter
Sleep 300ms
Show
Type "# a deliberately invalid tag: the variable is not in the spec"
Enter
Sleep 0.6s
Type "cat examples/invalid/unknown_variable.R"
Enter
Sleep 1.2s
Type `./bin/defxbridge validate --source examples/invalid/unknown_variable.R --spec examples/spec.csv; echo "exit code: $?"`
Enter
Sleep 9s
