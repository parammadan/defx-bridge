Output demo/work/s02_raw.mp4
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
Type "# The SAS program: DEFX tags are ordinary comments beside the code"
Enter
Sleep 0.6s
Type "cat -n examples/valid/makeadae.sas | sed -n '19,37p'"
Enter
Sleep 8s
