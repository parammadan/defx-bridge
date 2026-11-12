Output demo/work/s03_raw.mp4
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
Type "# The R program: the same tag syntax, written as R comments"
Enter
Sleep 0.6s
Type "cat -n examples/valid/makeadsl.R | sed -n '9,22p'"
Enter
Sleep 1.5s
Type "cat -n examples/valid/makeadsl.R | sed -n '47,49p'"
Enter
Sleep 8s
