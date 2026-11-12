Output demo/work/s05_raw.mp4
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
Type "# validate against the synthetic specification"
Enter
Sleep 0.6s
Type "./bin/defxbridge validate --source examples/valid --spec examples/spec.csv"
Enter
Sleep 5s
